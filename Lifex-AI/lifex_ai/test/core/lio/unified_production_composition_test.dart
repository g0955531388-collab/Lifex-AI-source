import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_core.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_retriever.dart';
import 'package:lifex_ai/core/agent/tools/knowledge_search_tool.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/features/ai/ai_bridge.dart';
import 'package:lifex_ai/features/ai/ai_engine.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/ai/doctor_guidance_engine.dart';
import 'package:lifex_ai/features/ai/health_analysis_engine.dart';
import 'package:lifex_ai/features/ai/health_decision_engine.dart';
import 'package:lifex_ai/features/ai/unified_ai_hub_gateway.dart';

import '../../support/knowledge_retriever_test_doubles.dart';

class _FakeDb implements MedicalDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MemCreds implements SecureCredentialStore {
  final Map<String, String> _m = {};
  @override
  Future<void> saveCredential(String key, String value) async => _m[key] = value;
  @override
  Future<String?> readCredential(String key) async => _m[key];
  @override
  Future<void> deleteCredential(String key) async => _m.remove(key);
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

AiModuleBundle _minimalAiBundle() {
  final analysis = HealthAnalysisEngine(
    symptomKeywordMap: const {},
    emergencySymptomIds: const {},
  );
  final guidance = DoctorGuidanceEngine(symptomBodySystemMap: const {});
  return AiModuleBundle(
    engine: AiEngine.instance,
    analysisEngine: analysis,
    guidanceEngine: guidance,
    decisionEngine: HealthDecisionEngine(
      analysisEngine: analysis,
      guidanceEngine: guidance,
    ),
  );
}

AiServiceRouter _minimalRouter() => AiServiceRouter(
      hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
    );

void main() {
  late InMemoryKnowledgeCorpus corpus;
  late LifexKnowledgeEngine engine;
  late AiModuleBundle aiBundle;
  late AiServiceRouter router;

  setUp(() {
    corpus = InMemoryKnowledgeCorpus([
      _rec('1', 'Hydration fluid guidance for adults education'),
    ]);
    engine = LifexKnowledgeEngine(corpus: corpus);
    aiBundle = _minimalAiBundle();
    router = _minimalRouter();
  });

  test('A Production Composition builds AgentCore with production retriever',
      () {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(bundle.agentCore.knowledgeRetriever.isProductionKnowledgePath, isTrue);
    expect(
      bundle.agentCore.knowledgeRetriever,
      isA<KnowledgeEngineBridgedRetriever>(),
    );
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
  });

  test('B Fabric and AgentCore share the same production composition', () {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(identical(bundle.fabric.knowledgeEngine, bundle.knowledgeEngine), isTrue);
    expect(
      identical(bundle.fabric.existingOrchestrator, bundle.agentCore.orchestrator),
      isTrue,
    );
    expect(
      identical(
        bundle.agentCore.knowledgeRetriever,
        bundle.knowledgeRetriever,
      ),
      isTrue,
    );
    final bridged =
        bundle.knowledgeRetriever as KnowledgeEngineBridgedRetriever;
    expect(identical(bridged.knowledgeEngine, engine), isTrue);
  });

  test('C Knowledge Engine is the actual retrieval path', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final bridged =
        bundle.knowledgeRetriever as KnowledgeEngineBridgedRetriever;
    final before = bridged.engineRetrieveCalls;
    await bridged.retrieve('hydration');
    expect(bridged.engineRetrieveCalls, before + 1);
    expect(bridged.delegatesToKnowledgeEngine, isTrue);
  });

  test('D KE unavailable → TOOL_UNAVAILABLE without fallback', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngineConnected: false,
      corpus: corpus,
    );
    expect(
      bundle.knowledgeRetriever,
      isA<KnowledgeEngineUnavailableRetriever>(),
    );
    expect(bundle.fabric.knowledgeEngine, isNull);
    final ctx = await bundle.knowledgeRetriever.retrieve('hydration fluid');
    expect(ctx.matches, isEmpty);
    expect(ctx.retrievalStatus, 'TOOL_UNAVAILABLE');
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
  });

  test('E Test doubles only work via explicit injection (not production root)',
      () {
    final fake = FakeKnowledgeRetriever(const []);
    expect(fake.isProductionKnowledgePath, isFalse);
    expect(
      () => AgentCore.initialize(
        medicalDatabaseManager: _FakeDb(),
        aiModuleBundle: aiBundle,
        aiServiceRouter: router,
        knowledgeRetriever: fake,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('F Existing Agent consumers remain compatible', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final tool = KnowledgeSearchTool(retriever: bundle.knowledgeRetriever);
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
    expect(bundle.agentCore.coordinator, isNotNull);
  });

  test('G No Bridge bypass — AgentCore uses bridged retriever only', () {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(
      bundle.agentCore.knowledgeRetriever,
      isA<KnowledgeEngineBridgedRetriever>(),
    );
    final bridged =
        bundle.agentCore.knowledgeRetriever as KnowledgeEngineBridgedRetriever;
    expect(bridged.bridge.runtimeType.toString(), contains('AgentKnowledgeBridge'));
  });

  test('H Single production composition root for Agent Knowledge', () {
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
    // لا يوجد جذر إنتاج ثانٍ بنفس الدور — مُثبت أيضاً في architecture guards.
    final a = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final b = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    expect(a.isUnifiedProductionKnowledgePath, isTrue);
    expect(b.isUnifiedProductionKnowledgePath, isTrue);
  });
}
