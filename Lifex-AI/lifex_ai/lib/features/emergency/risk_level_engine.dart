/// =============================================================
/// Lifex-AI — الطوارئ
/// الملف: risk_level_engine.dart
/// المسار: lib/features/emergency/risk_level_engine.dart
/// الوصف: تقييم بسيط وشفاف لمستوى خطورة حالة الطوارئ بناءً على السياق
/// المُمرَّر إليه (نوع المؤشر، العمر، وجود حالات مزمنة...) — قواعد
/// صريحة وليست نموذج تعلّم آلي، لضمان قابلية التفسير الكاملة.
/// =============================================================
library;

import '../../core/app_constants.dart';

class RiskAssessment {
  final String level; // uses AppConstants.riskLevel*
  final String reasonAr;

  const RiskAssessment({required this.level, required this.reasonAr});
}

/// محرك تقييم الخطر — قائم على قواعد صريحة وبسيطة، يمكن لأي مطور أو
/// مختص طبي مراجعتها بسهولة دون الحاجة لفهم نموذج تعلّم آلي.
class RiskLevelEngine {
  RiskLevelEngine();

  RiskAssessment assess(Map<String, dynamic> context) {
    final triggerType = context['triggerType'] as String?;
    final hasChronicCondition = context['hasChronicCondition'] as bool? ?? false;
    final age = context['age'] as int?;

    // مؤشرات قلبية أو تنفسية حادة تُصنَّف حرجة دائماً بغض النظر عن أي
    // عامل آخر.
    const criticalTriggers = [
      'cardiac_symptom',
      'respiratory_distress',
      'severe_bleeding',
      'loss_of_consciousness',
    ];

    if (triggerType != null && criticalTriggers.contains(triggerType)) {
      return const RiskAssessment(
        level: AppConstants.riskLevelCritical,
        reasonAr: 'مؤشر يستدعي استجابة طوارئ فورية دون تأخير.',
      );
    }

    if (hasChronicCondition && (age == null || age >= 60)) {
      return const RiskAssessment(
        level: AppConstants.riskLevelHigh,
        reasonAr: 'وجود حالة مزمنة مع عامل عمري يرفع مستوى الحذر المطلوب.',
      );
    }

    if (triggerType != null) {
      return const RiskAssessment(
        level: AppConstants.riskLevelMedium,
        reasonAr: 'مؤشر يستدعي متابعة قريبة وليس بالضرورة تدخلاً فورياً.',
      );
    }

    return const RiskAssessment(
      level: AppConstants.riskLevelLow,
      reasonAr: 'لا توجد مؤشرات كافية لتصنيف الحالة كخطيرة حالياً.',
    );
  }
}
