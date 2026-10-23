/// =============================================================
/// Lifex-AI — رعاية الإناث
/// الملف: private_female_notice.dart
/// الإشعار الظاهر: «لديك رسالة خاصة» فقط. المحتوى بعد الفتح.
/// لا تُذكر الدورة أو الحمل في العنوان العلني حتى لا يحدث إحراج اجتماعي.
/// =============================================================
library lifex_ai.features.women_health.private_female_notice;

class PrivateFemaleNotice {
  const PrivateFemaleNotice({
    required this.id,
    required this.bodyAr,
  });

  static const publicTitleAr = 'لديك رسالة خاصة';

  final String id;
  final String bodyAr;

  factory PrivateFemaleNotice.cycleSoon({required int daysUntil}) {
    final when = daysUntil == 0
        ? 'قد تكون الأيام القريبة مناسبة لمتابعة جسمك بهدوء.'
        : 'بعد نحو $daysUntil يوماً قد تحتاجين هدوءاً وراحة إضافية.';
    return PrivateFemaleNotice(
      id: 'soon-$daysUntil',
      bodyAr:
          '$when هذه رسالة لكِ وحدكِ من تواريخ سجّلتيها أنتِ. ليست تشخيصاً ولا إعلاناً لأحد.',
    );
  }

  factory PrivateFemaleNotice.lateCycle({required int daysLate}) {
    final lead = daysLate <= 7
        ? 'مرّ أسبوع على الموعد الذي يقدّره سجلكِ.'
        : 'مرّ أكثر من أسبوع على الموعد الذي يقدّره سجلكِ.';
    return PrivateFemaleNotice(
      id: 'late-$daysLate',
      bodyAr:
          '$lead يُستحسن فحص طبي هادئ: قد يكون تأخراً بسيطاً أو حاجة لمتابعة أو حمل. '
          'التطبيق لا يثبت شيئاً. إن تأكد الحمل عند الطبيبة، فعّلي زر الحمل هنا لترعاكِ الوحدة.',
    );
  }

  factory PrivateFemaleNotice.weeklyCare({required int week}) {
    return PrivateFemaleNotice(
      id: 'week-$week',
      bodyAr:
          'نصيحة هذا الأسبوع لراحتكِ وراحة من تعتنين به. افتحي الرعاية الأسبوعية داخل الوحدة.',
    );
  }

  factory PrivateFemaleNotice.dailyCare() {
    return const PrivateFemaleNotice(
      id: 'daily',
      bodyAr:
          'تذكير يومي لطيف: راحة، غذاء بسيط، وماء. التفاصيل داخل رسالتكِ الخاصة لا على الشاشة العامة.',
    );
  }

  factory PrivateFemaleNotice.cvReview({required List<String> flags}) {
    return PrivateFemaleNotice(
      id: 'cv',
      bodyAr:
          'بعد تأكيدكِ، راجعنا ملفكِ الصحي المحلي. ${flags.join(' ')} '
          'التوجيه: مراجعة الطبيبة قبل أي تغيير لدواء. ليست استشارة طبية من التطبيق.',
    );
  }
}
