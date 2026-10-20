/// =============================================================
/// Lifex-AI — سياسة هوية المالك/المخترع
/// الإسناد الفكري ثابت في ProjectAttribution.
/// الدور التشغيلي owner يُفعَّل فقط لغازي سليم بكفلاوي عبر بريد/هاتف.
/// =============================================================
library lifex_ai.core.admin.owner_identity_policy;

import '../app_constants.dart';
import '../attribution/project_attribution.dart';

/// يفصل: إسناد الملكية الفكرية ≠ صلاحية تشغيلية.
class OwnerIdentityPolicy {
  const OwnerIdentityPolicy();

  String get inventorOwnerAr => ProjectAttribution.inventorOwnerAr;
  String get inventorTitleAr => ProjectAttribution.inventorTitleAr;
  String get guideAr => ProjectAttribution.guideAr;

  /// البريد/الهاتف المعتمدان لتفعيل دور owner التشغيلي فقط.
  List<String> get ownerEmailsNormalized => AppConstants.ownerEmails
      .map((e) => e.trim().toLowerCase())
      .toList(growable: false);

  String get ownerPhoneDigits =>
      _foldOwnerPhone(AppConstants.ownerPhoneNumber);

  bool matchesOwnerEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final e = email.trim().toLowerCase();
    return ownerEmailsNormalized.contains(e) ||
        e == AppConstants.officialContactEmail.trim().toLowerCase();
  }

  bool matchesOwnerPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final n = _foldOwnerPhone(phone);
    final digits = ownerPhoneDigits;
    return n == digits ||
        n == digits.replaceFirst('+963', '0') ||
        n == digits.replaceFirst('+963', '');
  }

  bool isInventorOwnerContact({String? email, String? phoneNumber}) =>
      matchesOwnerEmail(email) || matchesOwnerPhone(phoneNumber);

  String activationHintAr() =>
      'لتفعيل صلاحيات المخترع/المالك التشغيلية، سجّل في الهوية '
      'البريد ${AppConstants.ownerEmail} أو الهاتف '
      '${AppConstants.ownerPhoneNumber}. '
      'الإسناد الرسمي يبقى: ${ProjectAttribution.inventorOwnerAr} — '
      'وليس دوراً يُمنح يدوياً لأي شخص.';
}

/// يحوّل ٠١٢٣٤٥٦٧٨٩ إلى 0123456789 ثم يحذف المسافات والشرطات.
/// التطبيع لا يضيف صيغة ولا يُثبت تحققاً برمز.
String _foldOwnerPhone(String raw) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    final index = arabicIndic.indexOf(char);
    buffer.write(index >= 0 ? '$index' : char);
  }
  return buffer.toString().replaceAll(RegExp(r'[\s-]'), '');
}
