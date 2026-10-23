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
/// ⚠️ ملاحظة نطاق: بعض المديرين هنا (المحفظة، بوابة AI الموحدة،
/// المزامنة السحابية) يحتاجون بيانات اعتماد حقيقية (مفاتيح API، خادم
/// فعلي) قبل العمل الكامل. حتى ذلك الحين تُستخدم تنفيذات مؤقتة آمنة
/// (No-op/In-memory) موضَّحة بتعليق ⚠️ عند كل واحدة، بحيث يبدأ التطبيق
/// ويعمل دون كراش، بدل تعطيل الميزة بالكامل حتى توفر الاعتماديات.
/// =============================================================
library lifex_ai.main;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_config.dart';
import 'core/config/app_secrets.dart';
import 'core/studio_theme.dart';
import 'widgets/studio_web_frame.dart';
import 'core/app_constants.dart';
import 'core/error_handler.dart';
import 'core/agent/adapters/mlkit_ocr_extractor.dart';
import 'core/security/secure_credential_store.dart';
import 'features/accessibility/real_sensory_executors.dart';
import 'core/lio/lifex_app_context.dart';
import 'core/lio/lifex_intelligence_fabric.dart';
import 'core/lio/lifex_production_composition.dart';
import 'core/orchestrator/lio_sensitive_action_entry.dart';
import 'l10n/generated/app_localizations.dart';

import 'data/medical_data_loader.dart';
import 'data/medical_database_manager.dart';

