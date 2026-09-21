/// =============================================================
/// Lifex-AI — جرد العمليات الحساسة غير AI/Agent/MCP (Production)
/// =============================================================
library lifex_ai.core.orchestrator.lio_sensitive_operation_inventory;

/// تصنيف عملية حساسة (ليس تشخيصاً).
enum LioSensitiveOpClass {
  readSensitive,
  readHealth,
  readMedical,
  write,
  update,
  delete,
  archive,
  export,
  share,
  printOp,
  download,
  subscribe,
  stream,
  execute,
  control,
  administer,
  audit,
  emergencyAccess,
  financial,
}

/// سجل عملية حساسة معروفة في الإنتاج.
class LioSensitiveOpRecord {
  const LioSensitiveOpRecord({
    required this.path,
    required this.classOrFunction,
    required this.callerSurface,
    required this.operation,
    required this.classification,
    required this.risk,
    required this.mustPassLio,
    required this.legalPathNote,
  });

  final String path;
  final String classOrFunction;
  final String callerSurface;
  final String operation;
  final LioSensitiveOpClass classification;
  final String risk;
  final bool mustPassLio;
  final String legalPathNote;
}

/// الجرد المعتمد للعمليات الحساسة غير مسار AI/Agent/MCP.
class LioSensitiveOperationInventory {
  const LioSensitiveOperationInventory();

  static const inventoryId = 'LioSensitiveOperationInventory';

  static const legalFlow = [
    'Presentation/UI',
    'LifexAppContext',
    'LioSensitiveActionEntry',
    'ProductionLioGateway',
    'Identity',
    'Authentication',
    'Authorization',
    'Consent',
    'Purpose',
    'DataScope/Minimization',
    'SecurityPolicy',
    'Risk/ActionClassification',
    'Application operation',
    'Verification',
    'Audit',
  ];

  List<LioSensitiveOpRecord> get productionEntries => const [
        LioSensitiveOpRecord(
          path: 'lib/screens/medications_screen.dart',
          classOrFunction: 'MedicationsScreen._loadCatalog',
          callerSurface: 'UI',
          operation: 'read_medical_catalog',
          classification: LioSensitiveOpClass.readMedical,
          risk: 'low',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.readMedicalBundle',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/settings_screen.dart',
          classOrFunction: 'SettingsScreen._checkForMedicalUpdate',
          callerSurface: 'UI',
          operation: 'check_medical_db_version',
          classification: LioSensitiveOpClass.readMedical,
          risk: 'low',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.checkMedicalDbVersion',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/settings_screen.dart',
          classOrFunction: 'SettingsScreen._downloadMedicalUpdate',
          callerSurface: 'UI',
          operation: 'download_medical_bundle',
          classification: LioSensitiveOpClass.download,
          risk: 'medium',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.refreshMedicalKnowledge',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/wallet_screen.dart',
          classOrFunction: 'WalletScreen.build / withdraw / transfer / topUp',
          callerSurface: 'UI',
          operation: 'wallet_financial_ops',
          classification: LioSensitiveOpClass.financial,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry wallet methods',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/home_screen.dart',
          classOrFunction: 'HomeScreen emergency confirm',
          callerSurface: 'UI',
          operation: 'emergency_trigger',
          classification: LioSensitiveOpClass.emergencyAccess,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.triggerEmergencyLimited',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/voice_control_screen.dart',
          classOrFunction: 'VoiceControlScreen emergency intent',
          callerSurface: 'UI',
          operation: 'emergency_trigger',
          classification: LioSensitiveOpClass.emergencyAccess,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.triggerEmergencyLimited',
        ),
        LioSensitiveOpRecord(
          path: 'lib/widgets/encyclopedia_share_bar.dart',
          classOrFunction: 'EncyclopediaShareBar._share',
          callerSurface: 'UI',
          operation: 'share_public_encyclopedia',
          classification: LioSensitiveOpClass.share,
          risk: 'low',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.sharePublicEncyclopedia',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/donations_center_screen.dart',
          classOrFunction: 'DonationsCenterScreen._confirmDonate',
          callerSurface: 'UI',
          operation: 'donate_from_wallet',
          classification: LioSensitiveOpClass.financial,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.authorizeThenRun',
        ),
        LioSensitiveOpRecord(
          path: 'lib/screens/voice_control_screen.dart',
          classOrFunction: 'VoiceControlScreen walletBalance',
          callerSurface: 'UI',
          operation: 'read_wallet_balances',
          classification: LioSensitiveOpClass.financial,
          risk: 'low',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.readWalletBalances',
        ),
        LioSensitiveOpRecord(
          path: 'lib/features/finance/wallet_manager.dart',
          classOrFunction: 'WalletManager.withdraw/topUp',
          callerSurface: 'Application',
          operation: 'FINANCIAL/WALLET',
          classification: LioSensitiveOpClass.financial,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'only after LIO via SensitiveActionEntry',
        ),
        LioSensitiveOpRecord(
          path: 'lib/data/medical_database_manager.dart',
          classOrFunction: 'MedicalDatabaseManager.read/download',
          callerSurface: 'Data',
          operation: 'READ_MEDICAL / DOWNLOAD',
          classification: LioSensitiveOpClass.readMedical,
          risk: 'medium',
          mustPassLio: true,
          legalPathNote: 'UI must not call; Entry → Application → Data',
        ),
        LioSensitiveOpRecord(
          path: 'lib/features/emergency/emergency_manager.dart',
          classOrFunction: 'EmergencyManager.triggerEmergency',
          callerSurface: 'Application',
          operation: 'EMERGENCY_ACCESS',
          classification: LioSensitiveOpClass.emergencyAccess,
          risk: 'high',
          mustPassLio: true,
          legalPathNote: 'EMERGENCY_LIMITED only via Entry',
        ),
      ];

  /// أنواع Provider ممنوعة في screens للعمليات الحساسة.
  static const uiForbiddenProviderTypes = [
    'MedicalDatabaseManager',
    'WalletManager',
    'TransactionService',
    'PaymentController',
    'SubscriptionBillingManager',
    'EmergencyManager',
  ];

  /// أنماط استدعاء مباشرة ممنوعة في UI.
  static const uiForbiddenCallPatterns = [
    r'readBundleFile\s*\(',
    r'downloadAndUpdateBundle\s*\(',
    r'\.withdraw\s*\(',
    r'\.handleTransfer\s*\(',
    r'\.triggerEmergency\s*\(',
    r'shareEncyclopedia\s*\(',
  ];
}
