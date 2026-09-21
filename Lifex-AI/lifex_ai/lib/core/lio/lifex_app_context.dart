/// =============================================================
/// Lifex-AI — AppContext (تعريض Fabric الإنتاجي)
/// يستقبل [LifexProductionBundle] من Composition Root فقط.
/// ممنوع إنشاء Fabric / AgentCore / ProductionKnowledge هنا.
/// =============================================================
library lifex_ai.core.lio.lifex_app_context;

import '../../data/medical_database_manager.dart';
import '../../features/accessibility/multi_sensory_alert_manager.dart';
import '../../features/ai/ai_bridge.dart';
import '../../features/ai/ai_service_router.dart';
import '../../features/ai/unified_ai_hub_gateway.dart';
import '../../features/devices/lifex_device_runtime.dart';
import '../../features/emergency/emergency_manager.dart';
import '../../features/emergency/emergency_phone_contacts_registry.dart';
import '../../features/energy/energy_manager.dart';
import '../../features/energy/lifex_power_coordinator.dart';
import '../../features/finance/payment_controller.dart';
import '../../features/finance/subscription_billing_manager.dart';
import '../../features/finance/transaction_service.dart';
import '../../features/finance/wallet_manager.dart';
import '../../features/iot/health_device_reader.dart';
import '../../features/profile/active_profile_controller.dart';
import '../../features/profile/multi_profile_engine.dart';
import '../../features/remote_health/health_alert_dispatcher.dart';
import '../../services/cloud/cloud_sync_manager.dart';
import '../../services/medical_terminology/terminology_connector.dart';
import '../../services/translation/translation_service.dart';
import '../agent/agent_core.dart';
import '../agent/knowledge/knowledge_retriever.dart';
import '../health_data/health_observation_application_service.dart';
import '../health_data/health_observation_repository.dart';
import '../lasting_search_index.dart';
import '../local_knowledge.dart';
import '../trial_manager.dart';
import 'lifex_intelligence_fabric.dart';
import 'lifex_production_composition.dart';
import '../orchestrator/lio_gateway.dart';
import '../orchestrator/lio_sensitive_action_entry.dart';

/// حزمة المديرين المركزيين بعد التهيئة — تعرّض Fabric الإنتاجي نفسه
/// الذي أنشأه [LifexProductionComposition.assemble] دون نسخة ثانية.
class LifexAppContext {
  LifexAppContext({
    required this.multiProfileEngine,
    required this.aiModuleBundle,
    required this.emergencyManager,
    required this.energyManager,
    required this.powerCoordinator,
    required this.healthAlertDispatcher,
    required this.medicalDatabaseManager,
    required this.walletManager,
    required this.paymentController,
    required this.transactionService,
    required this.subscriptionBillingManager,
    required this.unifiedAiHubGateway,
    required this.aiServiceRouter,
    required this.cloudSyncManager,
    required this.translationService,
    required this.healthDeviceReader,
    required this.terminologyConnector,
    required this.multiSensoryAlertManager,
    required this.activeProfileController,
    required this.production,
    required this.emergencyPhoneContactsRegistry,
    required this.trialManager,
    required this.localKnowledge,
    required this.lastingSearchIndex,
    required this.deviceRuntime,
  }) {
    if (!production.isUnifiedProductionKnowledgePath) {
      throw StateError(
        'LifexAppContext requires a unified production bundle from '
        'LifexProductionComposition.assemble; secondary Fabric/AgentCore '
        'or non-production retriever is forbidden.',
      );
    }
  }

  /// الجذر الإنتاجي الوحيد — المصدر الوحيد لـ Fabric و AgentCore.
  final LifexProductionBundle production;

  final MultiProfileEngine multiProfileEngine;
  final ActiveProfileController activeProfileController;
  final AiModuleBundle aiModuleBundle;
  final EmergencyManager emergencyManager;
  final EnergyManager energyManager;
  final LifexPowerCoordinator powerCoordinator;
  final HealthAlertDispatcher healthAlertDispatcher;
  final MedicalDatabaseManager medicalDatabaseManager;
  final WalletManager walletManager;
  final PaymentController paymentController;
  final TransactionService transactionService;
  final SubscriptionBillingManager subscriptionBillingManager;
  final UnifiedAiHubGateway unifiedAiHubGateway;
  final AiServiceRouter aiServiceRouter;
  final CloudSyncManager cloudSyncManager;
  final TranslationService translationService;
  final HealthDeviceReader healthDeviceReader;
  final TerminologyConnector terminologyConnector;
  final MultiSensoryAlertManager multiSensoryAlertManager;
  final EmergencyPhoneContactsRegistry emergencyPhoneContactsRegistry;
  final TrialManager trialManager;
  final LocalKnowledge localKnowledge;
  final LastingSearchIndex lastingSearchIndex;
  final LifexDeviceRuntime deviceRuntime;

  /// نفس instance من [LifexProductionComposition.assemble] — لا Fabric ثانية.
  LifexIntelligenceFabric get fabric => production.fabric;

  /// نفس AgentCore الإنتاجي من Composition Root.
  AgentCoreBundle get agentCore => production.agentCore;

  /// توافق مع المستهلكين الحاليين (Provider / شاشات).
  AgentCoreBundle get agentCoreBundle => production.agentCore;

  /// KnowledgeRetriever الإنتاجي المرتبط بنفس المسار.
  KnowledgeRetriever get knowledgeRetriever => production.knowledgeRetriever;

  /// بوابة LIO الإنتاجية — نفس instance من Composition Root.
  ProductionLioGateway get lioGateway => production.lioGateway;

  /// Canonical HealthObservation owner من Composition Root فقط.
  /// ممنوع إنشاء InMemory هنا — الإنتاج = Persistent عبر Composition.
  HealthObservationRepository get healthObservationRepository =>
      production.healthObservationRepository;

  /// المالك التشغيلي لعمليات الملاحظة — نفس instance من Composition.
  HealthObservationApplicationService get healthObservationService =>
      production.healthObservationService;

  /// نقطة دخول UI/Application الحساسة — إلزامية قبل العمليات الحساسة.
  /// تربط مديري Application دون إنشاء Gateway/Entry/Fabric ثانية.
  /// healthObservationService يأتي مسبقاً من Composition (لا مسار ثانٍ).
  LioSensitiveActionEntry get sensitiveActionEntry {
    return _boundSensitiveEntry ??= production.sensitiveActionEntry
        .bindApplicationOps(
      walletManager: walletManager,
      transactionService: transactionService,
      paymentController: paymentController,
      subscriptionBillingManager: subscriptionBillingManager,
      medicalDatabaseManager: medicalDatabaseManager,
      localKnowledge: localKnowledge,
      lastingSearchIndex: lastingSearchIndex,
      emergencyManager: emergencyManager,
      healthObservationService: healthObservationService,
    );
  }

  LioSensitiveActionEntry? _boundSensitiveEntry;
}