import 'features/voice/voice_route_observer.dart';
import 'features/accessibility/assistive_vision_engine.dart';
import 'features/accessibility/blind_camera_binding.dart';
import 'features/accessibility/multi_sensory_alert_manager.dart';
import 'features/devices/lifex_device_runtime.dart';
import 'features/ai/ai_bridge.dart';
import 'features/ai/ai_service_router.dart';
import 'features/ai/unified_ai_hub_gateway.dart';
import 'core/admin/admin_manager.dart';
import 'features/profile/health_identity_manager.dart';
import 'core/local_knowledge.dart';
import 'core/lasting_search_index.dart';
import 'core/trial_manager.dart';
import 'features/emergency/device_emergency_sms_handoff.dart';
import 'features/emergency/emergency_manager.dart';
import 'features/emergency/emergency_message_manager.dart';
import 'features/emergency/emergency_phone_contacts_registry.dart';
import 'features/emergency/risk_level_engine.dart';
import 'features/emergency/silent_emergency_signal_controller.dart';
import 'features/energy/battery_monitor.dart';
import 'features/energy/energy_manager.dart';
import 'features/energy/lifex_power_coordinator.dart';
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
import 'core/permission_transparency.dart';
import 'features/voice/assistant_session.dart';
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
  await AppSecrets.ensureLoaded();
  BlindCameraBinding.register(AssistiveVisionEngine.instance);

  final appContext = await _bootstrapLifexAi();

  runApp(LifexAiApp(appContext: appContext));
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
  await GlobalAdminManager.instance.initialize(prefs);
  GlobalAdminManager.instance.bindActorLookup(
    HealthIdentityManager.instance.actorIsOperationalLifexId,
  );
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
      'تعذّر استعادة الملفات المحفوظة: $error',
      severity: ErrorSeverity.warning,
      sourceModule: 'main',
    );
  }
  final activeProfileController = ActiveProfileController(
    engine: multiProfileEngine,
    vault: vault,
  );
  await activeProfileController.rebindIdentitiesAfterRestore();

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
    remoteManifestUrl: AppSecrets.medicalManifestUrl,
  );
  final medicalKnowledge =
      await MedicalDataLoader.loadAll(medicalDatabaseManager);
  final aiModuleBundle = AiBridge.initialize(
    symptomKeywordMap: medicalKnowledge.symptomKeywordMap,
    emergencySymptomIds: medicalKnowledge.emergencySymptomIds,
    symptomBodySystemMap: medicalKnowledge.symptomBodySystemMap,
  );

  // 3) بوابة الذكاء الاصطناعي الخارجية الموحّدة (Gemini/ChatGPT/Claude).
  final unifiedAiHubGateway = UnifiedAiHubGateway(
    credentialStore: SecureStorageCredentialStore(),
  );
  try {
    await unifiedAiHubGateway.restoreLinkedAccounts();
  } catch (error) {
    ErrorHandler.instance.report(
      'AI_HUB_RESTORE_FAILED',
      'تعذّر قراءة الربط المحفوظ. لم يُحذف مفتاح: $error',
      severity: ErrorSeverity.warning,
      sourceModule: 'main',
    );
  }
  final aiServiceRouter = AiServiceRouter(hubGateway: unifiedAiHubGateway);

  // 4) الطوارئ — يعتمد على محرك تقييم الخطر ومدير الرسائل.
  final riskLevelEngine = RiskLevelEngine();
  final emergencyPhoneContactsRegistry = EmergencyPhoneContactsRegistry();
  final emergencySmsHandoff = DeviceEmergencySmsHandoff();
  final emergencyMessageManager = EmergencyMessageManager(
    emergencyContactsRegistry: emergencyPhoneContactsRegistry,
    // مسودة SMS على الجهاز فقط — ليست إرسالاً تلقائياً ولا Push.
    draftHandoffFunction: (phone, message) =>
        emergencySmsHandoff.openDraft(phoneNumber: phone, messageAr: message),
  );

  // 4-ب) التنبيهات متعددة الحواس (اهتزاز + ومضة) لضمان وصول تنبيهات
  // الطوارئ لمستخدمين صم أو ضعاف سمع، وليس صوتاً فقط.
  final multiSensoryAlertManager = MultiSensoryAlertManager(
    vibrationExecutor: VibrationPackageExecutor(),
    visualFlashExecutor: ScreenFlashExecutor(
      navigatorKey: LifexNavigator.key,
    ),
  );

  // 4-ج) طبقة قرار "الطوارئ الصامتة" — ضوء فقط بدل صوت/اهتزاز، إلا إذا
  // وردت مكالمة من رقم موثوق. راجع silent_emergency_signal_controller.dart.
  // مربوطة الآن فعلياً بمفتاح الحدث الدقيق في لوحة الأدمن
  // (GlobalAdminManager)، فيمكن للأدمن تعطيل هذا الوضع مباشرة من
  // AdminDashboardScreen دون الحاجة لتحديث التطبيق.
  final silentEmergencySignalController = SilentEmergencySignalController(
    multiSensoryAlertManager: multiSensoryAlertManager,
    emergencyContactsRegistry: emergencyPhoneContactsRegistry,
    isSilentModeEnabledSystemWide: () => GlobalAdminManager.instance
        .isEventEnabled('emergency_silent_light_mode_enabled'),
  );

  final emergencyManager = EmergencyManager(
    riskLevelEngine: riskLevelEngine,
    messageManager: emergencyMessageManager,
    multiSensoryAlertManager: multiSensoryAlertManager,
    silentSignalController: silentEmergencySignalController,
  );

  // 4-ج) طبقة الوكيل الذكي متعدد الوكلاء (AI Agent Orchestration Layer).
  // يُبنى بعد medicalDatabaseManager وaiModuleBundle وaiServiceRouter
  // وriskLevelEngine مباشرة، لأنه يُعيد استخدامها جميعاً بدل تكرارها.
  //
  // OCR من ملف صورة مؤقت عبر ML Kit. النص اللاتيني فقط في هذا الإصدار.
  // البايتات غير المعروفة أو فشل القراءة يبقيان نصاً فارغاً.
  final smartVisionEngine = SmartVisionEngine.instance;
  const ocrTextExtractor = MlKitOcrExtractor();
  final medicalOcrReader = MedicalOcrReader(ocrExtractor: ocrTextExtractor);
  medicalOcrReader.registerWithVisionEngine(smartVisionEngine);

  // جذر الإنتاج الموحّد: Fabric + AgentCore + Knowledge Engine معاً.
  // AppContext يعرّض نفس الـbundle — بلا Fabric ثانية.
  final productionBundle = LifexProductionComposition.assemble(
    medicalDatabaseManager: medicalDatabaseManager,
    aiModuleBundle: aiModuleBundle,
    aiServiceRouter: aiServiceRouter,
    ocrReader: medicalOcrReader,
    ocrTextExtractor: ocrTextExtractor,
    visionEngine: smartVisionEngine,
    riskLevelEngine: riskLevelEngine,
  );

  // 5) الطاقة — مراقب البطارية + وضع البقاء + منسّق الطاقة العالمي.
  // منسّق الطاقة لا يدّعي نسب توفير ثابتة بلا قياسين فعليين.
  final batteryMonitor = BatteryMonitor();
  final survivalEnergyMode = SurvivalEnergyMode();
  final energyManager = EnergyManager(
    batteryMonitor: batteryMonitor,
    survivalMode: survivalEnergyMode,
  );
  final powerCoordinator = LifexPowerCoordinator(
    batteryMonitor: batteryMonitor,
    survivalMode: survivalEnergyMode,
  );
  batteryMonitor.startMonitoring();

  // 5-ب) منظومة الأجهزة العالمية — Hub + Control Center (محاكاة + مسار آمن).
  final deviceRuntime = LifexDeviceRuntime();

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
      return false;
    },
  );

  // 7) المحفظة الرقمية والمعاملات المالية.
  final transactionLedger = TransactionLedger();
  final walletManager = WalletManager(
    // الإنتاج غير موصول: Sandbox صريح حتى يوجد مزود مرخّص حقيقي.
    // لا تُخلط حركات Sandbox بأموال Production.
    gatewayClient: SandboxPaymentGatewayClient(
      feePolicy: const TopUpFeePolicy(fixedMinor: 200),
    ),
    ledger: transactionLedger,
    topUpFeePolicy: const TopUpFeePolicy(fixedMinor: 200),
  );
  final paymentController = PaymentController(walletManager: walletManager);
  final transactionService = TransactionService(ledger: transactionLedger);

  // 7-ب) فوترة الاشتراكات — فرد 100 دولار/سنة، وحدة صحية 300، مستشفى 600.
  // الاشتراك عادي بلا إعلانات ولا خدمات خاصة. التحويل والخدمات الأخرى برسوم.
  // المعفى بعد التثبيت في وحدة المعاقين: بطاقة إعاقة أو مريض دائم من بلد الحساب.
  // ⚠️ يتطلب Client ID فعلي من حساب PayPal تجاري حقيقي قبل أي دفعة حقيقية.
  final subscriptionBillingManager = SubscriptionBillingManager(
    ledger: transactionLedger,
    exemptionPolicy: const BillingExemptionPolicy(),
  );
  final paypalGateway = PayPalPaymentGatewayClient(
    clientId: AppSecrets.paypalClientId,
  );
  if (paypalGateway.isConfigured) {
    subscriptionBillingManager.registerGateway(paypalGateway);
  }
  final stripeGateway = StripePaymentGatewayClient(
    publishableKey: AppSecrets.stripePublishableKey,
  );
  if (stripeGateway.isConfigured) {
    subscriptionBillingManager.registerGateway(stripeGateway);
  }

  // 8) المزامنة السحابية.
  final cloudBackendClient = CloudBackendClient(
    baseUrl: AppSecrets.backendBaseUrl,
  );
  final cloudSyncManager = CloudSyncManager(backendClient: cloudBackendClient);

  // 9) خدمات الترجمة الديناميكية والمصطلحات الطبية الرسمية والأجهزة الذكية.
  final translationService = TranslationService(
    provider: GoogleTranslationProvider(
      apiKey: AppSecrets.googleTranslationApiKey,
    ),
  );
  SpeechToTextProcessor(
    provider: DeviceSpeechToTextProvider(),
  ).registerWithVoiceEngine(VoiceEngine.instance);
  TextToSpeechManager(
    provider: DeviceTextToSpeechProvider(),
  ).registerWithVoiceEngine(VoiceEngine.instance);
  PermissionTransparencyManager.instance.restore({
    for (final permission in LifexSensitivePermission.values)
      if (prefs.containsKey('lifex_consent_${permission.name}'))
        permission.name:
            prefs.getBool('lifex_consent_${permission.name}') ?? false,
  });
  PermissionTransparencyManager.instance.onDecided = (permission, granted) {
    prefs.setBool('lifex_consent_${permission.name}', granted);
  };
  unawaited(AssistantSession.instance.announceReady(VoiceEngine.instance));
  await HardwareCueBridge.instance.attach();
  HardwareCueHost.bind();
  final healthDeviceReader = HealthDeviceReader();
  final terminologyConnector = TerminologyConnector()
    ..registerProvider(RxNormTerminologyProvider());
  if (AppSecrets.icd11ClientId.isNotEmpty &&
      AppSecrets.icd11ClientSecret.isNotEmpty) {
    terminologyConnector.registerProvider(
      Icd11TerminologyProvider(
        clientId: AppSecrets.icd11ClientId,
        clientSecret: AppSecrets.icd11ClientSecret,
      ),
    );
  }

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
    powerCoordinator: powerCoordinator,
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
    production: productionBundle,
    emergencyPhoneContactsRegistry: emergencyPhoneContactsRegistry,
    trialManager: trialManager,
    localKnowledge: localKnowledge,
    lastingSearchIndex: lastingSearchIndex,
    deviceRuntime: deviceRuntime,
  );
}

