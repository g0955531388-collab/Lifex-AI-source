import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/claim_verifier.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/local_retrievers.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';

LioSourceProvenance _prov({
  required String id,
  LioSourceAuthority authority = LioSourceAuthority.peerReviewed,
  String? document,
  String? version = '1.0',
  LioConflictStatus conflict = LioConflictStatus.none,
  String? url,
}) {
  return LioSourceProvenance(
    sourceId: id,
    sourceType: 'knowledge_article',
    authority: authority,
    retrievedAt: DateTime(2026, 9, 20),
    document: document ?? 'doc-$id',
    version: version,
    url: url ?? 'https://example.org/$id',
    author: 'publisher-$id',
    evidenceLevel: 0.8,
    confidence: 0.7,
    conflict: conflict,
  );
}

KnowledgeRecord _rec({
  required String id,
  required String title,
  required String body,
  LioSourceProvenance? provenance,
  List<String> terms = const [],
  Map<String, String> metadata = const {},
  List<String> relatedIds = const [],
  List<double>? embedding,
}) {
  return KnowledgeRecord(
    id: id,
    title: title,
    body: body,
    provenance: provenance ?? _prov(id: id),
    terms: terms,
    metadata: metadata,
    relatedIds: relatedIds,
    embedding: embedding,
  );
}

