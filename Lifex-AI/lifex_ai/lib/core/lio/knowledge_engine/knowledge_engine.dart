/// =============================================================
/// Lifex-AI — Knowledge Engine + Hybrid RAG Foundation
/// Source → … → Evidence Pack → LIO → AI → Verifier
/// لا تشخيص، لا وصف، لا Clinical، LLM ≠ SoT.
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.knowledge_engine;

import '../claim_verifier.dart';
import '../lio_types.dart';
import '../source_reliability.dart';
import 'evidence_pack.dart';
import 'knowledge_types.dart';
import 'local_retrievers.dart';
import 'retrieval_adapters.dart';

class KnowledgeEngineSafety {
  const KnowledgeEngineSafety();

  bool get mayDiagnose => false;
  bool get mayPrescribe => false;
  bool get mayTouchClinicalDatabase => false;
  bool get mayControlMedicalDevice => false;
  bool get llmIsSourceOfTruth => false;
  bool get uiMayTalkKnowledgeDbDirectly => false;
}

/// محرك المعرفة — يستهلك adapters؛ لا يكتب Clinical ولا يصف.
class LifexKnowledgeEngine {
  LifexKnowledgeEngine({
    required this.corpus,
    KeywordRetriever? keyword,
    VectorRetriever? vector,
    MetadataFilterRetriever? metadata,
    GraphRelationshipRetriever? graph,
    StructuredSqlRetriever? structuredSql,
    KnowledgeReranker? reranker,
    LifexSourceReliabilityEngine? reliability,
    LifexClaimVerifier? claimVerifier,
    this.safety = const KnowledgeEngineSafety(),
  })  : keyword = keyword ?? LocalBm25KeywordRetriever(corpus),
        vector = vector ?? const UnavailableVectorRetriever(),
        metadata = metadata ?? LocalMetadataFilterRetriever(corpus),
        graph = graph ?? LocalGraphRelationshipRetriever(corpus),
        structuredSql =
            structuredSql ?? const UnavailableStructuredSqlRetriever(),
        reranker = reranker ?? const AuthorityAwareReranker(),
        reliability = reliability ?? const LifexSourceReliabilityEngine(),
        claimVerifier = claimVerifier ?? const LifexClaimVerifier();

  final KnowledgeCorpus corpus;
  final KeywordRetriever keyword;
  final VectorRetriever vector;
  final MetadataFilterRetriever metadata;
  final GraphRelationshipRetriever graph;
  final StructuredSqlRetriever structuredSql;
  final KnowledgeReranker reranker;
  final LifexSourceReliabilityEngine reliability;
  final LifexClaimVerifier claimVerifier;
  final KnowledgeEngineSafety safety;