/// جذر شجرة الواجهات — يوفّر كل المديرين المركزيين عبر Provider لكل
/// الشاشات دون الحاجة لتمريرهم يدوياً عبر كل مُنشئ (constructor).
class LifexAiApp extends StatelessWidget {
  const LifexAiApp({super.key, required this.appContext});

  final LifexAppContext appContext;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MultiProfileEngine>.value(
            value: appContext.multiProfileEngine),
        Provider<AiModuleBundle>.value(value: appContext.aiModuleBundle),
        Provider<EmergencyManager>.value(value: appContext.emergencyManager),
        Provider<EnergyManager>.value(value: appContext.energyManager),
        Provider<LifexPowerCoordinator>.value(
          value: appContext.powerCoordinator,
        ),
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
        Provider<TransactionService>.value(
            value: appContext.transactionService),
        // UnifiedAiHubGateway / AiServiceRouter غير معروضين للـ UI —
        // الوصول الحساس عبر LioSensitiveActionEntry فقط.
        Provider<CloudSyncManager>.value(value: appContext.cloudSyncManager),
        Provider<TranslationService>.value(
            value: appContext.translationService),
        Provider<HealthDeviceReader>.value(
            value: appContext.healthDeviceReader),
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
        // نفس instances من LifexProductionComposition — لا Fabric ثانية.
        // AgentCore غير معروض للـ UI؛ التنفيذ عبر LioSensitiveActionEntry فقط.
        Provider<LifexProductionBundle>.value(value: appContext.production),
        Provider<LifexIntelligenceFabric>.value(value: appContext.fabric),
        Provider<LioSensitiveActionEntry>.value(
          value: appContext.sensitiveActionEntry,
        ),
        Provider<EmergencyPhoneContactsRegistry>.value(
          value: appContext.emergencyPhoneContactsRegistry,
        ),
        Provider<TrialManager>.value(value: appContext.trialManager),
        Provider<LocalKnowledge>.value(value: appContext.localKnowledge),
        Provider<LastingSearchIndex>.value(
            value: appContext.lastingSearchIndex),
        Provider<LifexDeviceRuntime>.value(value: appContext.deviceRuntime),
      ],
      child: ListenableBuilder(
        listenable: StudioThemeController.instance,
        builder: (context, _) {
          final appearance = AppConfig.instance.appearance;
          return MaterialApp(
            navigatorKey: LifexNavigator.key,
            navigatorObservers: [VoiceRouteObserver.instance],
            title: AppConstants.systemName,
            debugShowCheckedModeBanner: false,
            locale: Locale(
              AppConfig.instance.defaultLanguage == AppLanguage.arabic
                  ? 'ar'
                  : 'en',
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: StudioTheme.light(),
            darkTheme: appearance == StudioAppearance.contrast
                ? StudioTheme.contrast()
                : StudioTheme.dark(),
            themeMode: appearance == StudioAppearance.light
                ? ThemeMode.light
                : ThemeMode.dark,
            home: const SplashScreen(),
            builder: (context, child) => StudioWebCanvas(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
