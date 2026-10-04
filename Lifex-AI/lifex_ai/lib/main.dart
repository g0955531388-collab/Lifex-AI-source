/// =============================================================
/// Lifex-AI Global Health Network
/// الملف: main.dart
/// المسار: lib/main.dart
/// الوصف: نقطة الدخول الرئيسية للتطبيق. هذا الملف مسؤول عن:
/// 1) تهيئة كل المديرين المركزيين (Managers) مرة واحدة عند الإقلاع.
/// 2) ربطهم ببعض حيث توجد اعتماديات متبادلة (مثل EmergencyManager
///    الذي يحتاج RiskLevelEngine وEmergencyMessageManager).
/// 3) توفيرهم لشجرة الواجهات كاملة عبر Provider، بدلاً من إنشاء نسخ
///    متفرقة من كل مدير داخل كل شاشة على حدة.
///
/// ملاحظة نطاق: بعض المديرين هنا (المحفظة، بوابة AI الموحدة،
/// المزامنة السحابية) يحتاجون بيانات اعتماد حقيقية (مفاتيح API، خادم
/// فعلي) قبل العمل الكامل. حتى ذلك الحين تُستخدم تنفيذات مؤقتة آمنة
/// (No-op/In-memory) موضحة بتعليق عند كل واحدة، بحيث يبدأ التطبيق
/// ويعمل دون كراش، بدل تعطيل الميزة بالكامل حتى توفر الاعتماديات.
/// =============================================================
library lifex_ai.main;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_config.dart';
import 'core/error_handler.dart';
import 'core/agent/agent_core.dart';
import 'core/agent/adapters/placeholder_ocr_extractor.dart';
import 'l10n/generated/app_localizations.dart';

import 'data/medical_data_loader.dart';
import 'data/medical_database_manager.dart';

import 'features/accessibility/assistive_vision_engine.dart';
import 'features/accessibility/multi_sensory_alert_manager.dart';
import 'features/accessibility/platform_notification_adapter.dart';
import 'features/ai/ai_bridge.dart';
import 'features/ai/ai_service_router.dart';
import 'features/ai/unified_ai_hub_gateway.dart';
import 'core/admin/admin_manager.dart';
import 'core/local_knowledge.dart';
import 'core/lasting_search_index.dart';
import 'core/trial_manager.dart';
import 'features/emergency/emergency_manager.dart';
import 'features/emergency/emergency_message_manager.dart';
import 'features/emergency/emergency_phone_contacts_registry.dart';
import 'features/emergency/risk_level_engine.dart';
import 'features/emergency/silent_emergency_signal_controller.dart';
import 'features/energy/battery_monitor.dart';
import 'features/energy/energy_manager.dart';
import 'features/energy/platform_battery_reader.dart';
import 'features/energy/platform_vibration_executor.dart';
import 'features/energy/platform_visual_flash_executor.dart';
import 'features/energy/survival_energy_mode.dart';
import 'features/finance/billing_exemption_policy.dart';
import 'features/finance/payment_controller.dart';
import 'features/finance/payment_gateway_client.dart';
import 'features/finance/paypal_payment_gateway_client.dart';
import 'features/finance/subscription_billing_manager.dart';
import 'features/finance/transaction_ledger.dart';
import 'features/finance/transaction_service.dart';
import 'features/finance/wallet_manager.dart';
import 'features/iot/health_device_reader.dart';
import 'features/profile/active_profile_controller.dart';
import 'features/profile/multi_profile_engine.dart';
import 'features/profile/profile_vault.dart';
import 'features/remote_health/health_alert_dispatcher.dart';
import 'features/remote_health/trusted_contacts_manager.dart';

import 'app_navigator.dart';
import 'features/voice/device_speech_to_text_provider.dart';
import 'features/voice/device_text_to_speech_provider.dart';
import 'features/voice/hardware_cue_bridge.dart';
import 'features/voice/hardware_cue_host.dart';
import 'features/voice/speech_to_text_processor.dart';
import 'features/voice/text_to_speech_manager.dart';
import 'features/voice/voice_engine.dart';
import 'features/vision/medical_ocr_reader.dart';
import 'features/vision/smart_vision_engine.dart';

