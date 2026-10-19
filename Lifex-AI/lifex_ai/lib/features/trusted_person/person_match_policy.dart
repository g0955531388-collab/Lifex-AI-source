/// =============================================================
/// Lifex-AI — مطابقة الأشخاص بحذر
/// الملف: person_match_policy.dart
/// المسار: lib/features/trusted_person/person_match_policy.dart
/// الوصف: لا دمج تلقائي على اسم متشابه فقط.
/// =============================================================
library lifex_ai.features.trusted_person.person_match_policy;

import 'trusted_person_models.dart';

class PersonMatchPolicy {
  const PersonMatchPolicy();

  String normalizePhone(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'[\s\-()]'), '');
  }

  String normalizeName(String? raw) {
    if (raw == null) return '';
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  PersonMatchResult match({
    required PersonSelectionCandidate candidate,
    String? existingIdentityId,
    String? existingPhone,
    String? existingEmail,
    String? existingDisplayName,
  }) {
    final candId = candidate.identityId?.trim();
    if (candId != null &&
        candId.isNotEmpty &&
        existingIdentityId != null &&
        existingIdentityId.trim() == candId) {
      return PersonMatchResult.matchConfirmed;
    }

    final candPhone = normalizePhone(candidate.phoneNumber);
    final knownPhone = normalizePhone(existingPhone);
    if (candPhone.isNotEmpty && candPhone == knownPhone) {
      return PersonMatchResult.matchConfirmed;
    }

    final candEmail = candidate.email?.trim().toLowerCase() ?? '';
    final knownEmail = existingEmail?.trim().toLowerCase() ?? '';
    if (candEmail.isNotEmpty && candEmail == knownEmail) {
      return PersonMatchResult.matchConfirmed;
    }

    final candName = normalizeName(candidate.displayName);
    final knownName = normalizeName(existingDisplayName);
    if (candName.isNotEmpty && candName == knownName) {
      // Name alone is never confirmed.
      return PersonMatchResult.matchPossible;
    }

    return PersonMatchResult.noMatch;
  }

  /// ممنوع إنشاء Person جديد تلقائياً عند تطابق محتمل فقط.
  bool shouldAutoMerge(PersonMatchResult result) =>
      result == PersonMatchResult.matchConfirmed;
}
