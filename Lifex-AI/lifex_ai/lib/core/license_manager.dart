/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: license_manager.dart
/// المسار: lib/core/license_manager.dart
/// الوصف: إدارة ترخيص التطبيق، إسناد النسخة، والتحقق من صلاحية الاستخدام.
/// إعداد وتطوير: غازي سليم بكفلاوي
/// =============================================================

import 'app_constants.dart';

/// حالة الترخيص الحالية للتطبيق.
enum LicenseStatus {
  active, // الترخيص فعّال وسليم
  expired, // الترخيص منتهي الصلاحية
  invalid, // الترخيص غير صالح أو تالف
  trial, // فترة تجريبية
  unregistered, // لم يتم تفعيل أي ترخيص بعد
}

/// نموذج بيانات الترخيص.
class LicenseInfo {
  final String licenseId;
  final String ownerName;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final LicenseStatus status;
  final String appVersion;

  const LicenseInfo({
    required this.licenseId,
    required this.ownerName,
    required this.issuedAt,
    this.expiresAt,
    required this.status,
    required this.appVersion,
  });

  /// هل الترخيص لا يزال ساري المفعول؟
  bool get isValid {
    if (status == LicenseStatus.invalid ||
        status == LicenseStatus.unregistered) {
      return false;
    }
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  Map<String, dynamic> toJson() => {
        'licenseId': licenseId,
        'ownerName': ownerName,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'status': status.name,
        'appVersion': appVersion,
      };

  factory LicenseInfo.fromJson(Map<String, dynamic> json) {
    return LicenseInfo(
      licenseId: json['licenseId'] as String,
      ownerName: json['ownerName'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: LicenseStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LicenseStatus.unregistered,
      ),
      appVersion: json['appVersion'] as String,
    );
  }
}

/// المدير المسؤول عن دورة حياة الترخيص داخل التطبيق.
///
/// هذا المدير لا يتعامل مع أي خادم خارجي حالياً؛ التحقق الفعلي من الترخيص
/// (عبر خادم Lifex-AI) يُضاف لاحقاً كطبقة شبكة منفصلة. حالياً يوفر البنية
/// الأساسية لتخزين/تحميل/التحقق محلياً.
class LicenseManager {
  LicenseManager._internal();
  static final LicenseManager instance = LicenseManager._internal();

  LicenseInfo? _currentLicense;

  LicenseInfo? get currentLicense => _currentLicense;

  /// تحميل ترخيص من بيانات محفوظة محلياً (مثلاً من التخزين الآمن).
  void loadLicense(LicenseInfo license) {
    _currentLicense = license;
  }

  /// إنشاء ترخيص تجريبي افتراضي عند أول تشغيل للتطبيق.
  LicenseInfo createTrialLicense({required String ownerName}) {
    final trial = LicenseInfo(
      licenseId: 'TRIAL-${DateTime.now().millisecondsSinceEpoch}',
      ownerName: ownerName,
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(
        Duration(days: AppConstants.trialPeriodDays),
      ),
      status: LicenseStatus.trial,
      appVersion: AppConstants.appVersion,
    );
    _currentLicense = trial;
    return trial;
  }

  /// التحقق مما إذا كان التطبيق مسموحاً له بالعمل الآن.
  bool get isAppUsageAllowed {
    final license = _currentLicense;
    if (license == null) return false;
    return license.isValid;
  }

  /// إعادة تقييم حالة الترخيص الحالي (مثلاً بعد مرور الوقت).
  LicenseStatus reevaluateStatus() {
    final license = _currentLicense;
    if (license == null) return LicenseStatus.unregistered;

    if (license.expiresAt != null &&
        DateTime.now().isAfter(license.expiresAt!)) {
      _currentLicense = LicenseInfo(
        licenseId: license.licenseId,
        ownerName: license.ownerName,
        issuedAt: license.issuedAt,
        expiresAt: license.expiresAt,
        status: LicenseStatus.expired,
        appVersion: license.appVersion,
      );
      return LicenseStatus.expired;
    }
    return license.status;
  }

  /// إلغاء الترخيص الحالي (تسجيل خروج / إعادة ضبط).
  void clearLicense() {
    _currentLicense = null;
  }

  /// مفاتيح العرض في مصادر Kotlin مرفوضة. لا تفعّل ترخيصاً.
  static bool isRejectedDemoKey(String key) {
    final folded = key.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    return folded == 'GHAZI2026';
  }

  String evaluateExternalKey(String key) {
    if (isRejectedDemoKey(key)) {
      return 'مفتاح العرض التوضيحي مرفوض. لا يفعّل ترخيصاً على هذا الجهاز.';
    }
    return 'لا يوجد خادم ترخيص لقبول مفاتيح خارجية بعد.';
  }

  String appendAr(String body) {
    const stamp = AppConstants.ownershipStatementShort;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return stamp;
    if (trimmed.contains(stamp) ||
        trimmed.contains(AppConstants.developerCredit) ||
        trimmed.contains('غازي سليم بكفلاوي')) {
      return trimmed;
    }
    return '$trimmed $stamp';
  }

  String appendEn(String body) {
    const stamp = AppConstants.ownershipStatementShortEn;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return stamp;
    if (trimmed.contains(stamp) ||
        trimmed.contains(AppConstants.ownershipStatementEn) ||
        trimmed.contains('Ghazi Salim Bekfalawi') ||
        trimmed.contains('Bakfalawi')) {
      return trimmed;
    }
    return '$trimmed $stamp';
  }
}