import 'services/cloud/cloud_backend_client.dart';
import 'services/cloud/cloud_sync_manager.dart';
import 'services/medical_terminology/terminology_connector.dart';
import 'services/translation/translation_service.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appContext = await _bootstrapLifexAi();

  runApp(LifexAiApp(appContext: appContext));
}

/// حزمة تحمل كل المديرين المركزيين الجاهزين بعد التهيئة، لتمرر
/// لشجرة الـ Providers دفعة واحدة.
class LifexAppContext {
  const LifexAppContext({
    required this.multiProfileEngine,
    required this.aiModuleBundle,
    required this.emergencyManager,
    required this.energyManager,
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
    required this.agentCoreBundle,
    required this.emergencyPhoneContactsRegistry,
    required this.trialManager,
    required this.localKnowledge,
    required this.lastingSearchIndex,
  });

  final MultiProfileEngine multiProfileEngine;
  final ActiveProfileController activeProfileController;
  final AiModuleBundle aiModuleBundle;
  final EmergencyManager emergencyManager;
  final EnergyManager energyManager;
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
  final AgentCoreBundle agentCoreBundle;
  final EmergencyPhoneContactsRegistry emergencyPhoneContactsRegistry;
  final TrialManager trialManager;
  final LocalKnowledge localKnowledge;
  final LastingSearchIndex lastingSearchIndex;
}

/// تنفيذ مؤقت (In-memory) لتخزين بيانات الاعتماد — غير آمن لأي
/// استخدام حقيقي. يجب استبداله بـ FlutterSecureStorageCredentialStore
/// (يستخدم حزمة flutter_secure_storage الموجودة بالفعل في pubspec.yaml)
/// قبل أي إطلاق فعلي للتطبيق.
class _InMemoryCredentialStore implements SecureCredentialStore {
  final Map<String, String> _store = {};

