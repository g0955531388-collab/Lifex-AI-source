/// =============================================================
/// Lifex-AI — حماية الجهاز
/// الملف: lost_phone_policy.dart
/// سياسة فقدان الهاتف من النسخة المكتبية: قريب/بعيد، بلا تصوير الخاطف.
/// =============================================================
library lifex_ai.features.device_guardian.lost_phone_policy;

import 'lost_phone_desk.dart';

class LostPhonePolicy {
  const LostPhonePolicy();

  static const String farSmsKeyword = 'أين جوالي';

  bool pinMatches(String storedPin, String input) =>
      storedPin.isNotEmpty && storedPin == input.trim();

  String nearbyActionAr() =>
      'قريب: رسالة أنا هنا + إنذار صوتي ظاهر. بلا تصوير من يمسك الهاتف.';

  String farSmsTemplate() =>
      '$farSmsKeyword ثم الرمز عبر قناة مصادق عليها. قراءة الرسائل النصية غير مفعّلة في هذا البناء. '
      'نجاح الإرسال يُسجَّل فقط إذا أعادت القناة نجاحاً. '
      '${LostPhoneDesk.limitAr}';

  String simChangeWithoutPinAr() =>
      'تغيير الشريحة بلا الرمز ينبّه النسخة الاحتياطية وعشرة أرقام موثوقة. '
      'ليس قفلاً خفياً للجهاز ولا Device Admin.';
}
