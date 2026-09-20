import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_engine_bridge.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_retriever.dart';
import 'package:lifex_ai/core/agent/tools/knowledge_search_tool.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/evidence_pack.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';

/// MedicalDatabaseManager وهمي — لا IO.
class _FakeDb implements MedicalDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

KnowledgeRecord _rec({
  required String id,
  required String title,
  required String body,
  List<String> terms = const [],
  LioSourceProvenance? provenance,
}) {
  return KnowledgeRecord(
    id: id,
    title: title,
    body: body,
    terms: terms,
    provenance: provenance ??
        LioSourceProvenance(
          sourceId: 's-$id',
          sourceType: 'test',
          authority: LioSourceAuthority.documentation,
          retrievedAt: DateTime(2026, 9, 20),
          document: 'doc-$id',
          evidenceLevel: 0.7,
          confidence: 0.7,
        ),
  );
}

void main() {
  late InMemoryKnowledgeCorpus corpus;
  late LifexKnowledgeEngine engine;
  late KnowledgeEngineBridgedRetriever retriever;

  setUp(() {
    corpus = InMemoryKnowledgeCorpus([
      _rec(
        id: 'k1',
        title: 'Hydration guidance',
        body: 'Adequate fluid intake supports general wellness education.',
        terms: const ['hydration', 'fluid'],
      ),
      _rec(
        id: 'k2',
        title: 'Sleep basics',
        body: 'Consistent sleep schedules support wellness education.',
        terms: const ['sleep'],
      ),
    ]);
    engine = LifexKnowledgeEngine(corpus: corpus);
    retriever = KnowledgeEngineBridgedRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
    );
  });

  test('delegates actually to Knowledge Engine (call counter)', () async {
    expect(retriever.delegatesToKnowledgeEngine, isTrue);
    expect(retriever.engineRetrieveCalls, 0);
    final ctx = await retriever.retrieve('hydration fluid');
    expect(retriever.engineRetrieveCalls, 1);
    expect(ctx.matches, isNotEmpty);
    expect(ctx.retrievalStatus, isNotNull);
  });

  test('preserves provenance / evidence in agent documents', () async {
    final ctx = await retriever.retrieve('hydration');
    expect(ctx.matches, isNotEmpty);
    final raw = ctx.matches.first.raw;
    expect(raw['provenance'], isNotNull);
    expect(raw['sourceId'], isNotNull);
    expect(raw['confidence'], isNotNull);
    expect(raw['evidenceLevel'], isNotNull);
    expect(ctx.llmIsSourceOfTruth, isFalse);
    expect(ctx.evidencePackMap, isNotNull);
  });

  test('empty / invalid query', () async {
    final ctx = await retriever.retrieve('   ');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'EMPTY_QUERY');
    expect(retriever.engineRetrieveCalls, 0);
  });

  test('no results', () async {
    final ctx = await retriever.retrieve('zzzznotfoundxyz');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'EMPTY');
  });

  test('retrieval unavailable adapter', () async {
    final offline = KnowledgeEngineBridgedRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
      engineAvailable: false,
    );
    final ctx = await offline.retrieve('hydration');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'TOOL_UNAVAILABLE');
    expect(offline.engineRetrieveCalls, 0);
  });

  test('conflict handling preserved', () async {
    final conflictCorpus = InMemoryKnowledgeCorpus([
      _rec(
        id: 'a',
        title: 'A',
        body: 'topicw yes statement for adults education.',
        terms: const ['topicw'],
        provenance: LioSourceProvenance(
          sourceId: 'a',
          sourceType: 'journal',
          authority: LioSourceAuthority.peerReviewed,
          retrievedAt: DateTime(2026, 9, 20),
          document: 'doc-a',
          url: 'https://example.org/a',
          evidenceLevel: 0.8,
          confidence: 0.8,
        ),
      ),
      _rec(
        id: 'b',
        title: 'B',
        body: 'topicw no statement for adults education.',
        terms: const ['topicw'],
        provenance: LioSourceProvenance(
          sourceId: 'b',
          sourceType: 'news',
          authority: LioSourceAuthority.news,
          retrievedAt: DateTime(2026, 9, 20),
          document: 'doc-b',
          url: 'https://example.org/b',
          evidenceLevel: 0.3,
          confidence: 0.3,
        ),
      ),
    ]);
    final r = KnowledgeEngineBridgedRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: LifexKnowledgeEngine(corpus: conflictCorpus),
      corpus: conflictCorpus,
    );
    final ctx = await r.retrieve('topicw');
    expect(ctx.hasConflict || ctx.retrievalStatus == 'CONFLICT', isTrue);
    expect(ctx.conflicts, isNotEmpty);
  });

  test('missing provenance results not returned as trusted matches', () {
    const bridge = AgentKnowledgeBridge();
    final pack = KnowledgeEvidencePack(
      query: 'q',
      status: KnowledgeRetrievalStatus.missingProvenance,
      items: const [],
      retrievedAt: DateTime(2026, 9, 20),
    );
    final ctx = bridge.toAgentContext(originalQuery: 'q', pack: pack);
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'MISSING_PROVENANCE');
  });

  test('filters items whose provenance is not acceptable', () {
    const bridge = AgentKnowledgeBridge();
    final pack = KnowledgeEvidencePack(
      query: 'q',
      status: KnowledgeRetrievalStatus.ok,
      retrievedAt: DateTime(2026, 9, 20),
      items: [
        KnowledgeEvidenceItem(
          recordId: 'bad',
          title: 'bad',
          snippet: 'x',
          score: 1,
          channel: RetrievalChannel.keywordBm25,
          provenance: LioSourceProvenance(
            sourceId: 'bad',
            sourceType: 'llm',
            authority: LioSourceAuthority.unverified,
            retrievedAt: DateTime(2026, 9, 20),
          ),
        ),
      ],
    );
    final ctx = bridge.toAgentContext(originalQuery: 'q', pack: pack);
    expect(ctx.matches, isEmpty);
  });

  test('consumer compatibility — KnowledgeSearchTool still works', () async {
    final tool = KnowledgeSearchTool(retriever: retriever);
    final result = await tool.execute(
      arguments: const {'query': 'hydration'},
      context: AgentContext(
        taskId: 't',
        profileId: 'p',
        userRequest: 'hydration',
        permissions: const AgentGrantedPermissions(granted: {}),
      ),
    );
    expect(result.isSuccess, isTrue);
    expect(retriever.engineRetrieveCalls, greaterThan(0));
  });

  test('factory KnowledgeRetriever constructs bridged facade', () {
    final r = KnowledgeRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(r, isA<KnowledgeEngineBridgedRetriever>());
    expect(
      (r as KnowledgeEngineBridgedRetriever).delegatesToKnowledgeEngine,
      isTrue,
    );
  });

  test('Architecture Guard — no parallel independent retrieval path', () async {
    // الاسترجاع يمر عبر engine.retrieve فقط؛ لا نتائج عند engineUnavailable.
    final offline = KnowledgeRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
      engineAvailable: false,
    ) as KnowledgeEngineBridgedRetriever;
    final ctx = await offline.retrieve('hydration fluid');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'TOOL_UNAVAILABLE');
    // حتى مع corpus ممتلئ — ممنوع fallback موازٍ
    expect(corpus.records, isNotEmpty);
  });
}