  @override
  Future<void> saveCredential(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> readCredential(String key) async => _store[key];

  @override
  Future<void> deleteCredential(String key) async {
    _store.remove(key);
  }
}

/// تهيئة كل الأنظمة الأساسية بالترتيب الصحيح قبل تشغيل أي واجهة.
Future<LifexAppContext> _bootstrapLifexAi() async {
  ErrorHandler.instance.report(
    'APP_BOOTSTRAP_STARTED',
    'بدء تهيئة تطبيق Lifex-AI.',
    severity: ErrorSeverity.info,
    sourceModule: 'main',
  );

  // 1) الهوية الصحية والملفات المتعددة.
  final prefs = await SharedPreferences.getInstance();
  final vault = ProfileVault(prefs);
  final trialManager = TrialManager(prefs);
  final multiProfileEngine = MultiProfileEngine(
    maxProfiles: AppConfig.instance.maxFamilyProfilesPerAccount,
  );
  try {
    await vault.loadInto(multiProfileEngine);
  } catch (error) {
    ErrorHandler.instance.report(
      'PROFILE_VAULT_LOAD_FAILED',
      'تعذر استعادة الملفات المحفوظة: $error',
      severity: ErrorSeverity.warning,
      sourceModule: 'main',
    );
  }
  final activeProfileController = ActiveProfileController(
    engine: multiProfileEngine,
    vault: vault,
  );
  activeProfileController.rebindIdentitiesAfterRestore();

  LocalKnowledge localKnowledge;
  try {
    localKnowledge = await LocalKnowledge.load();
  } catch (_) {
    localKnowledge = LocalKnowledge(
      diseases: const [],
      medications: const [],
      symptoms: const [],
      tests: const [],
      namedConditions: const [],
      cameraSigns: const [],
      disclaimerAr: 'مرجع توعية فقط. ليس تشخيصاً.',
    );
  }

  final lastingSearchIndex = LastingSearchIndex();
  lastingSearchIndex.ingest(localKnowledge.diseases);
  lastingSearchIndex.ingest(localKnowledge.medications);
  lastingSearchIndex.ingest(localKnowledge.symptoms);
  lastingSearchIndex.ingest(localKnowledge.tests);
  lastingSearchIndex.ingest(localKnowledge.namedConditions);
  lastingSearchIndex.ingest(localKnowledge.cameraSigns);

  // 2) الذكاء الاصطناعي الصحي الداخلي (تحليل أعراض/توجيه طبي).
  final medicalDatabaseManager = MedicalDatabaseManager(
    // TODO: استبدال هذا الرابط برابط خادم Lifex-AI الفعلي عند توفره.
    remoteManifestUrl: 'https://api.lifex-ai.example.com/medical-manifest',
  );
  final medicalKnowledge = await MedicalDataLoader.loadAll(medicalDatabaseManager);
  final aiModuleBundle = AiBridge.initialize(
    symptomKeywordMap: medicalKnowledge.symptomKeywordMap,
    emergencySymptomIds: medicalKnowledge.emergencySymptomIds,
    symptomBodySystemMap: medicalKnowledge.symptomBodySystemMap,
  );

  // 3) بوابة الذكاء الاصطناعي الخارجية الموحدة (Gemini/ChatGPT/Claude).
  final unifiedAiHubGateway = UnifiedAiHubGateway(
    credentialStore: _InMemoryCredentialStore(),
  );
  final aiServiceRouter = AiServiceRouter(hubGateway: unifiedAiHubGateway);

  // 4) الطوارئ — يعتمد على محرك تقييم الخطر ومدير الرسائل.
  final riskLevelEngine = RiskLevelEngine();
  final emergencyPhoneContactsRegistry = EmergencyPhoneContactsRegistry();
  final emergencyMessageManager = EmergencyMessageManager(
    emergencyContactsRegistry: emergencyPhoneContactsRegistry,
  );

  // 4-ب) التنبيهات متعددة الحواس (اهتزاز + ومضة) لضمان وصول تنبيهات
  // الطوارئ لمستخدمين صم أو ضعاف سمع.
  // PHASE 11: استخدام تنفيذات حقيقية.
  final vibrationExecutor = PlatformVibrationExecutor();
  final visualFlashExecutor = PlatformVisualFlashExecutor();
  final multiSensoryAlertManager = MultiSensoryAlertManager(
    vibrationExecutor: vibrationExecutor,
    visualFlashExecutor: visualFlashExecutor,
  );

  // 4-ج) طبقة قرار "الطوارئ الصامتة".
  final silentEmergencySignalController = SilentEmergencySignalController(
    multiSensoryAlertManager: multiSensoryAlertManager,
    emergencyContactsRegistry: emergencyPhoneContactsRegistry,
    isSilentModeEnabledSystemWide: () => GlobalAdminManager.instance
        .isEventEnabled('emergency_silent_light_mode_enabled'),
  );

  // PHASE 11: إعداد محول الإشعارات.
  final notificationAdapter = PlatformNotificationAdapter();
  await notificationAdapter.initialize();
  await notificationAdapter.createEmergencyChannel();

  final emergencyManager = EmergencyManager(
    riskLevelEngine: riskLevelEngine,
    messageManager: emergencyMessageManager,
    multiSensoryAlertManager: multiSensoryAlertManager,
    silentSignalController: silentEmergencySignalController,
  );

  // 4-د) طبقة الوكيل الذكي.
  final smartVisionEngine = SmartVisionEngine.instance;
  const ocrTextExtractor = PlaceholderOcrExtractor();
  final medicalOcrReader = MedicalOcrReader(ocrExtractor: ocrTextExtractor);
  medicalOcrReader.registerWithVisionEngine(smartVisionEngine);

  final agentCoreBundle = AgentCore.initialize(
    medicalDatabaseManager: medicalDatabaseManager,
    aiModuleBundle: aiModuleBundle,
    aiServiceRouter: aiServiceRouter,
    ocrReader: medicalOcrReader,
    ocrTextExtractor: ocrTextExtractor,
    visionEngine: smartVisionEngine,
    riskLevelEngine: riskLevelEngine,
  );

  // 5) الطاقة — يربط مراقب البطارية بوضع البقاء.
  // PHASE 11: استخدام قارئ البطارية الحقيقي.
  final batteryReader = PlatformBatteryReader();
  final batteryMonitor = BatteryMonitor(reader: batteryReader);
  final survivalEnergyMode = SurvivalEnergyMode();
  final energyManager = EnergyManager(
    batteryMonitor: batteryMonitor,
    survivalMode: survivalEnergyMode,
  );
  batteryMonitor.startMonitoring();

  // 6) المراقبة عن بعد وتنبيهات الصحة.
  final trustedContactsManagers = <String, TrustedContactsManager>{};
  final healthAlertDispatcher = HealthAlertDispatcher(
    trustedContactsProvider: (profileId) {
      return trustedContactsManagers.putIfAbsent(
        profileId,
        () => TrustedContactsManager(profileId: profileId),
      );
    },
    sendFunction: (alert) async {
      // PHASE 11: عرض تنبيه محلي على الجهاز الحالي.
      // ملاحظة: هذا ليس تسليماً إلى جهة الثقة؛ إنه تنبيه محلي فقط.
      // إرسال حقيقي إلى جهات الثقة (SMS/Push/etc) يتطلب قنوات خارجية
      // متصلة وموثقة، وهو غير متاح حالياً.
      await notificationAdapter.showEmergencyAlert(
        title: 'تنبيه صحي',
        body: alert.messageAr,
      );
      // إرجاع false لأن الإشعار المحلي لا يعني تسليماً خارجياً.
      return false;
    },
  );

  // 7) المحفظة الرقمية والمعاملات المالية.
  final transactionLedger = TransactionLedger();
  final walletManager = WalletManager(
    gatewayClient: StripePaymentGatewayClient(publishableKey: 'pk_test_placeholder'),
    ledger: transactionLedger,
  );
  final paymentController = PaymentController(walletManager: walletManager);
  final transactionService = TransactionService(ledger: transactionLedger);

  // 7-ب) فوترة الاشتراكات.
  final subscriptionBillingManager = SubscriptionBillingManager(
    ledger: transactionLedger,
    exemptionPolicy: const BillingExemptionPolicy(),
  )..registerGateway(
      PayPalPaymentGatewayClient(clientId: 'paypal_client_id_placeholder'),
    );

  // 8) المزامنة السحابية.
  final cloudBackendClient = CloudBackendClient(
    baseUrl: 'https://backend.lifex-ai.example.com',
  );
  final cloudSyncManager = CloudSyncManager(backendClient: cloudBackendClient);

  // 9) خدمات الترجمة والأجهزة الذكية.
  final translationService = TranslationService(
    provider: GoogleTranslationProvider(apiKey: 'placeholder-translation-key'),
  );
  SpeechToTextProcessor(
    provider: DeviceSpeechToTextProvider(),
  ).registerWithVoiceEngine(VoiceEngine.instance);
  TextToSpeechManager(
    provider: DeviceTextToSpeechProvider(),
  ).registerWithVoiceEngine(VoiceEngine.instance);
  await HardwareCueBridge.instance.attach();
  HardwareCueHost.bind();
  final healthDeviceReader = HealthDeviceReader();
  final terminologyConnector = TerminologyConnector()
    ..registerProvider(RxNormTerminologyProvider());

  ErrorHandler.instance.report(
    'APP_BOOTSTRAP_COMPLETED',
    'اكتملت تهيئة الأنظمة الأساسية بنجاح.',
    severity: ErrorSeverity.info,
    sourceModule: 'main',
  );

  return LifexAppContext(
    multiProfileEngine: multiProfileEngine,
    aiModuleBundle: aiModuleBundle,
    emergencyManager: emergencyManager,
    energyManager: energyManager,
    healthAlertDispatcher: healthAlertDispatcher,
    medicalDatabaseManager: medicalDatabaseManager,
    walletManager: walletManager,
    paymentController: paymentController,
    transactionService: transactionService,
    subscriptionBillingManager: subscriptionBillingManager,
    unifiedAiHubGateway: unifiedAiHubGateway,
    aiServiceRouter: aiServiceRouter,
    cloudSyncManager: cloudSyncManager,
    translationService: translationService,
    healthDeviceReader: healthDeviceReader,
    terminologyConnector: terminologyConnector,
    multiSensoryAlertManager: multiSensoryAlertManager,
    activeProfileController: activeProfileController,
    agentCoreBundle: agentCoreBundle,
    emergencyPhoneContactsRegistry: emergencyPhoneContactsRegistry,
    trialManager: trialManager,
    localKnowledge: localKnowledge,
    lastingSearchIndex: lastingSearchIndex,
  );
}

/// جذر شجرة الواجهات — يوفر كل المديرين المركزيين عبر Provider
/// للشاشات دون الحاجة لتمريرهم يدوياً عبر كل منشئ.
class LifexAiApp extends StatelessWidget {
  const LifexAiApp({super.key, required this.appContext});

