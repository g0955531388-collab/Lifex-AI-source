/// =============================================================
/// Lifex-AI — رعاية النساء والحمل
/// الملف: pregnancy_ai_assistant.dart
/// المسار: lib/features/women_health/pregnancy_ai_assistant.dart
/// الوصف: مساعد توعوي أسبوعي للحامل — يعرض معلومات عامة عن مرحلة الحمل
/// الحالية (نمو الجنين تقريبياً، نصائح غذائية عامة) بالاعتماد على
/// الأسبوع الحالي من pregnancy_profile.dart. هذا توعية عامة فقط، وليس
/// خطة رعاية طبية شخصية.
/// =============================================================
library;

import 'pregnancy_profile.dart';

/// محتوى توعوي عام مرتبط بنطاق أسابيع معيّن من الحمل.
class WeeklyPregnancyInsight {
  final int weekRangeStart;
  final int weekRangeEnd;
  final String generalInfoAr;
  final List<String> generalTipsAr;

  const WeeklyPregnancyInsight({
    required this.weekRangeStart,
    required this.weekRangeEnd,
    required this.generalInfoAr,
    required this.generalTipsAr,
  });

  bool coversWeek(int week) => week >= weekRangeStart && week <= weekRangeEnd;
}

/// قائمة معلومات توعوية عامة مبسّطة حسب مرحلة الحمل. هذا محتوى تثقيفي
/// عام مُعد مسبقاً (Static content)، وليس نتاج تحليل ذكاء اصطناعي حي،
/// تجنباً لأي إيحاء بأنه استشارة طبية مخصصة.
const List<WeeklyPregnancyInsight> _weeklyInsights = [
  WeeklyPregnancyInsight(
    weekRangeStart: 1,
    weekRangeEnd: 13,
    generalInfoAr: 'الثلث الأول: مرحلة التكوّن الأساسي لأعضاء الجنين.',
    generalTipsAr: [
      'الحرص على حمض الفوليك حسب توجيه الطبيب',
      'الراحة الكافية والابتعاد عن الإجهاد الزائد',
      'حجز أول موعد متابعة مبكراً',
    ],
  ),
  WeeklyPregnancyInsight(
    weekRangeStart: 14,
    weekRangeEnd: 27,
    generalInfoAr: 'الثلث الثاني: غالباً فترة أكثر راحة، ويبدأ الشعور بحركة الجنين.',
    generalTipsAr: [
      'متابعة فحوصات السكر والضغط حسب جدول الطبيب',
      'نشاط بدني خفيف إن سمح الطبيب بذلك',
      'الانتباه لبداية الشعور بحركة الجنين وتسجيلها',
    ],
  ),
  WeeklyPregnancyInsight(
    weekRangeStart: 28,
    weekRangeEnd: 40,
    generalInfoAr: 'الثلث الثالث: استعداد الجسم للولادة ومتابعة حركة الجنين اليومية.',
    generalTipsAr: [
      'تسجيل حركة الجنين يومياً كجزء من المتابعة',
      'تجهيز حقيبة الولادة ومناقشة خطة الولادة مع الطبيب',
      'الانتباه الفوري لأي من علامات الخطر ومراجعة الطبيب عندها',
    ],
  ),
];

/// نتيجة استعلام توعوي أسبوعي.
class PregnancyAssistantResponse {
  final String summaryAr;
  final List<String> tipsAr;
  final String disclaimer;

  const PregnancyAssistantResponse({
    required this.summaryAr,
    required this.tipsAr,
    this.disclaimer =
        'هذه معلومات توعوية عامة ولا تُغني عن خطة المتابعة الشخصية التي '
        'يضعها طبيبك أو طبيبتك المتابعة لحالتك تحديداً.',
  });
}

/// مساعد الحامل الذكي — يربط الأسبوع الحالي من سجل الحمل بالمحتوى
/// التوعوي المناسب.
class PregnancyAiAssistant {
  PregnancyAiAssistant();

  /// الحصول على التوعية المناسبة للأسبوع الحالي من حمل معيّن.
  PregnancyAssistantResponse getWeeklyGuidance(PregnancyRecord pregnancy) {
    final week = pregnancy.currentGestationalWeek;

    final insight = _weeklyInsights.firstWhere(
      (i) => i.coversWeek(week),
      orElse: () => _weeklyInsights.last,
    );

    return PregnancyAssistantResponse(
      summaryAr:
          'الأسبوع التقريبي الحالي: $week. ${insight.generalInfoAr}',
      tipsAr: insight.generalTipsAr,
    );
  }

  /// الإجابة على سؤال حر من الحامل — نسخة مبسّطة حالياً تعيد توعية
  /// عامة فقط؛ يمكن لاحقاً ربطها بـ ai_engine.dart المركزي لمعالجة أعمق
  /// دون كسر هذه الواجهة.
  PregnancyAssistantResponse answerGeneralQuestion(
    String question,
    PregnancyRecord pregnancy,
  ) {
    return getWeeklyGuidance(pregnancy);
  }
}
