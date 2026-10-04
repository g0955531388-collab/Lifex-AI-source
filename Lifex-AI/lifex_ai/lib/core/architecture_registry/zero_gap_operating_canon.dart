/// =============================================================
/// Lifex-AI — قانون التشغيل بلا فراغات (Zero-Gap Operating Canon)
/// مستخلص من أوامر صاحب المشروع والملفات السابقة.
/// قواعد قابلة للاختبار — ليست وثيقة فقط.
/// =============================================================
library lifex_ai.core.architecture_registry.zero_gap_operating_canon;

/// أفضل الممارسات المستخرجة من الأوامر والسيناريوهات السابقة.
class LifexZeroGapOperatingCanon {
  const LifexZeroGapOperatingCanon();

  // —— هوية النظام ——
  String get systemName => 'Lifex-AI';
  String get packageName => 'lifex_ai';
  bool get dartFlutterOnly => true;
  bool get isGlobalHealthSupportNotDoctor => true;

  // —— طبقات لا تُخلط ——
  List<String> get mandatoryLayers => const [
        'DATA',
        'KNOWLEDGE',
        'OBSERVATION',
        'INTERPRETATION',
        'HYPOTHESIS',
        'DIAGNOSIS',
        'DECISION',
        'ACTION',
        'CONTROL',
      ];

  // —— مالية ——
  bool get moneyUsesIntegerMinorUnits => true;
  bool get noFakePaymentSuccess => true;
  bool get sandboxMustBeLabeled => true;
  bool get feePreviewBeforeConfirm => true;
  bool get buttonClickIsNotPaymentSuccess => true;
  bool get everyFinancialButtonAdvancesKnownState => true;
  bool get noParallelFinancialEngine => true;
  bool get walletBalanceDerivedFromLedger => true;
  bool get topUpDeadEndForbidden => true;

  /// مسار الشحن العالمي المعتمد.
  List<String> get topUpHappyPath => const [
        'OPEN_WALLET',
        'ENTER_AMOUNT',
        'SELECT_PAYMENT_METHOD',
        'FEE_PREVIEW',
        'CONFIRM',
        'AUTHENTICATE',
        'PROVIDER',
        'PROCESSING',
        'WEBHOOK_OR_RESULT',
        'LEDGER',
        'BALANCE_UPDATE',
        'RECEIPT',
        'SPOKEN_CONFIRMATION',
      ];

  /// مسار التحويل الداخلي المعتمد.
  List<String> get transferHappyPath => const [
        'SELECT_RECIPIENT',
        'VERIFY_IDENTITY_OR_ACCOUNT',
        'ENTER_AMOUNT',
        'FEE_PREVIEW',
        'CONFIRM',
        'LEDGER_BOTH_SIDES',
        'RECEIPT',
      ];

  // —— واجهة ——
  bool get emptyMeansHonestEmptyWithNextAction => true;
  bool get emptyIsNotAccessDenied => true;
  bool get noBlankScreenWithoutGuidance => true;
  bool get noDeadContinueButton => true;
  bool get moduleAccessNotEqualsSubscription => true;
  bool get moduleAccessNotEqualsEntitlement => true;

  // —— صوت وإتاحة ——
  bool get financialFlowsMustBeSpeakable => true;
  bool get blindUsersMustHearAmountFeeTotalStatus => true;

  // —— تبرعات ——
  bool get donationSearchIsNotPatientConditionQuery => true;
  bool get phoneContactIsNotHealthIdentity => true;
  bool get onlyPublicOrConsentedDonationProfiles => true;

  // —— أجهزة ——
  bool get discoveredNotEqualsConnected => true;
  bool get connectedNotEqualsAuthenticated => true;
  bool get authenticatedNotEqualsAuthorized => true;
  bool get authorizedNotEqualsControllable => true;

  // —— سيناريوهات صوتية عالمية معتمدة ——
  List<String> get canonicalVoiceScenariosAr => const [
        'افتح محفظتي',
        'كم رصيدي',
        'شحن الرصيد',
        'أريد التبرع',
        'أريد التبرع لمرضى السرطان',
        'أريد التبرع لمرضى القلب',
        'أظهر الحملات المتاحة للتبرع',
        'افتح مركز الأجهزة',
        'أظهر الكرسي',
      ];

  /// شاشات يجب ألا تكون ميتة أو بلا مسار تالٍ.
  List<String> get mustHaveWorkingScreens => const [
        'WalletScreen',
        'DonationsCenterScreen',
        'AppointmentsScreen',
        'DoctorDirectoryScreen',
        'DeviceCenterScreen',
        'VoiceControlScreen',
        'HomeScreen',
      ];

  /// حالات EMPTY المسموحة فقط مع دعوة لإجراء تالٍ.
  bool emptyStateIsValid({
    required bool hasExplanation,
    required bool hasNextAction,
    required bool claimsBlockedBySubscription,
  }) {
    if (claimsBlockedBySubscription) return false;
    return hasExplanation && hasNextAction;
  }

  /// هل رسالة الشحن تعلن بيئة الاختبار بوضوح؟
  bool sandboxMessageHonest(String messageAr) {
    final m = messageAr.toUpperCase();
    return m.contains('SANDBOX') || messageAr.contains('اختبار');
  }

  /// الزر التالي يجب أن يسمي الحالة الهدف — ليس «متابعة» وحدها.
  bool continueLabelIsAcceptable(String labelAr) {
    final t = labelAr.trim();
    if (t == 'متابعة' || t == 'متابعة الشحن' || t == 'Continue') {
      return false;
    }
    return t.contains('التالي') ||
        t.contains('تأكيد') ||
        t.contains('وسيلة') ||
        t.contains('رسوم') ||
        t.contains('إلغاء') ||
        t.contains('رجوع') ||
        t.contains('شحن') ||
        t.contains('تحويل');
  }

  Map<String, Object> asReport() => {
        'system': systemName,
        'package': packageName,
        'topUpSteps': topUpHappyPath.length,
        'transferSteps': transferHappyPath.length,
        'voiceScenarios': canonicalVoiceScenariosAr.length,
        'mustHaveScreens': mustHaveWorkingScreens.length,
        'noFakeMoney': noFakePaymentSuccess,
        'noDeadContinue': noDeadContinueButton,
        'emptyWithNextAction': emptyMeansHonestEmptyWithNextAction,
      };
}