  /// مسار الاسترجاع الهجين → Evidence Pack.
  Future<KnowledgeEvidencePack> retrieve(KnowledgeQuery query) async {
    final at = DateTime.now();

    if (query.allowClinical || safety.mayTouchClinicalDatabase) {
      return KnowledgeEvidencePack(
        query: query.text,
        status: KnowledgeRetrievalStatus.forbidden,
        items: const [],
        retrievedAt: at,
        notesAr: const [
          'FORBIDDEN — Knowledge Engine لا يقرأ Clinical Data.',
        ],
      );
    }

    if (safety.mayDiagnose || safety.mayPrescribe) {
      return KnowledgeEvidencePack(
        query: query.text,
        status: KnowledgeRetrievalStatus.forbidden,
        items: const [],
        retrievedAt: at,
        notesAr: const [
          'FORBIDDEN — Knowledge Engine لا يشخّص ولا يصف.',
        ],
      );
    }

    final merged = <String, ScoredKnowledgeHit>{};
    final notes = <String>[];

    Future<void> run(
      RetrievalChannel ch,
      Future<List<ScoredKnowledgeHit>> Function() fn, {
      bool available = true,
    }) async {
      if (!query.channels.contains(ch)) return;
      if (!available) {
        notes.add('TOOL_UNAVAILABLE — ${ch.name}');
        return;
      }
      final hits = await fn();
      for (final h in hits) {
        final prev = merged[h.record.id];
        if (prev == null || h.score > prev.score) {
          merged[h.record.id] = h;
        }
      }
    }

    await run(RetrievalChannel.keywordBm25, () => keyword.search(query));
    await run(
      RetrievalChannel.vector,
      () => vector.search(query),
      available: vector.isAvailable,
    );
    await run(RetrievalChannel.metadata, () => metadata.search(query));
    await run(RetrievalChannel.graph, () => graph.search(query));
    await run(
      RetrievalChannel.structuredSql,
      () => structuredSql.search(query),
      available: structuredSql.isAvailable,
    );

    if (merged.isEmpty) {
      final unavailableOnly = notes.isNotEmpty &&
          query.channels.every((c) =>
              c == RetrievalChannel.vector ||
              c == RetrievalChannel.structuredSql);
      return KnowledgeEvidencePack(
        query: query.text,
        status: unavailableOnly
            ? KnowledgeRetrievalStatus.toolUnavailable
            : KnowledgeRetrievalStatus.empty,
        items: const [],
        retrievedAt: at,
        notesAr: notes.isEmpty
            ? const ['EMPTY — لا نتائج استرجاع.']
            : notes,
      );
    }

    var ranked = reranker.rerank(
      query: query,
      hits: merged.values.toList(),
    );

    // provenance ناقص
    if (query.requireProvenance) {
      final missing = ranked
          .where((h) => !reliability.acceptAsEvidence(h.record.provenance))
          .toList();
      if (missing.length == ranked.length) {
        return KnowledgeEvidencePack(
          query: query.text,
          status: KnowledgeRetrievalStatus.missingProvenance,
          items: const [],
          retrievedAt: at,
          notesAr: const [
            'MISSING_PROVENANCE — كل النتائج بلا provenance مقبول.',
          ],
        );
      }
      ranked = ranked
          .where((h) => reliability.acceptAsEvidence(h.record.provenance))
          .toList();
    }

    // تعارض مصادر
    final conflicts = <String>[];
    final competing = <String, List<String>>{};
    for (var i = 0; i < ranked.length; i++) {
      for (var j = i + 1; j < ranked.length; j++) {
        final a = ranked[i].record.provenance;
        final b = ranked[j].record.provenance;
        final contradict = a.document != null &&
            b.document != null &&
            a.document != b.document &&
            ranked[i].record.terms.any(
              (t) => ranked[j].record.terms.contains(t),
            ) &&
            a.authority != b.authority;
        final status = reliability.compare(
          a: a,
          b: b,
          claimsContradict: contradict,
        );
        if (status == LioConflictStatus.unresolved ||
            status == LioConflictStatus.confirmed) {
          conflicts.add(
            '${ranked[i].record.id}↔${ranked[j].record.id}:${status.name}',
          );
          competing
              .putIfAbsent(ranked[i].record.id, () => [])
              .add(ranked[j].record.id);
          competing
              .putIfAbsent(ranked[j].record.id, () => [])
              .add(ranked[i].record.id);
        }
      }
    }

    // لا نخترع إجماعًا — prefer يعيد null عند التساوي
    if (conflicts.isNotEmpty && ranked.length >= 2) {
      final preferred = reliability.prefer(
        ranked[0].record.provenance,
        ranked[1].record.provenance,
      );
      if (preferred == null) {
        notes.add('CONFLICT — لا إجماع؛ يتطلب مراجعة بشرية.');
      } else {
        notes.add(
          'CONFLICT — مصدر أرجح مؤقتًا (${preferred.sourceId}) بلا إجماع مخترع.',
        );
      }
    }

    final items = ranked
        .map(
          (h) => KnowledgeEvidenceItem(
            recordId: h.record.id,
            title: h.record.title,
            snippet: h.record.body.length > 160
                ? '${h.record.body.substring(0, 160)}…'
                : h.record.body,
            score: h.score,
            channel: h.channel,
            provenance: h.record.provenance,
            competingIds: competing[h.record.id] ?? const [],
          ),
        )
        .toList();

    return KnowledgeEvidencePack(
      query: query.text,
      status: conflicts.isNotEmpty
          ? KnowledgeRetrievalStatus.conflict
          : KnowledgeRetrievalStatus.ok,
      items: items,
      retrievedAt: at,
      conflicts: conflicts,
      notesAr: notes,
      llmIsSourceOfTruth: false,
      mayDiagnose: false,
      mayPrescribe: false,
    );
  }

  /// تكامل LIO: حزمة الأدلة → تحقق أن الادعاء لا يُقبل بلا مصادر.
  LioVerificationReport verifyPackAgainstClaim({
    required LioClaim claim,
    required KnowledgeEvidencePack pack,
  }) {
    final evidence = <LioEvidence>[];
    for (final item in pack.items) {
      evidence.add(
        LioEvidence(
          kind: LioEvidenceKind.provenanceCite,
          passed: reliability.acceptAsEvidence(item.provenance),
          detailAr: item.title,
          provenance: item.provenance,
        ),
      );
    }
    if (evidence.isEmpty) {
      return claimVerifier.verify(
        claim: claim,
        evidence: const [],
        required: {LioEvidenceKind.provenanceCite},
      );
    }
    return claimVerifier.verify(
      claim: claim,
      evidence: evidence,
      required: {LioEvidenceKind.provenanceCite},
    );
  }
}