  final LifexAppContext appContext;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MultiProfileEngine>.value(value: appContext.multiProfileEngine),
        Provider<AiModuleBundle>.value(value: appContext.aiModuleBundle),
        Provider<EmergencyManager>.value(value: appContext.emergencyManager),
        Provider<EnergyManager>.value(value: appContext.energyManager),
        Provider<HealthAlertDispatcher>.value(
          value: appContext.healthAlertDispatcher,
        ),
        Provider<MedicalDatabaseManager>.value(
          value: appContext.medicalDatabaseManager,
        ),
        Provider<WalletManager>.value(value: appContext.walletManager),
        Provider<PaymentController>.value(value: appContext.paymentController),
        Provider<SubscriptionBillingManager>.value(
          value: appContext.subscriptionBillingManager,
        ),
        Provider<TransactionService>.value(value: appContext.transactionService),
        Provider<UnifiedAiHubGateway>.value(value: appContext.unifiedAiHubGateway),
        Provider<AiServiceRouter>.value(value: appContext.aiServiceRouter),
        Provider<CloudSyncManager>.value(value: appContext.cloudSyncManager),
        Provider<TranslationService>.value(value: appContext.translationService),
        Provider<HealthDeviceReader>.value(value: appContext.healthDeviceReader),
        Provider<TerminologyConnector>.value(
          value: appContext.terminologyConnector,
        ),
        Provider<MultiSensoryAlertManager>.value(
          value: appContext.multiSensoryAlertManager,
        ),
        ChangeNotifierProvider<ActiveProfileController>.value(
          value: appContext.activeProfileController,
        ),
        Provider<AssistiveVisionEngine>.value(
          value: AssistiveVisionEngine.instance,
        ),
        Provider<AgentCoreBundle>.value(value: appContext.agentCoreBundle),
        Provider<EmergencyPhoneContactsRegistry>.value(
          value: appContext.emergencyPhoneContactsRegistry,
        ),
        Provider<TrialManager>.value(value: appContext.trialManager),
        Provider<LocalKnowledge>.value(value: appContext.localKnowledge),
        Provider<LastingSearchIndex>.value(value: appContext.lastingSearchIndex),
      ],
      child: MaterialApp(
        navigatorKey: LifexNavigator.key,
        title: 'Lifex-AI',
        debugShowCheckedModeBanner: false,
        locale: Locale(
          AppConfig.instance.defaultLanguage == AppLanguage.arabic ? 'ar' : 'en',
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: AppConfig.instance.darkModeEnabled
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
