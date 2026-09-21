import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_core.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_retriever.dart';
import 'package:lifex_ai/core/agent/tools/knowledge_search_tool.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_app_context.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/core/lasting_search_index.dart';
import 'package:lifex_ai/core/local_knowledge.dart';
import 'package:lifex_ai/core/trial_manager.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/features/accessibility/multi_sensory_alert_manager.dart';
import 'package:lifex_ai/features/ai/ai_bridge.dart';
import 'package:lifex_ai/features/ai/ai_engine.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/ai/doctor_guidance_engine.dart';
import 'package:lifex_ai/features/ai/health_analysis_engine.dart';
import 'package:lifex_ai/features/ai/health_decision_engine.dart';
import 'package:lifex_ai/features/ai/unified_ai_hub_gateway.dart';
import 'package:lifex_ai/features/devices/lifex_device_runtime.dart';
import 'package:lifex_ai/features/emergency/emergency_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_message_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_phone_contacts_registry.dart';
import 'package:lifex_ai/features/emergency/risk_level_engine.dart';
import 'package:lifex_ai/features/energy/battery_monitor.dart';
import 'package:lifex_ai/features/energy/energy_manager.dart';
import 'package:lifex_ai/features/energy/lifex_power_coordinator.dart';
import 'package:lifex_ai/features/energy/survival_energy_mode.dart';
import 'package:lifex_ai/features/finance/billing_exemption_policy.dart';
import 'package:lifex_ai/features/finance/payment_controller.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/subscription_billing_manager.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';
import 'package:lifex_ai/features/finance/transaction_service.dart';
import 'package:lifex_ai/features/finance/wallet_manager.dart';
import 'package:lifex_ai/features/iot/health_device_reader.dart';
import 'package:lifex_ai/features/profile/active_profile_controller.dart';
import 'package:lifex_ai/features/profile/multi_profile_engine.dart';
import 'package:lifex_ai/features/remote_health/health_alert_dispatcher.dart';
import 'package:lifex_ai/features/remote_health/trusted_contacts_manager.dart';
import 'package:lifex_ai/services/cloud/cloud_backend_client.dart';
import 'package:lifex_ai/services/cloud/cloud_sync_manager.dart';
import 'package:lifex_ai/services/medical_terminology/terminology_connector.dart';
import 'package:lifex_ai/services/translation/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _NoopVibe implements VibrationExecutor {
  @override
  Future<void> vibrate({required List<int> patternMs}) async {}
}

class _NoopFlash implements VisualFlashExecutor {
  @override
  Future<void> flashScreen({required int repeatCount}) async {}

