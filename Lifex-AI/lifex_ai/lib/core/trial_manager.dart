/// =============================================================
/// Lifex-AI — النواة
/// الملف: trial_manager.dart
/// نسخة مستقلة: شهر مخفّض ثم بقايا إنسانية.
/// نسخة إهداء: من مشترك نظامي مرة واحدة، 15 يوماً، ثم تخصيص.
/// =============================================================
library lifex_ai.core.trial_manager;

import 'package:shared_preferences/shared_preferences.dart';

import 'app_constants.dart';

enum TrialPhase {
  /// اشتراك سنوي محلي مسجّل أو إعفاء يُمرَّر من الواجهة.
  subscribed,
  /// نسخة إهداء تعمل كاملة خمسة عشر يوماً.
  giftWorking,
  /// انتهت الخمسة عشر يوماً. تتوقف حتى التخصيص.
  giftFrozen,
  /// مشترك جديد في الشهر المجاني بخدمات أقل.
  reducedMonth,
  /// بلا اشتراك أو منتهٍ: إشعارات وتبرعات وإسعاف ودم.
  residual,
}

class GiftActionResult {
  const GiftActionResult({required this.ok, required this.messageAr, this.token});

  final bool ok;
  final String messageAr;
  final String? token;
}

class TrialManager {
  TrialManager(this._prefs);

  final SharedPreferences _prefs;

  static const _keyInstalledAt = 'lifex_installed_at';
  static const _keyOrigin = 'lifex_copy_origin';
  static const _keyGiftStartedAt = 'lifex_gift_started_at';
  static const _keyClaimedAt = 'lifex_gift_claimed_at';
  static const _keyIssuedToken = 'lifex_gift_issued_token';
  static const _keyRedeemedToken = 'lifex_gift_redeemed_token';
  static const _keySubscriptionUntil = 'lifex_subscription_until';

