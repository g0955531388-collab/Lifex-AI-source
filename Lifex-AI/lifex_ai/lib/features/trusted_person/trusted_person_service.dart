/// =============================================================
/// Lifex-AI — خدمة الأشخاص الموثوقين
/// الملف: trusted_person_service.dart
/// المسار: lib/features/trusted_person/trusted_person_service.dart
/// الوصف: Domain/Application — إنشاء/تحديث/إلغاء ثقة + فصل جهة الطوارئ.
/// الواجهة لا تكتب مباشرة في SQL/خرائط عشوائية بلا خدمة.
/// =============================================================
library lifex_ai.features.trusted_person.trusted_person_service;

import 'person_match_policy.dart';
import 'trusted_person_models.dart';

class TrustedPersonActionResult {
  const TrustedPersonActionResult._({
    required this.success,
    required this.messageAr,
    this.person,
    this.emergencyLink,
    this.auditEventId,
  });

  final bool success;
  final String messageAr;
  final TrustedPerson? person;
  final EmergencyContactLink? emergencyLink;
  final String? auditEventId;

  factory TrustedPersonActionResult.ok(
    String messageAr, {
    TrustedPerson? person,
    EmergencyContactLink? emergencyLink,
    String? auditEventId,
  }) =>
      TrustedPersonActionResult._(
        success: true,
        messageAr: messageAr,
        person: person,
        emergencyLink: emergencyLink,
        auditEventId: auditEventId,
      );

  factory TrustedPersonActionResult.rejected(String messageAr) =>
      TrustedPersonActionResult._(success: false, messageAr: messageAr);
}

class TrustedPersonAuditEvent {
  TrustedPersonAuditEvent({
    required this.eventId,
    required this.action,
    required this.ownerProfileId,
    required this.at,
    this.trustedPersonId,
    this.details = const {},
  });

  final String eventId;
  final String action;
  final String ownerProfileId;
  final String? trustedPersonId;
  final DateTime at;
  final Map<String, String> details;
}

class TrustedPersonService {
  TrustedPersonService({PersonMatchPolicy? matchPolicy})
      : _matchPolicy = matchPolicy ?? const PersonMatchPolicy();

  final PersonMatchPolicy _matchPolicy;
  final Map<String, List<TrustedPerson>> _byOwner = {};
  final Map<String, List<EmergencyContactLink>> _emergencyByOwner = {};
  final List<TrustedPersonAuditEvent> _audit = [];
  int _seq = 0;

  List<TrustedPerson> listFor(String ownerProfileId) =>
      List.unmodifiable(_byOwner[ownerProfileId] ?? const []);

  List<EmergencyContactLink> emergencyLinksFor(String ownerProfileId) =>
      List.unmodifiable(_emergencyByOwner[ownerProfileId] ?? const []);

  List<TrustedPersonAuditEvent> auditTrail() => List.unmodifiable(_audit);

