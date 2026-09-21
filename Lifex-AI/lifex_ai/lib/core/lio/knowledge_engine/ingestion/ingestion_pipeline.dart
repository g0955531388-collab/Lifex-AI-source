/// =============================================================
/// Lifex-AI — مسار الاستيعاب → Corpus Knowledge Engine
/// Registry → Validate → Acquire → Normalize → Segment →
/// Provenance → Duplicate/Conflict → Quarantine|Accept
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.ingestion_pipeline;

import '../../lio_types.dart';
import '../../source_reliability.dart';
import '../knowledge_types.dart';
import '../retrieval_adapters.dart';
import 'ingestion_contracts.dart';
import 'ingestion_safety.dart';
import 'local_ingestion_adapters.dart';
import 'source_registry.dart';
import 'source_registry_model.dart';

class KnowledgeIngestionPipeline {
  KnowledgeIngestionPipeline({
    required this.registry,
    required this.acquisition,
    required this.corpus,
    ContentNormalizer? normalizer,
    ContentSegmenter? segmenter,
    ChecksumCalculator? checksum,
    IngestionSafetyPolicy? safety,
    LifexSourceReliabilityEngine? reliability,
  })  : normalizer = normalizer ?? const SimpleContentNormalizer(),
        segmenter = segmenter ?? const ParagraphSegmenter(),
        checksum = checksum ?? const FnvChecksum(),
        safety = safety ?? const IngestionSafetyPolicy(),
        reliability = reliability ?? const LifexSourceReliabilityEngine();

  final InMemoryKnowledgeSourceRegistry registry;
  final DocumentAcquisitionAdapter acquisition;
  final InMemoryKnowledgeCorpus corpus;
  final ContentNormalizer normalizer;
  final ContentSegmenter segmenter;
  final ChecksumCalculator checksum;
  final IngestionSafetyPolicy safety;
  final LifexSourceReliabilityEngine reliability;

  final List<ImmutableIngestionRecord> _ledger = [];
  final Set<String> _seenHashes = {};
  final Map<String, String> _termOwner = {};
  int _seq = 0;

  List<ImmutableIngestionRecord> get ledger => List.unmodifiable(_ledger);

