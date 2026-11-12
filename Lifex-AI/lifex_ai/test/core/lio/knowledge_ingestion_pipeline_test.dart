import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/ingestion_contracts.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/ingestion_pipeline.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/local_ingestion_adapters.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/source_registry.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/source_registry_model.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';

RegisteredKnowledgeSource _src({
  String id = 'src-who-like',
  String version = '1.0',
  KnowledgeSourceStatus status = KnowledgeSourceStatus.active,
  LioSourceAuthority authority = LioSourceAuthority.officialStandard,
  String? supersedes,
  String? hash,
}) {
  return RegisteredKnowledgeSource(
    sourceId: id,
    kind: KnowledgeSourceKind.governmentalPublicHealth,
    title: 'Public health reference $id',
    authority: authority,
    status: status,
    publisher: 'Example Public Health Org',
    url: 'https://example.health/$id',
    documentRef: 'doc-$id',
    jurisdiction: 'INT',
    language: 'en',
    license: 'CC-BY',
    evidenceLevel: 0.9,
    reliabilityWeight: 0.85,
    version: version,
    retrievedAt: DateTime(2026, 9, 20),
    lastVerifiedAt: DateTime(2026, 9, 20),
    contentHash: hash,
    allowedDomains: const [
      KnowledgeDomain.publicHealth,
      KnowledgeDomain.educational,
    ],
    conflictPolicy: SourceConflictPolicy.preserveBoth,
    supersedesSourceId: supersedes,
  );
}