  @override
  Future<void> flashCameraLight({required int repeatCount}) async {}
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

Future<LifexAppContext> _appContextFrom(LifexProductionBundle production) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final battery = BatteryMonitor();
  final survival = SurvivalEnergyMode();
  final energy = EnergyManager(batteryMonitor: battery, survivalMode: survival);
  final power = LifexPowerCoordinator(
    batteryMonitor: battery,
    survivalMode: survival,
  );
  final ledger = TransactionLedger();
  final wallet = WalletManager(
    gatewayClient: SandboxPaymentGatewayClient(
      feePolicy: const TopUpFeePolicy(fixedMinor: 0),
    ),
    ledger: ledger,
    topUpFeePolicy: const TopUpFeePolicy(fixedMinor: 0),
  );
  final phoneRegistry = EmergencyPhoneContactsRegistry();
  final profiles = MultiProfileEngine(maxProfiles: 2);
  return LifexAppContext(
    multiProfileEngine: profiles,
    aiModuleBundle: _minimalAiBundle(),
    emergencyManager: EmergencyManager(
      riskLevelEngine: RiskLevelEngine(),
      messageManager: EmergencyMessageManager(
        emergencyContactsRegistry: phoneRegistry,
      ),
    ),
    energyManager: energy,
    powerCoordinator: power,
    healthAlertDispatcher: HealthAlertDispatcher(
      trustedContactsProvider: (id) => TrustedContactsManager(profileId: id),
      sendFunction: (_) async => false,
    ),
    medicalDatabaseManager: _FakeDb(),
    walletManager: wallet,
    paymentController: PaymentController(walletManager: wallet),
    transactionService: TransactionService(ledger: ledger),
    subscriptionBillingManager: SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    ),
    unifiedAiHubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
    aiServiceRouter: _minimalRouter(),
    cloudSyncManager: CloudSyncManager(
      backendClient: CloudBackendClient(baseUrl: 'https://example.test'),
    ),
    translationService: TranslationService(
      provider: GoogleTranslationProvider(apiKey: 'test'),
    ),
    healthDeviceReader: HealthDeviceReader(),
    terminologyConnector: TerminologyConnector(),
    multiSensoryAlertManager: MultiSensoryAlertManager(
      vibrationExecutor: _NoopVibe(),
      visualFlashExecutor: _NoopFlash(),
    ),
    activeProfileController: ActiveProfileController(engine: profiles),
    production: production,
    emergencyPhoneContactsRegistry: phoneRegistry,
    trialManager: TrialManager(prefs),
    localKnowledge: LocalKnowledge(
      diseases: const [],
      medications: const [],
      symptoms: const [],
      tests: const [],
      namedConditions: const [],
      cameraSigns: const [],
      disclaimerAr: 'test',
    ),
    lastingSearchIndex: LastingSearchIndex(),
    deviceRuntime: LifexDeviceRuntime(),
  );
}

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

  test('A AppContext.fabric is identical to ProductionComposition fabric',
      () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final ctx = await _appContextFrom(bundle);
    expect(identical(ctx.fabric, bundle.fabric), isTrue);
    expect(identical(ctx.production, bundle), isTrue);
  });

  test('B AppContext.agentCore is identical to Composition agentCore', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final ctx = await _appContextFrom(bundle);
    expect(identical(ctx.agentCore, bundle.agentCore), isTrue);
    expect(identical(ctx.agentCoreBundle, bundle.agentCore), isTrue);
    expect(identical(ctx.knowledgeRetriever, bundle.knowledgeRetriever), isTrue);
  });

  test('C No second production Fabric via AppContext', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final ctx = await _appContextFrom(bundle);
    expect(identical(ctx.fabric, bundle.fabric), isTrue);
    expect(
      identical(ctx.fabric.existingOrchestrator, bundle.agentCore.orchestrator),
      isTrue,
    );
    expect(
      identical(ctx.fabric.knowledgeEngine, bundle.knowledgeEngine),
      isTrue,
    );
    final loose = LifexIntelligenceFabric();
    expect(identical(loose, ctx.fabric), isFalse);
  });

  test('D Real Knowledge Engine path still works through AppContext', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final ctx = await _appContextFrom(bundle);
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
    expect(ctx.knowledgeRetriever.isProductionKnowledgePath, isTrue);

    final tool = KnowledgeSearchTool(retriever: ctx.knowledgeRetriever);
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

  test('E Missing Knowledge Engine yields TOOL_UNAVAILABLE without fallback',
      () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngineConnected: false,
    );
    final ctx = await _appContextFrom(bundle);
    expect(ctx.fabric.knowledgeEngine, isNull);
    expect(
      ctx.knowledgeRetriever,
      isA<KnowledgeEngineUnavailableRetriever>(),
    );

    final retrieved = await ctx.knowledgeRetriever.retrieve('hydration fluid');
    expect(retrieved.matches, isEmpty);
    expect(retrieved.retrievalStatus, 'TOOL_UNAVAILABLE');
  });

  test('F Test doubles enter only via explicit test injection', () {
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

  test('AppContext rejects non-unified production bundle', () async {
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: aiBundle,
      aiServiceRouter: router,
      knowledgeEngine: engine,
      corpus: corpus,
    );
    final broken = LifexProductionBundle(
      fabric: LifexIntelligenceFabric(),
      agentCore: bundle.agentCore,
      knowledgeEngine: engine,
      knowledgeRetriever: bundle.knowledgeRetriever,
      corpus: corpus,
      lioGateway: bundle.lioGateway,
    );
    await expectLater(
      _appContextFrom(broken),
      throwsA(isA<StateError>()),
    );
  });
}
