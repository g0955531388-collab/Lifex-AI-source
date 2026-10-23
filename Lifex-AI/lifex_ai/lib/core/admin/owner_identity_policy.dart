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

  /// يوحّد أرقام سورية: أرقام عربية، 00، 963، والصفر الأول.
  String normalizePhoneDigits(String value) {
    final westernDigits = value.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (match) {
        final code = match[0]!.codeUnitAt(0);
        final zero = code >= 0x06f0 ? 0x06f0 : 0x0660;
        return String.fromCharCode(0x30 + code - zero);
      },
    );
    var digits = westernDigits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('963')) return digits;
    if (digits.startsWith('0')) return '963${digits.substring(1)}';
    if (digits.startsWith('9')) return '963$digits';
    return digits;
  }

  bool matchesOwnerEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final e = email.trim().toLowerCase();
    return ownerEmailsNormalized.contains(e) ||
        e == AppConstants.officialContactEmail.trim().toLowerCase();
  }

  bool matchesOwnerPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final candidate = normalizePhoneDigits(phone);
    final owner = normalizePhoneDigits(AppConstants.ownerPhoneNumber);
    if (candidate.isEmpty || owner.isEmpty) return false;
    if (candidate.length != owner.length) return false;
    return candidate == owner;
  }

  /// نتيجة المقارنة ليست مصادقة ولا تمنح دوراً.
  bool isInventorOwnerContact({String? email, String? phoneNumber}) =>
      matchesOwnerEmail(email) || matchesOwnerPhone(phoneNumber);

  /// لا يعرض بريد المالك ولا هاتفه.
  String activationHintAr() =>
      'دور المالك يُفتح للهوية المربوطة إذا طابق بريدها أو هاتفها '
      'وسيلة الاتصال المعتمدة تطابقاً كاملاً. '
      'الاسم، وعضوية العائلة، وذيل الرقم، وكتابة الوسيلة في خانة منفصلة لا تمنح الدور.';
}