void main() {
  late InMemoryKnowledgeSourceRegistry registry;
  late InMemoryDocumentStore store;
  late InMemoryKnowledgeCorpus corpus;
  late KnowledgeIngestionPipeline pipeline;

  setUp(() {
    registry = InMemoryKnowledgeSourceRegistry();
    store = InMemoryDocumentStore();
    corpus = InMemoryKnowledgeCorpus();
    pipeline = KnowledgeIngestionPipeline(
      registry: registry,
      acquisition: store,
      corpus: corpus,
    );
  });

  test('source registration accepted when citable + authority ok', () {
    final r = registry.register(_src());
    expect(r.accepted, isTrue);
    expect(registry.get('src-who-like')?.isActive, isTrue);
  });

  test('invalid source rejection — unverified / not citable', () {
    final bad = RegisteredKnowledgeSource(
      sourceId: 'bad',
      kind: KnowledgeSourceKind.educationalReference,
      title: 'blog',
      authority: LioSourceAuthority.unverified,
      status: KnowledgeSourceStatus.active,
      retrievedAt: DateTime(2026, 9, 20),
    );
    final r = registry.register(bad);
    expect(r.accepted, isFalse);
  });

  test('provenance requirement — ingest without active source rejected',
      () async {
    final out = await pipeline.ingest(
      sourceId: 'missing',
      documentId: 'd1',
    );
    expect(out.status, IngestionStatus.rejected);
    expect(out.record.rejectReason, IngestionRejectReason.invalidSource);
  });

  test('checksum / version detection on accepted ingest', () async {
    registry.register(_src(version: '1.0'));
    store.put(
      const RawKnowledgeDocument(
        documentId: 'd1',
        sourceId: 'src-who-like',
        title: 'Hydration overview',
        body: 'Adults generally benefit from adequate fluid intake.',
        terms: ['hydration'],
        version: '1.0',
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'd1',
    );
    expect(out.status, IngestionStatus.accepted);
    expect(out.record.contentHash, isNotNull);
    expect(out.record.version, '1.0');
    expect(out.acceptedRecords, isNotEmpty);
    expect(
      out.acceptedRecords.first.provenance.isCitable,
      isTrue,
    );
  });

  test('duplicate detection by contentHash', () async {
    registry.register(_src());
    const doc = RawKnowledgeDocument(
      documentId: 'd1',
      sourceId: 'src-who-like',
      title: 'Same',
      body: 'Identical body for duplicate detection test case.',
      terms: ['dup'],
    );
    store.put(doc);
    final first = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'd1',
    );
    expect(first.status, IngestionStatus.accepted);
    store.put(
      const RawKnowledgeDocument(
        documentId: 'd2',
        sourceId: 'src-who-like',
        title: 'Same',
        body: 'Identical body for duplicate detection test case.',
        terms: ['dup'],
      ),
    );
    final second = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'd2',
    );
    expect(second.status, IngestionStatus.rejected);
    expect(second.record.rejectReason, IngestionRejectReason.duplicate);
  });

  test('superseding a source version preserves history', () {
    registry.register(_src(version: '1.0'));
    final r2 = registry.register(_src(version: '2.0'));
    expect(r2.accepted, isTrue);
    expect(r2.source!.version, '2.0');
    expect(r2.source!.supersedesSourceId, 'src-who-like');
    expect(
      registry.history.any((h) => h.status == KnowledgeSourceStatus.superseded),
      isTrue,
    );
  });

  test('quarantine when conflictPolicy requires human review', () async {
    final reviewSrc = RegisteredKnowledgeSource(
      sourceId: 'src-review',
      kind: KnowledgeSourceKind.clinicalGuideline,
      title: 'Guideline',
      authority: LioSourceAuthority.peerReviewed,
      status: KnowledgeSourceStatus.active,
      url: 'https://example.health/guideline',
      documentRef: 'g1',
      evidenceLevel: 0.8,
      reliabilityWeight: 0.8,
      version: '1',
      retrievedAt: DateTime(2026, 9, 20),
      allowedDomains: const [KnowledgeDomain.clinicalGuideline],
      conflictPolicy: SourceConflictPolicy.requireHumanReview,
    );
    registry.register(reviewSrc);
    store.put(
      const RawKnowledgeDocument(
        documentId: 'a1',
        sourceId: 'src-review',
        title: 'Topic Z',
        body: 'Topic Z statement alpha for quarantine path.',
        terms: ['topicz'],
      ),
    );
    await pipeline.ingest(sourceId: 'src-review', documentId: 'a1');
    store.put(
      const RawKnowledgeDocument(
        documentId: 'a2',
        sourceId: 'src-review',
        title: 'Topic Z alt',
        body: 'Topic Z statement beta competing with alpha.',
        terms: ['topicz'],
      ),
    );
    final out = await pipeline.ingest(sourceId: 'src-review', documentId: 'a2');
    expect(out.status, IngestionStatus.quarantined);
    expect(out.quarantinedChunks, isNotEmpty);
  });

  test('rejected content — empty body', () async {
    registry.register(_src());
    store.put(
      const RawKnowledgeDocument(
        documentId: 'empty',
        sourceId: 'src-who-like',
        title: 'Empty',
        body: '   ',
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'empty',
    );
    expect(out.status, IngestionStatus.rejected);
    expect(out.record.rejectReason, IngestionRejectReason.emptyContent);
  });

  test('conflict preservation — competing terms kept, no invented consensus',
      () async {
    registry.register(_src(id: 's1'));
    registry.register(
      RegisteredKnowledgeSource(
        sourceId: 's2',
        kind: KnowledgeSourceKind.peerReviewedLiterature,
        title: 'Paper B',
        authority: LioSourceAuthority.peerReviewed,
        status: KnowledgeSourceStatus.active,
        url: 'https://example.health/s2',
        documentRef: 'paper-b',
        evidenceLevel: 0.7,
        reliabilityWeight: 0.7,
        version: '1',
        retrievedAt: DateTime(2026, 9, 20),
        allowedDomains: const [KnowledgeDomain.educational],
        conflictPolicy: SourceConflictPolicy.preserveBoth,
      ),
    );
    store.put(
      const RawKnowledgeDocument(
        documentId: 'p1',
        sourceId: 's1',
        title: 'Claim yes',
        body: 'Shared topic claims affirmative guidance for adults.',
        terms: ['sharedtopic'],
      ),
    );
    store.put(
      const RawKnowledgeDocument(
        documentId: 'p2',
        sourceId: 's2',
        title: 'Claim no',
        body: 'Shared topic claims alternative guidance for adults.',
        terms: ['sharedtopic'],
      ),
    );
    final a = await pipeline.ingest(sourceId: 's1', documentId: 'p1');
    final b = await pipeline.ingest(sourceId: 's2', documentId: 'p2');
    expect(a.status, IngestionStatus.accepted);
    expect(b.status, IngestionStatus.accepted);
    expect(b.record.competingDocumentIds, isNotEmpty);
    expect(b.record.notesAr.any((n) => n.contains('CONFLICT')), isTrue);
  });

  test('forbidden clinical / private / secrets / prescription rejected',
      () async {
    registry.register(_src());
    store.put(
      const RawKnowledgeDocument(
        documentId: 'clin',
        sourceId: 'src-who-like',
        title: 'leak',
        body: 'patient_id 123 clinical_record export',
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'clin',
    );
    expect(out.record.rejectReason, IngestionRejectReason.forbiddenClinical);

    store.put(
      const RawKnowledgeDocument(
        documentId: 'rx',
        sourceId: 'src-who-like',
        title: 'rx',
        body: 'prescription: amoxicillin rx_order',
      ),
    );
    final rx = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'rx',
    );
    expect(rx.record.rejectReason, IngestionRejectReason.forbiddenPrescription);

    store.put(
      const RawKnowledgeDocument(
        documentId: 'sec',
        sourceId: 'src-who-like',
        title: 'sec',
        body: 'api_token=abc bearer xyz',
      ),
    );
    final sec = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'sec',
    );
    expect(sec.record.rejectReason, IngestionRejectReason.forbiddenSecrets);
  });

  test('missing provenance path — bypass flags rejected', () async {
    registry.register(_src());
    store.put(
      const RawKnowledgeDocument(
        documentId: 'd',
        sourceId: 'src-who-like',
        title: 'Ok title long enough',
        body: 'Body text long enough for segmentation path.',
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'd',
      bypassProvenance: true,
    );
    expect(out.record.rejectReason, IngestionRejectReason.bypassAttempt);
  });

  test('ingestion status transitions recorded on ledger', () async {
    registry.register(_src());
    store.put(
      const RawKnowledgeDocument(
        documentId: 'd3',
        sourceId: 'src-who-like',
        title: 'Sleep hygiene basics',
        body: 'Consistent sleep schedules support general wellness.',
        terms: ['sleep'],
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'd3',
    );
    expect(pipeline.ledger, isNotEmpty);
    expect(pipeline.ledger.last.status, out.status);
    expect(out.status, IngestionStatus.accepted);
  });

  test('Knowledge Engine integration — ingest then retrieve Evidence Pack',
      () async {
    registry.register(_src());
    store.put(
      const RawKnowledgeDocument(
        documentId: 'ke1',
        sourceId: 'src-who-like',
        title: 'Electrolyte balance overview',
        body:
            'Electrolytes support fluid balance in general physiology education.',
        terms: ['electrolyte', 'fluid'],
      ),
    );
    final out = await pipeline.ingest(
      sourceId: 'src-who-like',
      documentId: 'ke1',
    );
    expect(out.status, IngestionStatus.accepted);

    final engine = LifexKnowledgeEngine(corpus: corpus);
    final fabric = LifexIntelligenceFabric(
      knowledgeEngine: engine,
      ingestionPipeline: pipeline,
    );
    expect(fabric.ingestionPipeline, isNotNull);
    expect(
      fabric.bootstrapReport()['ingestionPhase'],
      'KNOWLEDGE_SOURCE_REGISTRY_INGESTION',
    );

    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'electrolyte fluid',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.items, isNotEmpty);
    expect(pack.llmIsSourceOfTruth, isFalse);
    expect(pack.items.first.provenance.isCitable, isTrue);
  });
}
