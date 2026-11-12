/// =============================================================
/// Lifex-AI — الهوية الصحية والملفات الشخصية
/// الملف: health_identity_manager.dart
/// المسار: lib/features/profile/health_identity_manager.dart
/// الوصف: إدارة "الهوية الصحية" لكل مستخدم — الفرق بين هذا الملف وملف
/// health_profile.dart أن هذا يتعامل مع معرّفات الهوية (Lifex-ID)،
/// التحقق من الهوية الحقيقية، وربطها بالحساب، وليس البيانات الطبية نفسها.
/// =============================================================
library;

import 'dart:math';

import '../../core/admin/admin_manager.dart';
import '../../core/error_handler.dart';

/// مستوى التحقق من هوية المستخدم.
enum IdentityVerificationLevel {
  unverified, // لم يُتحقق من الهوية بعد
  phoneVerified, // تم التحقق عبر رقم الهاتف فقط
  documentVerified, // تم التحقق عبر وثيقة رسمية (بطاقة/جواز)
  fullyVerified, // تحقق كامل (هاتف + وثيقة + مطابقة بيانات)
}

/// الهوية الصحية الفريدة لكل مستخدم داخل منظومة Lifex-AI.
///
/// كل ملف صحي (HealthProfile) يجب أن يملك هوية واحدة مرتبطة به عبر
/// [lifexId]. هذا المعرّف هو ما يُستخدم في التراسل والتبرعات بدلاً من
/// كشف رقم الهاتف أو الاسم الحقيقي مباشرة، حفاظاً على الخصوصية.
class HealthIdentity {
  final String lifexId;
  final String linkedProfileId;
  String? phoneNumber;

  /// بريد اختياري على الجهاز. وجوده لا يمنح دور المالك.
  String? email;
  IdentityVerificationLevel verificationLevel;
  DateTime createdAt;
  DateTime? verifiedAt;

