/// =============================================================
/// Lifex-AI — الأشخاص الموثوقون
/// الملف: trusted_person_models.dart
/// المسار: lib/features/trusted_person/trusted_person_models.dart
/// الوصف: كيانات منفصلة — TrustedPerson ≠ EmergencyContact ≠ Health Access.
/// المصدر يُحفظ دائماً. لا نسخ دفتر هاتف ولا سجل مكالمات ولا SMS كامل.
/// =============================================================
library lifex_ai.features.trusted_person.trusted_person_models;

/// مصدر اختيار الشخص الموثوق — يُخزَّن مع الحد الأدنى من البيانات.
enum TrustedPersonSourceType {
  phoneContact,
  callLog,
  sms,
  lifexDirectory,
  manual,
}

extension TrustedPersonSourceTypeLabel on TrustedPersonSourceType {
  String get wireName {
    switch (this) {
      case TrustedPersonSourceType.phoneContact:
        return 'PHONE_CONTACT';
      case TrustedPersonSourceType.callLog:
        return 'CALL_LOG';
      case TrustedPersonSourceType.sms:
        return 'SMS';
      case TrustedPersonSourceType.lifexDirectory:
        return 'LIFEX_DIRECTORY';
      case TrustedPersonSourceType.manual:
        return 'MANUAL';
    }
  }

  String get labelAr {
    switch (this) {
      case TrustedPersonSourceType.phoneContact:
        return 'جهات اتصال الهاتف';
      case TrustedPersonSourceType.callLog:
        return 'سجل المكالمات';
      case TrustedPersonSourceType.sms:
        return 'رسائل الهاتف';
      case TrustedPersonSourceType.lifexDirectory:
        return 'دليل Lifex-AI';
      case TrustedPersonSourceType.manual:
        return 'إدخال يدوي';
    }
  }

  static TrustedPersonSourceType? fromWire(String? raw) {
    switch (raw) {
      case 'PHONE_CONTACT':
        return TrustedPersonSourceType.phoneContact;
      case 'CALL_LOG':
        return TrustedPersonSourceType.callLog;
      case 'SMS':
        return TrustedPersonSourceType.sms;
      case 'LIFEX_DIRECTORY':
        return TrustedPersonSourceType.lifexDirectory;
      case 'MANUAL':
        return TrustedPersonSourceType.manual;
      default:
        return null;
    }
  }
}

enum TrustedPersonStatus { active, revoked, expired, disabled }

enum TrustedRelationshipType {
  family,
  friend,
  caregiver,
  clinician,
  colleague,
  other,
}

enum TrustedPurpose {
  emergencyNotify,
  checkIn,
  coordination,
  remoteMonitoringRequest,
  other,
}

/// مرشّح اختيار قبل التأكيد — ليس سجل ثقة بعد.
class PersonSelectionCandidate {
  const PersonSelectionCandidate({
    required this.sourceType,
    required this.displayName,
    this.phoneNumber,
    this.email,
    this.sourceReference,
    this.identityId,
    this.accountId,
    this.personId,
    this.extra = const {},
  });

  final TrustedPersonSourceType sourceType;
  final String displayName;
  final String? phoneNumber;
  final String? email;
  final String? sourceReference;
  final String? identityId;
  final String? accountId;
  final String? personId;
  final Map<String, String> extra;

  bool get hasContactHandle =>
      (phoneNumber != null && phoneNumber!.trim().isNotEmpty) ||
      (email != null && email!.trim().isNotEmpty) ||
      (identityId != null && identityId!.trim().isNotEmpty);
}

/// شخص موثوق — تواصل/ثقة فقط. لا يعني وصولاً صحياً.
class TrustedPerson {
  TrustedPerson({
    required this.trustedPersonId,
    required this.ownerProfileId,
    required this.displayName,
    required this.sourceType,
    required this.createdAt,
    this.personId,
    this.identityId,
    this.accountId,
    this.phoneNumber,
    this.email,
    this.sourceReference,
    this.relationshipType = TrustedRelationshipType.other,
    this.purpose = TrustedPurpose.emergencyNotify,
    this.priority = 0,
    this.isEmergencyContact = false,
    this.isTrusted = true,
    this.updatedAt,
    this.expiresAt,
    this.status = TrustedPersonStatus.active,
    this.provenance = const {},
  });