void main() {
  late InMemoryKnowledgeCorpus corpus;
  late LifexKnowledgeEngine engine;

  setUp(() {
    corpus = InMemoryKnowledgeCorpus([
      _rec(
        id: 'k1',
        title: 'Hydration guidance',
        body: 'General fluid intake information for healthy adults.',
        terms: const ['hydration', 'fluid'],
        metadata: const {'topic': 'nutrition', 'lang': 'en'},
        relatedIds: const ['k2'],
        embedding: const [1, 0, 0],
      ),
      _rec(
        id: 'k2',
        title: 'Electrolyte overview',
        body: 'Electrolytes support fluid balance in general physiology.',
        terms: const ['electrolyte', 'fluid'],
        metadata: const {'topic': 'nutrition', 'lang': 'en'},
        embedding: const [0.9, 0.1, 0],
      ),
      _rec(
        id: 'k3',
        title: 'Sleep hygiene',
        body: 'Sleep duration recommendations for adults.',
        terms: const ['sleep'],
        metadata: const {'topic': 'sleep', 'lang': 'en'},
        provenance: _prov(
          id: 'k3',
          authority: LioSourceAuthority.officialStandard,
          version: '2.1',
        ),
        embedding: const [0, 1, 0],
      ),
    ]);
    engine = LifexKnowledgeEngine(
      corpus: corpus,
      vector: InMemoryVectorRetriever(corpus),
    );
  });

  test('Test1 Keyword / BM25 retrieval', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'hydration fluid',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.ok);
    expect(pack.items.first.recordId, 'k1');
  });

  test('Test2 Vector adapter contract', () async {
    expect(const UnavailableVectorRetriever().isAvailable, isFalse);
    expect(InMemoryVectorRetriever(corpus).isAvailable, isTrue);
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'hydration',
        channels: [RetrievalChannel.vector],
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.ok);
    expect(pack.items, isNotEmpty);
  });

  test('Test3 Metadata filtering', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'x',
        metadataEquals: {'topic': 'sleep'},
        channels: [RetrievalChannel.metadata],
      ),
    );
    expect(pack.items.map((e) => e.recordId), ['k3']);
  });

  test('Test4 Evidence Pack provenance fields', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'sleep',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    final m = pack.items.first.toMap();
    expect(m['sourceId'], isNotNull);
    expect(m['sourceType'], isNotNull);
    expect(m['sourceUri'], isNotNull);
    expect(m['version'], '2.1');
    expect(m['authority'], isNotNull);
    expect(m['evidenceLevel'], isNotNull);
    expect(m['confidence'], isNotNull);
    expect(m['conflictStatus'], isNotNull);
    expect(m['retrievedAt'], isNotNull);
  });

  test('Test5 Source versioning', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'sleep hygiene',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.items.first.provenance.version, '2.1');
  });

  test('Test6 Conflicting sources → no invented consensus', () async {
    final conflictCorpus = InMemoryKnowledgeCorpus([
      _rec(
        id: 'c1',
        title: 'Claim A',
        body: 'Topic X says yes.',
        terms: const ['topicx'],
        provenance: _prov(
          id: 'c1',
          authority: LioSourceAuthority.peerReviewed,
          document: 'journal-a',
        ),
      ),
      _rec(
        id: 'c2',
        title: 'Claim B',
        body: 'Topic X says no.',
        terms: const ['topicx'],
        provenance: _prov(
          id: 'c2',
          authority: LioSourceAuthority.news,
          document: 'blog-b',
        ),
      ),
    ]);
    final e = LifexKnowledgeEngine(corpus: conflictCorpus);
    final pack = await e.retrieve(
      const KnowledgeQuery(
        text: 'topicx',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.conflict);
    expect(pack.conflicts, isNotEmpty);
    expect(pack.notesAr.any((n) => n.contains('CONFLICT')), isTrue);
  });

  test('Test7 Missing provenance → MISSING_PROVENANCE', () async {
    final bad = InMemoryKnowledgeCorpus([
      KnowledgeRecord(
        id: 'bad',
        title: 'orphan',
        body: 'orphan knowledge without cite',
        provenance: LioSourceProvenance(
          sourceId: 'bad',
          sourceType: 'unknown',
          authority: LioSourceAuthority.unverified,
          retrievedAt: DateTime.now(),
        ),
      ),
    ]);
    final e = LifexKnowledgeEngine(corpus: bad);
    final pack = await e.retrieve(
      const KnowledgeQuery(
        text: 'orphan',
        channels: [RetrievalChannel.keywordBm25],
        requireProvenance: true,
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.missingProvenance);
  });

  test('Test8 Empty retrieval', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'zzzznotfound',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.empty);
    expect(pack.items, isEmpty);
  });

  test('Test9 Reranking prefers higher authority', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'fluid',
        channels: [RetrievalChannel.keywordBm25],
        topK: 5,
      ),
    );
    // k3 has sleep only — fluid hits k1/k2; inject official on k2 via rerank corpus
    final rankedCorpus = InMemoryKnowledgeCorpus([
      _rec(
        id: 'low',
        title: 'fluid note',
        body: 'fluid',
        terms: const ['fluid'],
        provenance: _prov(id: 'low', authority: LioSourceAuthority.news),
      ),
      _rec(
        id: 'high',
        title: 'fluid standard',
        body: 'fluid',
        terms: const ['fluid'],
        provenance: _prov(
          id: 'high',
          authority: LioSourceAuthority.officialStandard,
        ),
      ),
    ]);
    final e = LifexKnowledgeEngine(corpus: rankedCorpus);
    final r = await e.retrieve(
      const KnowledgeQuery(
        text: 'fluid',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(r.items.first.recordId, 'high');
    expect(pack, isNotNull);
  });

  test('Test10 لا وصول Clinical Data', () async {
    expect(
      () => corpus.add(
        KnowledgeRecord(
          id: 'clin',
          title: 'patient',
          body: 'secret',
          layer: KnowledgeLayer.clinicalData,
          provenance: _prov(id: 'clin'),
        ),
      ),
      throwsStateError,
    );
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'hydration',
        allowClinical: true,
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.forbidden);
    expect(engine.safety.mayTouchClinicalDatabase, isFalse);
  });

  test('Test11 LLM ليس مصدر الحقيقة', () async {
    final pack = await engine.retrieve(
      const KnowledgeQuery(
        text: 'hydration',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.llmIsSourceOfTruth, isFalse);
    expect(engine.safety.llmIsSourceOfTruth, isFalse);
    expect(pack.mayDiagnose, isFalse);
    expect(pack.mayPrescribe, isFalse);
  });

  test('Test12 تكامل Knowledge Engine مع LIO', () async {
    final fabric = LifexIntelligenceFabric(
      knowledgeEngine: engine,
    );
    expect(fabric.knowledgeEngine, isNotNull);
    expect(
      fabric.bootstrapReport()['knowledgePhase'],
      'KNOWLEDGE_ENGINE_HYBRID_RAG_FOUNDATION',
    );
    final pack = await fabric.knowledgeEngine!.retrieve(
      const KnowledgeQuery(
        text: 'sleep',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    final report = fabric.knowledgeEngine!.verifyPackAgainstClaim(
      claim: const LioClaim(
        id: 'c1',
        statementAr: 'معرفة نوم موثقة',
        madeByAgentId: 'agent.medical_knowledge',
      ),
      pack: pack,
    );
    expect(report.verdict, LioVerificationVerdict.pass);
  });
}