  /// مسار كامل — لا تجاوز للتحقق/provenance.
  Future<IngestionOutcome> ingest({
    required String sourceId,
    required String documentId,
    bool bypassProvenance = false,
    bool bypassValidation = false,
  }) async {
    final at = DateTime.now();
    _seq++;
    final ingestionId = 'ing-$_seq';

    if (bypassProvenance || safety.mayBypassProvenance) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.bypassAttempt,
        notes: const ['REJECTED — تجاوز provenance ممنوع.'],
      );
    }
    if (bypassValidation || safety.mayBypassValidation) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.bypassAttempt,
        notes: const ['REJECTED — تجاوز validation ممنوع.'],
      );
    }

    final source = registry.get(sourceId);
    if (source == null || !source.isActive) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.invalidSource,
        notes: const ['REJECTED — المصدر غير مسجّل أو غير نشط.'],
      );
    }

    final revalidate = registry.validator.validate(source);
    if (!revalidate.accepted) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.validationFailed,
        notes: [revalidate.reasonAr ?? 'validation failed'],
      );
    }

    final raw = await acquisition.acquire(
      source: source,
      documentId: documentId,
    );
    if (raw == null) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.emptyContent,
        notes: const ['REJECTED — تعذّر الاكتساب.'],
      );
    }

    final forbidden = safety.detectForbidden(raw);
    if (forbidden != null) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: forbidden,
        notes: ['REJECTED — محتوى محظور: ${forbidden.name}'],
      );
    }

    final normalizedBody = normalizer.normalize(raw.body);
    if (normalizedBody.isEmpty) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.emptyContent,
        notes: const ['REJECTED — محتوى فارغ بعد التطبيع.'],
      );
    }

    final contentHash =
        raw.contentHash ?? checksum.hash('${raw.title}|$normalizedBody');
    if (_seenHashes.contains(contentHash)) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        contentHash: contentHash,
        version: raw.version ?? source.version,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.duplicate,
        notes: const ['REJECTED — تكرار contentHash.'],
      );
    }

    final withHash = RawKnowledgeDocument(
      documentId: raw.documentId,
      sourceId: raw.sourceId,
      title: normalizer.normalize(raw.title),
      body: normalizedBody,
      terms: raw.terms,
      metadata: raw.metadata,
      contentHash: contentHash,
      version: raw.version ?? source.version,
    );

    final chunks = segmenter.segment(withHash);
    if (chunks.isEmpty) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        contentHash: contentHash,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.emptyContent,
        notes: const ['REJECTED — لا مقاطع بعد التقسيم.'],
      );
    }

    final provenance = source.toProvenance(retrievedOverride: at);
    if (!reliability.acceptAsEvidence(provenance)) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        contentHash: contentHash,
        status: IngestionStatus.rejected,
        reason: IngestionRejectReason.missingProvenance,
        notes: const ['REJECTED — provenance غير مقبول.'],
      );
    }

    final competing = <String>[];
    final quarantine = <NormalizedKnowledgeChunk>[];
    final accepted = <KnowledgeRecord>[];

    for (final chunk in chunks) {
      for (final term in chunk.terms) {
        final owner = _termOwner[term];
        if (owner != null && owner != chunk.documentId) {
          competing.add('$term:$owner↔${chunk.documentId}');
        }
      }

      if (source.conflictPolicy == SourceConflictPolicy.requireHumanReview &&
          competing.isNotEmpty) {
        quarantine.add(chunk);
        continue;
      }

      final conflictStatus = competing.isEmpty
          ? LioConflictStatus.none
          : LioConflictStatus.unresolved;

      final record = KnowledgeRecord(
        id: chunk.chunkId,
        title: chunk.title,
        body: chunk.body,
        layer: KnowledgeLayer.knowledge,
        terms: chunk.terms,
        metadata: {
          ...chunk.metadata,
          'contentHash': chunk.contentHash,
          'ingestionId': ingestionId,
          'sourceVersion': chunk.version ?? '',
        },
        provenance: LioSourceProvenance(
          sourceId: provenance.sourceId,
          sourceType: provenance.sourceType,
          authority: provenance.authority,
          retrievedAt: provenance.retrievedAt,
          url: provenance.url,
          repository: provenance.repository,
          document: provenance.document,
          version: chunk.version ?? provenance.version,
          author: provenance.author,
          license: provenance.license,
          evidenceLevel: provenance.evidenceLevel,
          confidence: provenance.confidence,
          conflict: conflictStatus,
          jurisdiction: provenance.jurisdiction,
        ),
      );

      // لا إدخال بلا provenance مقبول
      if (!reliability.acceptAsEvidence(record.provenance)) {
        quarantine.add(chunk);
        continue;
      }

      corpus.add(record);
      accepted.add(record);
      for (final term in chunk.terms) {
        _termOwner.putIfAbsent(term, () => chunk.documentId);
      }
    }

    _seenHashes.add(contentHash);

    if (accepted.isEmpty && quarantine.isNotEmpty) {
      return _finish(
        ingestionId: ingestionId,
        at: at,
        sourceId: sourceId,
        documentId: documentId,
        contentHash: contentHash,
        version: withHash.version,
        status: IngestionStatus.quarantined,
        competing: competing,
        quarantined: quarantine,
        notes: const ['QUARANTINED — بانتظار مراجعة.'],
      );
    }

    return _finish(
      ingestionId: ingestionId,
      at: at,
      sourceId: sourceId,
      documentId: documentId,
      contentHash: contentHash,
      version: withHash.version,
      status: competing.isNotEmpty
          ? IngestionStatus.accepted
          : IngestionStatus.accepted,
      competing: competing,
      accepted: accepted,
      quarantined: quarantine,
      notes: [
        if (competing.isNotEmpty)
          'CONFLICT — حُفظت أدلة متنافسة بلا إجماع مخترع.',
        'ACCEPTED — ${accepted.length} سجل(ات) إلى Knowledge Corpus.',
      ],
    );
  }

  IngestionOutcome _finish({
    required String ingestionId,
    required DateTime at,
    required String sourceId,
    String? documentId,
    String? contentHash,
    String? version,
    required IngestionStatus status,
    IngestionRejectReason? reason,
    List<String> notes = const [],
    List<String> competing = const [],
    List<KnowledgeRecord> accepted = const [],
    List<NormalizedKnowledgeChunk> quarantined = const [],
    String? supersedesIngestionId,
  }) {
    final record = ImmutableIngestionRecord(
      ingestionId: ingestionId,
      status: status,
      at: at,
      sourceId: sourceId,
      documentId: documentId,
      contentHash: contentHash,
      version: version,
      rejectReason: reason,
      notesAr: notes,
      competingDocumentIds: competing,
      supersedesIngestionId: supersedesIngestionId,
    );
    _ledger.add(record);
    return IngestionOutcome(
      status: status,
      record: record,
      acceptedRecords: accepted,
      quarantinedChunks: quarantined,
    );
  }
}