  final String trustedPersonId;
  final String ownerProfileId;
  final String? personId;
  final String? identityId;
  final String? accountId;
  final String displayName;
  final String? phoneNumber;
  final String? email;
  final TrustedPersonSourceType sourceType;
  final String? sourceReference;
  final TrustedRelationshipType relationshipType;
  final TrustedPurpose purpose;
  final int priority;
  final bool isEmergencyContact;
  final bool isTrusted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final TrustedPersonStatus status;
  final Map<String, String> provenance;

  bool get grantsHealthDataAccess => false;

  bool get isEffectivelyTrusted {
    if (!isTrusted) return false;
    if (status != TrustedPersonStatus.active) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  TrustedPerson copyWith({
    String? displayName,
    String? phoneNumber,
    String? email,
    String? identityId,
    String? personId,
    String? accountId,
    String? sourceReference,
    TrustedRelationshipType? relationshipType,
    TrustedPurpose? purpose,
    int? priority,
    bool? isEmergencyContact,
    bool? isTrusted,
    DateTime? updatedAt,
    DateTime? expiresAt,
    TrustedPersonStatus? status,
    Map<String, String>? provenance,
  }) {
    return TrustedPerson(
      trustedPersonId: trustedPersonId,
      ownerProfileId: ownerProfileId,
      displayName: displayName ?? this.displayName,
      sourceType: sourceType,
      createdAt: createdAt,
      personId: personId ?? this.personId,
      identityId: identityId ?? this.identityId,
      accountId: accountId ?? this.accountId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      sourceReference: sourceReference ?? this.sourceReference,
      relationshipType: relationshipType ?? this.relationshipType,
      purpose: purpose ?? this.purpose,
      priority: priority ?? this.priority,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
      isTrusted: isTrusted ?? this.isTrusted,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      provenance: provenance ?? this.provenance,
    );
  }

  Map<String, dynamic> toJson() => {
        'trustedPersonId': trustedPersonId,
        'ownerProfileId': ownerProfileId,
        'personId': personId,
        'identityId': identityId,
        'accountId': accountId,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'email': email,
        'sourceType': sourceType.wireName,
        'sourceReference': sourceReference,
        'relationshipType': relationshipType.name,
        'purpose': purpose.name,
        'priority': priority,
        'isEmergencyContact': isEmergencyContact,
        'isTrusted': isTrusted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'status': status.name,
        'provenance': provenance,
      };

  factory TrustedPerson.fromJson(Map<String, dynamic> json) {
    return TrustedPerson(
      trustedPersonId: json['trustedPersonId'] as String,
      ownerProfileId: json['ownerProfileId'] as String,
      personId: json['personId'] as String?,
      identityId: json['identityId'] as String?,
      accountId: json['accountId'] as String?,
      displayName: json['displayName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      sourceType: TrustedPersonSourceTypeLabel.fromWire(
            json['sourceType'] as String?,
          ) ??
          TrustedPersonSourceType.manual,
      sourceReference: json['sourceReference'] as String?,
      relationshipType: TrustedRelationshipType.values.firstWhere(
        (e) => e.name == json['relationshipType'],
        orElse: () => TrustedRelationshipType.other,
      ),
      purpose: TrustedPurpose.values.firstWhere(
        (e) => e.name == json['purpose'],
        orElse: () => TrustedPurpose.emergencyNotify,
      ),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isEmergencyContact: json['isEmergencyContact'] as bool? ?? false,
      isTrusted: json['isTrusted'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: TrustedPersonStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TrustedPersonStatus.active,
      ),
      provenance: (json['provenance'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }
}

/// جهة طوارئ منفصلة عن الثقة — لا تمنح وصولاً صحياً بمفردها.
class EmergencyContactLink {
  const EmergencyContactLink({
    required this.emergencyContactId,
    required this.trustedPersonId,
    required this.ownerProfileId,
    required this.phoneNumber,
    required this.createdAt,
    this.allowsEmergencyDataAccess = false,
  });

  final String emergencyContactId;
  final String trustedPersonId;
  final String ownerProfileId;
  final String phoneNumber;
  final DateTime createdAt;

  /// دائماً false افتراضياً — يتطلب تفويضاً منفصلاً (Consent + Authz).
  final bool allowsEmergencyDataAccess;
}

enum PersonMatchResult { matchConfirmed, matchPossible, noMatch }