  HealthIdentity({
    required this.lifexId,
    required this.linkedProfileId,
    this.phoneNumber,
    this.email,
    this.verificationLevel = IdentityVerificationLevel.unverified,
    DateTime? createdAt,
    this.verifiedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'lifexId': lifexId,
        'linkedProfileId': linkedProfileId,
        'phoneNumber': phoneNumber,
        'email': email,
        'verificationLevel': verificationLevel.name,
        'createdAt': createdAt.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
      };

  factory HealthIdentity.fromJson(Map<String, dynamic> json) => HealthIdentity(
        lifexId: json['lifexId'] as String,
        linkedProfileId: json['linkedProfileId'] as String,
        phoneNumber: json['phoneNumber'] as String?,
        email: json['email'] as String?,
        verificationLevel: IdentityVerificationLevel.values.firstWhere(
          (e) => e.name == json['verificationLevel'],
          orElse: () => IdentityVerificationLevel.unverified,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        verifiedAt: json['verifiedAt'] != null
            ? DateTime.parse(json['verifiedAt'] as String)
            : null,
      );
}

/// المدير المسؤول عن إنشاء والتحقق من الهويات الصحية (Lifex-ID).
///
/// ملاحظة: التحقق الفعلي عبر خادم/OTP/OCR للوثائق سيُبنى لاحقاً كطبقة
/// شبكة منفصلة تستدعي هذا المدير. هنا نوفر البنية والمنطق المحلي فقط.
class HealthIdentityManager {
  HealthIdentityManager._internal();
  static final HealthIdentityManager instance =
      HealthIdentityManager._internal();

  final Map<String, HealthIdentity> _identitiesByLifexId = {};
  final Map<String, String> _lifexIdByProfileId = {};

  static const String _idPrefix = 'LFX';
  final Random _random = Random.secure();

  /// إنشاء هوية صحية جديدة وربطها بملف صحي.
  HealthIdentity createIdentity({
    required String profileId,
    String? phoneNumber,
    String? email,
    String? preferredLifexId,
  }) {
    if (_lifexIdByProfileId.containsKey(profileId)) {
      final existingId = _lifexIdByProfileId[profileId]!;
      final existing = _identitiesByLifexId[existingId]!;
      if (email != null) existing.email = email;
      if (phoneNumber != null) existing.phoneNumber = phoneNumber;
      _considerOwner(existing);
      return existing;
    }

    final requestedId = preferredLifexId?.trim();
    final lifexId = requestedId != null &&
            requestedId.isNotEmpty &&
            !_identitiesByLifexId.containsKey(requestedId)
        ? requestedId
        : _generateUniqueLifexId();
    final identity = HealthIdentity(
      lifexId: lifexId,
      linkedProfileId: profileId,
      phoneNumber: phoneNumber,
      email: email,
      verificationLevel: IdentityVerificationLevel.unverified,
    );

    _identitiesByLifexId[lifexId] = identity;
    _lifexIdByProfileId[profileId] = lifexId;
    _considerOwner(identity);
    return identity;
  }

  void _considerOwner(HealthIdentity identity) {
    GlobalAdminManager.instance.activateOwnerForBoundIdentity(
      lifexId: identity.lifexId,
      linkedProfileId: identity.linkedProfileId,
      email: identity.email,
      phoneNumber: identity.phoneNumber,
    );
  }

  /// توليد معرّف Lifex-ID فريد بصيغة LFX-XXXXXX.
  String _generateUniqueLifexId() {
    String candidate;
    do {
      final suffix = List.generate(6, (_) => _random.nextInt(10)).join();
      candidate = '$_idPrefix-$suffix';
    } while (_identitiesByLifexId.containsKey(candidate));
    return candidate;
  }

  /// كل الهويات المحلية المعروفة على الجهاز — للبحث في دليل Lifex فقط.
  /// لا يمنح أي وصول لبيانات صحية.
  List<HealthIdentity> get allIdentities =>
      List.unmodifiable(_identitiesByLifexId.values);

  /// استرجاع الهوية عبر معرّف Lifex-ID.
  HealthIdentity? getByLifexId(String lifexId) =>
      _identitiesByLifexId[lifexId];

  /// استرجاع الهوية عبر معرّف الملف الصحي المرتبط.
  HealthIdentity? getByProfileId(String profileId) {
    final lifexId = _lifexIdByProfileId[profileId];
    if (lifexId == null) return null;
    return _identitiesByLifexId[lifexId];
  }

  /// ترقية مستوى التحقق (مثلاً بعد تأكيد OTP أو رفع وثيقة رسمية).
  bool upgradeVerification(
    String lifexId,
    IdentityVerificationLevel newLevel,
  ) {
    final identity = _identitiesByLifexId[lifexId];
    if (identity == null) {
      ErrorHandler.instance.report(
        'IDENTITY_NOT_FOUND',
        'محاولة ترقية تحقق لهوية غير موجودة: $lifexId',
        sourceModule: 'health_identity_manager',
        severity: ErrorSeverity.warning,
      );
      return false;
    }

    // منع التراجع لمستوى أقل بالخطأ.
    if (newLevel.index < identity.verificationLevel.index) {
      return false;
    }

    identity.verificationLevel = newLevel;
    if (newLevel == IdentityVerificationLevel.fullyVerified) {
      identity.verifiedAt = DateTime.now();
    }
    return true;
  }

  /// تحديث بريد/هاتف الهوية وإعادة محاولة تفعيل دور المخترع/المالك.
  /// الاسم وحده لا يكفي — يجب تطابق بريد أو هاتف المالك المسجَّلين.
  HealthIdentity? updateContactAndReactivateOwner({
    required String lifexId,
    String? email,
    String? phoneNumber,
  }) {
    final identity = _identitiesByLifexId[lifexId];
    if (identity == null) return null;
    if (email != null) identity.email = email.trim().isEmpty ? null : email.trim();
    if (phoneNumber != null) {
      identity.phoneNumber =
          phoneNumber.trim().isEmpty ? null : phoneNumber.trim();
    }
    _considerOwner(identity);
    return identity;
  }

  /// إنشاء هوية إن لزم، ثم تفعيل المالك إن طابق البريد/الهاتف.
  HealthIdentity ensureIdentityAndMaybeActivateOwner({
    required String profileId,
    String? phoneNumber,
    String? email,
  }) {
    final existing = getByProfileId(profileId);
    if (existing != null) {
      return updateContactAndReactivateOwner(
            lifexId: existing.lifexId,
            email: email ?? existing.email,
            phoneNumber: phoneNumber ?? existing.phoneNumber,
          ) ??
          existing;
    }
    return createIdentity(
      profileId: profileId,
      phoneNumber: phoneNumber,
      email: email,
    );
  }

  /// معرّف Lifex التشغيلي مختلف عن معرّف الملف.
  bool actorIsOperationalLifexId(String actorId) {
    final identity = getByLifexId(actorId);
    if (identity == null) return false;
    return identity.lifexId == actorId && identity.linkedProfileId != actorId;
  }

  /// إعادة كل الهويات لحالته الأولية — للاختبارات فقط.
  void resetForTesting() {
    _identitiesByLifexId.clear();
    _lifexIdByProfileId.clear();
  }
}