  TrustedPersonActionResult createFromCandidate({
    required String ownerProfileId,
    required PersonSelectionCandidate candidate,
    TrustedRelationshipType relationshipType = TrustedRelationshipType.other,
    TrustedPurpose purpose = TrustedPurpose.emergencyNotify,
    int priority = 0,
    bool markAsEmergencyContact = false,
    DateTime? expiresAt,
    String? existingIdentityId,
    String? existingPhone,
    String? existingEmail,
    String? existingDisplayName,
  }) {
    if (!candidate.hasContactHandle) {
      return TrustedPersonActionResult.rejected(
        'لا يمكن إنشاء شخص موثوق بلا رقم أو بريد أو هوية Lifex.',
      );
    }

    final match = _matchPolicy.match(
      candidate: candidate,
      existingIdentityId: existingIdentityId,
      existingPhone: existingPhone,
      existingEmail: existingEmail,
      existingDisplayName: existingDisplayName,
    );

    String? personId = candidate.personId;
    String? identityId = candidate.identityId;
    if (match == PersonMatchResult.matchPossible) {
      // Do not auto-create/merge Person — keep candidate refs only.
      personId = null;
    } else if (match == PersonMatchResult.matchConfirmed) {
      identityId = identityId ?? existingIdentityId;
    }

    final id = 'tp-${++_seq}-${DateTime.now().millisecondsSinceEpoch}';
    final person = TrustedPerson(
      trustedPersonId: id,
      ownerProfileId: ownerProfileId,
      displayName: candidate.displayName.trim(),
      phoneNumber: candidate.phoneNumber?.trim(),
      email: candidate.email?.trim(),
      sourceType: candidate.sourceType,
      sourceReference: candidate.sourceReference,
      identityId: identityId,
      personId: personId,
      accountId: candidate.accountId,
      relationshipType: relationshipType,
      purpose: purpose,
      priority: priority,
      isEmergencyContact: markAsEmergencyContact,
      isTrusted: true,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      status: TrustedPersonStatus.active,
      provenance: {
        'source': candidate.sourceType.wireName,
        'match': match.name,
        'minimized': 'true',
      },
    );

    _byOwner.putIfAbsent(ownerProfileId, () => []).add(person);
    final auditId = _record(
      action: 'TRUSTED_PERSON_CREATE',
      ownerProfileId: ownerProfileId,
      trustedPersonId: id,
      details: {
        'source': candidate.sourceType.wireName,
        'healthAccess': 'false',
      },
    );

    EmergencyContactLink? link;
    if (markAsEmergencyContact) {
      final linked = linkAsEmergencyContact(
        ownerProfileId: ownerProfileId,
        trustedPersonId: id,
      );
      if (!linked.success) {
        return TrustedPersonActionResult.ok(
          'أُنشئ الشخص الموثوق، لكن ربط الطوارئ رُفض: ${linked.messageAr}',
          person: person,
          auditEventId: auditId,
        );
      }
      link = linked.emergencyLink;
    }

    return TrustedPersonActionResult.ok(
      'تم إنشاء شخص موثوق من مصدر ${candidate.sourceType.labelAr}.',
      person: person,
      emergencyLink: link,
      auditEventId: auditId,
    );
  }

  TrustedPersonActionResult revoke({
    required String ownerProfileId,
    required String trustedPersonId,
  }) {
    final list = _byOwner[ownerProfileId];
    if (list == null) {
      return TrustedPersonActionResult.rejected('لا يوجد أشخاص موثوقون.');
    }
    final index = list.indexWhere((p) => p.trustedPersonId == trustedPersonId);
    if (index < 0) {
      return TrustedPersonActionResult.rejected('الشخص الموثوق غير موجود.');
    }
    final updated = list[index].copyWith(
      isTrusted: false,
      status: TrustedPersonStatus.revoked,
      updatedAt: DateTime.now(),
      isEmergencyContact: false,
    );
    list[index] = updated;
    _emergencyByOwner[ownerProfileId]
        ?.removeWhere((e) => e.trustedPersonId == trustedPersonId);

    final auditId = _record(
      action: 'TRUSTED_PERSON_REVOKE',
      ownerProfileId: ownerProfileId,
      trustedPersonId: trustedPersonId,
    );
    return TrustedPersonActionResult.ok(
      'أُلغيت الثقة فوراً. لا وصول صحي كان ممنوحاً أصلاً من حالة الثقة.',
      person: updated,
      auditEventId: auditId,
    );
  }

  TrustedPersonActionResult updateMeta({
    required String ownerProfileId,
    required String trustedPersonId,
    TrustedRelationshipType? relationshipType,
    TrustedPurpose? purpose,
    int? priority,
    DateTime? expiresAt,
  }) {
    final list = _byOwner[ownerProfileId];
    if (list == null) {
      return TrustedPersonActionResult.rejected('لا يوجد أشخاص موثوقون.');
    }
    final index = list.indexWhere((p) => p.trustedPersonId == trustedPersonId);
    if (index < 0) {
      return TrustedPersonActionResult.rejected('الشخص الموثوق غير موجود.');
    }
    final current = list[index];
    if (current.status == TrustedPersonStatus.revoked) {
      return TrustedPersonActionResult.rejected(
        'لا يمكن تعديل شخص موثوق ملغى الثقة.',
      );
    }
    final updated = current.copyWith(
      relationshipType: relationshipType,
      purpose: purpose,
      priority: priority,
      expiresAt: expiresAt,
      updatedAt: DateTime.now(),
    );
    list[index] = updated;
    final auditId = _record(
      action: 'TRUSTED_PERSON_UPDATE',
      ownerProfileId: ownerProfileId,
      trustedPersonId: trustedPersonId,
    );
    return TrustedPersonActionResult.ok(
      'تم تحديث بيانات العلاقة/الغرض.',
      person: updated,
      auditEventId: auditId,
    );
  }

