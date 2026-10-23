/// رعاية الأنثى والحمل والطفل: حسابات محددة وقواعد سلامة.
/// التأخير ليس حملاً مؤكداً. التطبيق لا يوقف دواءً ولا يغيّر جرعة.
library lifex_ai.features.women_health.women_care_desk;

enum PregnancyBasis { homeTest, laboratory, clinician, unsure }

class PregnancyOpenResult {
  const PregnancyOpenResult({
    required this.confirmed,
    required this.provisional,
    required this.messageAr,
  });

  final bool confirmed;
  final bool provisional;
  final String messageAr;
}

class GestationalAge {
  const GestationalAge({
    required this.week,
    required this.day,
    required this.dueDate,
    required this.underReview,
    required this.sourceAr,
  });

  final int week;
  final int day;
  final DateTime dueDate;
  final bool underReview;
  final String sourceAr;

  String get labelAr => 'الأسبوع $week، اليوم $day';
}

class WomenCareDesk {
  const WomenCareDesk();

  static const lockScreenTitleAr = 'لديك رسالة خاصة';

  static const doNotStopMedicineAr =
      'لا توقفي دواءً موصوفاً ولا تغيّري جرعته من تلقاء نفسك، '
      'لأن ذلك قد يسبب ضرراً أيضاً.';

  PregnancyOpenResult openFromBasis(PregnancyBasis basis) {
    switch (basis) {
      case PregnancyBasis.homeTest:
      case PregnancyBasis.laboratory:
      case PregnancyBasis.clinician:
        return const PregnancyOpenResult(
          confirmed: true,
          provisional: false,
          messageAr:
              'سُجّل أساس التأكيد الذي اخترته. عمر الحمل تقدير، والطبيبة قد تعدّله.',
        );
      case PregnancyBasis.unsure:
        return const PregnancyOpenResult(
          confirmed: false,
          provisional: true,
          messageAr:
              'لم يُسجَّل حمل مؤكد. يمكنكِ إجراء اختبار حمل واتباع تعليماته، '
              'ثم العودة بالنتيجة. التأخير وحده لا يثبت الحمل.',
        );
    }
  }

  /// عمر الحمل من آخر دورة: الأسابيع واليوم. تاريخ الطبيبة يُقدَّم إن وُجد.
  GestationalAge age({
    required DateTime lmp,
    required DateTime now,
    DateTime? clinicianDueDate,
  }) {
    final lmpDue = lmp.add(const Duration(days: 280));
    final due = clinicianDueDate ?? lmpDue;
    final revisedLmp = clinicianDueDate == null
        ? lmp
        : clinicianDueDate.subtract(const Duration(days: 280));
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(revisedLmp.year, revisedLmp.month, revisedLmp.day))
        .inDays;
    final safe = days < 0 ? 0 : days;
    return GestationalAge(
      week: safe ~/ 7,
      day: safe % 7,
      dueDate: due,
      underReview: clinicianDueDate != null &&
          clinicianDueDate.difference(lmpDue).inDays.abs() > 0,
      sourceAr: clinicianDueDate == null
          ? 'تقدير من تاريخ آخر دورة. ليس من تاريخ الإخصاب.'
          : 'تاريخ عدّلته جهة الرعاية. التقدير السابق يبقى في السجل.',
    );
  }

  /// نزيف الحمل وأشباهه: توجيه فوري، بلا انتظار رسالة الغد.
  String? urgentPath(String symptom) {
    const urgent = [
      'نزيف',
      'ألم شديد',
      'إغماء',
      'ضيق نفس',
      'ألم صدر',
      'صداع شديد',
      'تشوش',
      'تسرب سائل',
      'حمى',
      'حركة الجنين',
      'إيذاء',
      'ازرقاق',
      'تشنج',
    ];
    final folded = symptom.trim();
    if (folded.isEmpty) return null;
    if (!urgent.any(folded.contains)) return null;
    return 'هذه علامة تستدعي المساعدة الآن. اتصلي بالطوارئ أو وحدة الأمومة '
        'ولا تنتظري رد التطبيق. $lockScreenTitleAr ليس بديلاً عن الاتصال.';
  }

  String dailyCheckInAr() =>
      'كيف تشعرين اليوم؟ غياب الأعراض في السجل لا يعني أن الحمل سليم.';

  String medicationReviewAr(
      {required bool knownCaution, required bool sourceEnough}) {
    if (!sourceEnough) {
      return 'لا أستطيع تأكيد تعارض هذا الدواء. راجعي مختصاً. $doNotStopMedicineAr';
    }
    if (knownCaution) {
      return 'قد يحتاج هذا الدواء إلى مراجعة عاجلة بسبب الحمل. '
          'تواصلي مع الطبيب أو الصيدلي اليوم. $doNotStopMedicineAr';
    }
    return 'لا بند كافٍ في المصدر المحلي. أبلغي الطبيبة بكل دواء. $doNotStopMedicineAr';
  }

  /// ملف الطفل مستقل عن ملف الأم.
  String babyProfileId(
      {required String motherProfileId, required DateTime bornAt}) {
    return 'baby-$motherProfileId-${bornAt.microsecondsSinceEpoch}';
  }
}