  DateTime get installedAt {
    final raw = _prefs.getString(_keyInstalledAt);
    if (raw == null) {
      final now = DateTime.now().toIso8601String();
      _prefs.setString(_keyInstalledAt, now);
      if (_prefs.getString(_keyOrigin) == null) {
        _prefs.setString(_keyOrigin, 'independent');
      }
      return DateTime.now();
    }
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  int get daysSinceInstall => DateTime.now().difference(installedAt).inDays;

  String get origin {
    installedAt;
    return _prefs.getString(_keyOrigin) ?? 'independent';
  }

  bool get isGiftCopy => origin == 'gift';

  DateTime? get subscriptionUntil {
    final raw = _prefs.getString(_keySubscriptionUntil);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get paidYearActive {
    final until = subscriptionUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  String? get issuedGiftToken => _prefs.getString(_keyIssuedToken);

  bool get hasIssuedGift => (issuedGiftToken ?? '').isNotEmpty;

  DateTime? get giftStartedAt {
    final raw = _prefs.getString(_keyGiftStartedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? get claimedAt {
    final raw = _prefs.getString(_keyClaimedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  TrialPhase phase({bool feeExempt = false}) {
    if (feeExempt || paidYearActive) return TrialPhase.subscribed;
    if (isGiftCopy) {
      final started = giftStartedAt ?? installedAt;
      final giftDays = DateTime.now().difference(started).inDays;
      if (giftDays < AppConstants.giftCopyDays) {
        return TrialPhase.giftWorking;
      }
      if (claimedAt == null) return TrialPhase.giftFrozen;
      final reducedDays = DateTime.now().difference(claimedAt!).inDays;
      if (reducedDays < AppConstants.trialPeriodDays) {
        return TrialPhase.reducedMonth;
      }
      return TrialPhase.residual;
    }
    if (daysSinceInstall < AppConstants.trialPeriodDays) {
      return TrialPhase.reducedMonth;
    }
    return TrialPhase.residual;
  }

  /// توافق الشاشات القديمة: القفل الشديد بعد التجربة أو تجميد الإهداء.
  bool get emergencyAndBloodOnly =>
      phase() == TrialPhase.residual || phase() == TrialPhase.giftFrozen;

  bool get asksForSubscription =>
      phase() == TrialPhase.reducedMonth || phase() == TrialPhase.residual;

  String statusLineAr({bool feeExempt = false}) {
    switch (phase(feeExempt: feeExempt)) {
      case TrialPhase.subscribed:
        return feeExempt
            ? 'نسخة كاملة بإعفاء إنساني مسجّل على هذا الجهاز.'
            : 'اشتراك سنوي مسجّل محلياً حتى ${subscriptionUntil?.toIso8601String().split('T').first ?? ''}.';
      case TrialPhase.giftWorking:
        final left = AppConstants.giftCopyDays -
            DateTime.now().difference(giftStartedAt ?? installedAt).inDays;
        return 'نسخة إهداء من مشترك نظامي. تعمل $left يوماً تقريباً ثم تتوقف حتى التخصيص.';
      case TrialPhase.giftFrozen:
        return 'توقفت نسخة الإهداء بعد ${AppConstants.giftCopyDays} يوماً. خصّصها كمشترك جديد للدخول في الشهر المجاني المخفّف.';
      case TrialPhase.reducedMonth:
        final start = claimedAt ?? installedAt;
        final left = AppConstants.trialPeriodDays -
            DateTime.now().difference(start).inDays;
        return 'شهر مجاني بخدمات أقل من الكاملة. متبقٍ تقريباً $left يوماً ثم يُطلب الاشتراك.';
      case TrialPhase.residual:
        return 'بلا اشتراك أو انتهى. تبقى الإشعارات والتبرعات ونداء الإسعاف وطلب الدم. الباقي يتوقف.';
    }
  }

  void activatePaidYear({DateTime? from}) {
    final start = from ?? DateTime.now();
    _prefs.setString(
      _keySubscriptionUntil,
      start.add(const Duration(days: 365)).toIso8601String(),
    );
  }

  GiftActionResult issueGiftToken({required bool legallySubscribed}) {
    if (!legallySubscribed) {
      return const GiftActionResult(
        ok: false,
        messageAr:
            'لا يجوز استنساخ التطبيق إلا من نسخة مشتركة نظامياً. هذه النسخة ليست مشتركة.',
      );
    }
    if (hasIssuedGift) {
      return GiftActionResult(
        ok: false,
        messageAr:
            'سبق إصدار هدية واحدة من هذا الحساب. الرمز السابق: $issuedGiftToken',
        token: issuedGiftToken,
      );
    }
    final token =
        'LIFEX-GIFT-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    _prefs.setString(_keyIssuedToken, token);
    return GiftActionResult(
      ok: true,
      token: token,
      messageAr:
          'رمز إهداء لمرة واحدة: $token. يُعطى لشخص واحد. التحقق بين الأجهزة يحتاج خادماً غير مربوط بعد؛ على جهاز المستلم يُدخل الرمز مرة واحدة.',
    );
  }

  GiftActionResult redeemGiftToken(String raw) {
    final token = raw.trim().toUpperCase();
    if (token.isEmpty || !token.startsWith('LIFEX-GIFT-')) {
      return const GiftActionResult(
        ok: false,
        messageAr: 'رمز الإهداء غير صالح. الاستنساخ من غير مشترك مرفوض.',
      );
    }
    if ((_prefs.getString(_keyRedeemedToken) ?? '').isNotEmpty) {
      return const GiftActionResult(
        ok: false,
        messageAr: 'سبق تفعيل رمز إهداء على هذا الجهاز. الإهداء مرة واحدة فقط.',
      );
    }
    if (paidYearActive) {
      return const GiftActionResult(
        ok: false,
        messageAr: 'هذه النسخة مشتركة نظامياً. لا حاجة لإهداء.',
      );
    }
    _prefs.setString(_keyRedeemedToken, token);
    _prefs.setString(_keyOrigin, 'gift');
    _prefs.setString(_keyGiftStartedAt, DateTime.now().toIso8601String());
    _prefs.remove(_keyClaimedAt);
    return GiftActionResult(
      ok: true,
      token: token,
      messageAr:
          'تم تفعيل نسخة الإهداء لمدة ${AppConstants.giftCopyDays} يوماً بالاسم والدواء والخدمات الكاملة لهذه المدة فقط.',
    );
  }

  GiftActionResult claimAsNewSubscriber() {
    if (phase() != TrialPhase.giftFrozen) {
      return GiftActionResult(
        ok: false,
        messageAr: phase() == TrialPhase.giftWorking
            ? 'نسخة الإهداء ما زالت تعمل. التخصيص بعد انتهاء الخمسة عشر يوماً.'
            : 'لا توجد نسخة إهداء مجمّدة لتخصيصها.',
      );
    }
    _prefs.setString(_keyClaimedAt, DateTime.now().toIso8601String());
    return const GiftActionResult(
      ok: true,
      messageAr:
          'خُصصت النسخة لمشترك جديد. الشهر المجاني مفتوح الآن بخدمات أقل، ثم يُطلب الاشتراك.',
    );
  }
}

/// فصل صارم: فتح الوحدة ≠ استحقاق تجاري ≠ صلاحية بيانات.
///
/// - [canOpenUnit]: اكتشاف/تنقل/فتح الوحدة الأساسية — لا يُحجب بـ Trial.
/// - [canUsePaidFeature]: عمليات مدفوعة داخل الوحدة (حجز مميز، شحن مزوّد…).
class SessionAccessPolicy {
  const SessionAccessPolicy();

  /// وحدات أساسية قابلة للاكتشاف دائماً (Module Access).
  static const coreDiscoverableUnits = {
    'emergency',
    'blood',
    'donations',
    'notifications',
    'settings',
    'wallet',
    'profile',
    'medications',
    'appointments',
    'doctors',
    'hospitals',
    'labs',
    'pharmacy',
    'imaging',
    'dentistry',
    'devices',
    'location',
    'documents',
    'messages',
    'ai',
    'education',
    'accessibility',
    'power',
    'camera',
    'voice',
    'family',
    'search',
    'admin',
  };

  /// عمليات تجارية/مدفوعة — تُفحص منفصلة عن فتح الوحدة.
  static const paidFeatureIds = {
    'premium_booking',
    'paid_topup_provider',
    'marketplace_purchase',
    'paid_advertising',
  };

  /// فتح الوحدة/التنقل — لا يُرفض بسبب انتهاء Trial أو غياب الاشتراك.
  /// الاشتراك يقيّد [canUsePaidFeature] فقط.
  bool canOpenUnit(
    String unitId, {
    required TrialPhase phase,
    required bool feeExempt,
  }) {
    // giftFrozen: نسخة إهداء غير مخصّصة — الإعدادات فقط حتى التخصيص
    // (REQUIRES_EXTERNAL_SETUP وليس LOCKED بسبب Premium).
    if (phase == TrialPhase.giftFrozen) {
      return unitId == 'settings';
    }
    // residual / reducedMonth / giftWorking / subscribed: كل الوحدات الأساسية.
    return true;
  }

  /// هل الوحدة الأساسية ضمن قائمة الاكتشاف؟
  bool isCoreDiscoverable(String unitId) =>
      coreDiscoverableUnits.contains(unitId);

  /// استحقاق ميزة مدفوعة داخل وحدة مفتوحة مسبقاً.
  bool canUsePaidFeature(
    String featureId, {
    required TrialPhase phase,
    required bool feeExempt,
  }) {
    if (feeExempt ||
        phase == TrialPhase.subscribed ||
        phase == TrialPhase.giftWorking) {
      return true;
    }
    // خارج الاشتراك: الميزات المدفوعة مقيدة؛ الوحدات نفسها تبقى مفتوحة.
    return !paidFeatureIds.contains(featureId);
  }
}