  TrustedPersonActionResult linkAsEmergencyContact({
    required String ownerProfileId,
    required String trustedPersonId,
  }) {
    final list = _byOwner[ownerProfileId];
    if (list == null) {
      return TrustedPersonActionResult.rejected(
        'يجب أن يكون الشخص موثوقاً ونشطاً قبل ربطه كجهة طوارئ.',
      );
    }
    final index = list.indexWhere((p) => p.trustedPersonId == trustedPersonId);
    if (index < 0) {
      return TrustedPersonActionResult.rejected(
        'يجب أن يكون الشخص موثوقاً ونشطاً قبل ربطه كجهة طوارئ.',
      );
    }
    final person = list[index];
    if (!person.isEffectivelyTrusted) {
      return TrustedPersonActionResult.rejected(
        'يجب أن يكون الشخص موثوقاً ونشطاً قبل ربطه كجهة طوارئ.',
      );
    }
    final phone = person.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) {
      return TrustedPersonActionResult.rejected(
        'جهة الطوارئ تتطلب رقم هاتف.',
      );
    }

    final link = EmergencyContactLink(
      emergencyContactId:
          'ec-${++_seq}-${DateTime.now().millisecondsSinceEpoch}',
      trustedPersonId: trustedPersonId,
      ownerProfileId: ownerProfileId,
      phoneNumber: phone,
      createdAt: DateTime.now(),
      allowsEmergencyDataAccess: false,
    );
    _emergencyByOwner.putIfAbsent(ownerProfileId, () => []).add(link);

    list[index] = person.copyWith(
      isEmergencyContact: true,
      updatedAt: DateTime.now(),
    );

    final auditId = _record(
      action: 'EMERGENCY_CONTACT_CREATE',
      ownerProfileId: ownerProfileId,
      trustedPersonId: trustedPersonId,
      details: {
        'emergencyDataAccess': 'false',
        'trustedEqualsEmergencyAccess': 'false',
      },
    );
    return TrustedPersonActionResult.ok(
      'رُبطت جهة طوارئ للتواصل فقط — بلا وصول لبيانات صحية.',
      person: list[index],
      emergencyLink: link,
      auditEventId: auditId,
    );
  }

  /// Trusted status never grants health-record authorization.
  bool grantsHealthDataAccess(String trustedPersonId) {
    for (final list in _byOwner.values) {
      for (final p in list) {
        if (p.trustedPersonId == trustedPersonId) {
          return p.grantsHealthDataAccess;
        }
      }
    }
    return false;
  }

  bool emergencyGrantsHealthDataAccess(String emergencyContactId) {
    for (final list in _emergencyByOwner.values) {
      for (final e in list) {
        if (e.emergencyContactId == emergencyContactId) {
          return e.allowsEmergencyDataAccess;
        }
      }
    }
    return false;
  }

  String _record({
    required String action,
    required String ownerProfileId,
    String? trustedPersonId,
    Map<String, String> details = const {},
  }) {
    final id = 'aud-${++_seq}';
    _audit.add(
      TrustedPersonAuditEvent(
        eventId: id,
        action: action,
        ownerProfileId: ownerProfileId,
        trustedPersonId: trustedPersonId,
        at: DateTime.now(),
        details: details,
      ),
    );
    return id;
  }

  void resetForTesting() {
    _byOwner.clear();
    _emergencyByOwner.clear();
    _audit.clear();
    _seq = 0;
  }

  /// تخزين الحد الأدنى فقط من المرشّح — للتحقق في الاختبارات.
  static Map<String, String?> minimalStoredFields(
    PersonSelectionCandidate candidate,
  ) {
    return {
      'displayName': candidate.displayName,
      'phoneNumber': candidate.phoneNumber,
      'email': candidate.email,
      'sourceType': candidate.sourceType.wireName,
      'sourceReference': candidate.sourceReference,
      // Explicitly absent bulk fields:
      'fullAddressBook': null,
      'fullCallLog': null,
      'fullSmsInbox': null,
    };
  }
}
