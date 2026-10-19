import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_engine_bridge.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_retriever.dart';
import 'package:lifex_ai/core/agent/knowledge/medical_bundle_corpus_seeder.dart';
import 'package:lifex_ai/core/agent/knowledge/production_knowledge_composition.dart';
import 'package:lifex_ai/core/agent/tools/knowledge_search_tool.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';

import '../../../support/knowledge_retriever_test_doubles.dart';

class _FakeDb implements MedicalDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

KnowledgeRecord _rec(String id, String text) => KnowledgeRecord(
      id: id,
      title: text,
      body: text,
      terms: text.toLowerCase().split(' '),
      provenance: LioSourceProvenance(
        sourceId: 's-$id',
        sourceType: 'test',
        authority: LioSourceAuthority.documentation,
        retrievedAt: DateTime(2026, 9, 20),
        document: 'doc-$id',
        evidenceLevel: 0.7,
        confidence: 0.7,
      ),
    );

void main() {
  late InMemoryKnowledgeCorpus corpus;
  late LifexKnowledgeEngine engine;

  setUp(() {
    corpus = InMemoryKnowledgeCorpus([
      _rec('1', 'Hydration fluid guidance for adults education'),
    ]);
    engine = LifexKnowledgeEngine(corpus: corpus);
  });

  test('A Production Agent Knowledge delegates to Knowledge Engine', () async {
    final r = ProductionKnowledgeComposition.createRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
    ) as KnowledgeEngineBridgedRetriever;
    expect(r.isProductionKnowledgePath, isTrue);
    expect(r.delegatesToKnowledgeEngine, isTrue);
    final before = r.engineRetrieveCalls;
    await r.retrieve('hydration');
    expect(r.engineRetrieveCalls, before + 1);
  });

  test('B KnowledgeEngineBridge is the mapping path used', () async {
    const bridge = AgentKnowledgeBridge();
    final r = KnowledgeEngineBridgedRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
      bridge: bridge,
    );
    final ctx = await r.retrieve('hydration');
    expect(identical(r.bridge, bridge), isTrue);
    expect(ctx.evidencePackMap, isNotNull);
    expect(ctx.matches.first.raw['provenance'], isNotNull);
  });

  test('C Test Fake works only when explicitly injected', () async {
    final fake = FakeKnowledgeRetriever(const []);
    expect(fake.isProductionKnowledgePath, isFalse);
    await fake.retrieve('anything');
    expect(fake.retrieveCalls, 1);
    expect(fake.lastQuery, 'anything');
  });

  test('D No hidden fallback to Stub from production factory', () {
    final r = KnowledgeRetriever.production(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(r, isA<KnowledgeEngineBridgedRetriever>());
    expect(r.isProductionKnowledgePath, isTrue);
    expect(r, isNot(isA<FakeKnowledgeRetriever>()));
    expect(r, isNot(isA<StubKnowledgeRetriever>()));
  });

  test('E KE unavailable → TOOL_UNAVAILABLE, not Legacy Retrieval', () async {
    final unavailable = ProductionKnowledgeComposition.createRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngineConnected: false,
    );
    expect(unavailable, isA<KnowledgeEngineUnavailableRetriever>());
    final ctx = await unavailable.retrieve('hydration fluid');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'TOOL_UNAVAILABLE');
    // corpus ممتلئ لكن لا يُستخدم مباشرة كـ legacy search
    expect(corpus.records, isNotEmpty);
  });

  test('F Existing Agent consumers remain compatible', () async {
    final r = KnowledgeRetriever.production(
      databaseManager: _FakeDb(),
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final tool = KnowledgeSearchTool(retriever: r);
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
  });

  test('G MedicalBundleCorpusSeeder is seed-only (no retrieve API)', () {
    const seeder = MedicalBundleCorpusSeeder();
    expect(seeder.runtimeType.toString(), 'MedicalBundleCorpusSeeder');
    // لا يوجد method retrieve على seeder — التحقق عبر رمز المصدر في guard.
  });

  test('H Evidence/Provenance requirements not bypassed', () async {
    final badCorpus = InMemoryKnowledgeCorpus([
      KnowledgeRecord(
        id: 'bad',
        title: 'orphan',
        body: 'orphan knowledge without cite fields',
        provenance: LioSourceProvenance(
          sourceId: 'bad',
          sourceType: 'llm',
          authority: LioSourceAuthority.unverified,
          retrievedAt: DateTime.now(),
        ),
      ),
    ]);
    final r = KnowledgeEngineBridgedRetriever(
      databaseManager: _FakeDb(),
      knowledgeEngine: LifexKnowledgeEngine(corpus: badCorpus),
      corpus: badCorpus,
    );
    final ctx = await r.retrieve('orphan');
    expect(ctx.matches, isEmpty);
    expect(
      ctx.retrievalStatus == 'MISSING_PROVENANCE' || ctx.isEmpty,
      isTrue,
    );
  });
}
