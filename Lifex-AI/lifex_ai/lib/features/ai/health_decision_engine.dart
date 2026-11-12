/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: health_decision_engine.dart
/// المسار: lib/features/ai/health_decision_engine.dart
/// الوصف: محرك يجمع مخرجات المحركات الفرعية الأخرى (تحليل، توجيه) ليقرر
/// "الإجراء التالي" على مستوى التطبيق: هل نعرض توعية فقط؟ هل نفعّل وحدة
/// الطوارئ؟ هل نقترح حجز موعد؟ — هذا تنسيق قرار تشغيلي، وليس قراراً طبياً.
/// =============================================================
library;

import '../../core/health_event_manager.dart';
import 'ai_engine.dart';
import 'doctor_guidance_engine.dart';
import 'health_analysis_engine.dart';

/// الإجراء التشغيلي الذي يقترحه المحرك على مستوى واجهة التطبيق.
enum AppAction {
  showEducationalInfoOnly,
  suggestDoctorBooking,
  triggerEmergencyFlow,
  suggestSpecialistReferral,
  askForMoreDetails,
}

/// نتيجة القرار النهائية التي تستهلكها الواجهة مباشرة.
class HealthDecision {
  final AppAction action;
  final AiResponse response;
  final MedicalSpecialty? suggestedSpecialty;

  const HealthDecision({
    required this.action,
    required this.response,
    this.suggestedSpecialty,
  });
}

/// محرك القرار الصحي — الطبقة الأعلى التي تربط بين تحليل الأعراض
/// والتوجيه الطبي وتُصدر قراراً تشغيلياً واحداً واضحاً للواجهة.
class HealthDecisionEngine {
  HealthDecisionEngine({
    required this.analysisEngine,
    required this.guidanceEngine,
  });

  final HealthAnalysisEngine analysisEngine;
  final DoctorGuidanceEngine guidanceEngine;

  /// اتخاذ القرار الكامل بناءً على مدخلات المستخدم النصية.
  HealthDecision decide({
    required String userInput,
    String? profileId,
  }) {
    final analysis = analysisEngine.analyze(userInput);

    if (analysis.isEmergencyIndicator) {
      HealthEventManager.instance.emitQuick(
        HealthEventType.emergencyTriggered,
        sourceModule: 'health_decision_engine',
        profileId: profileId,
        data: {'reason': 'symptom_analysis_emergency_flag'},
      );
      return HealthDecision(
        action: AppAction.triggerEmergencyFlow,
        response: analysis.response,
      );
    }

    if (analysis.matchedSymptomIds.isEmpty) {
      return HealthDecision(
        action: AppAction.askForMoreDetails,
        response: analysis.response,
      );
    }

    final guidance = guidanceEngine.guidanceFromAnalysisPublic(analysis);

    // إذا كان هناك ما يكفي من الأعراض المطابقة (٢ أو أكثر) نقترح حجز
    // موعد مباشرة مع التخصص المناسب، وإلا نكتفي بعرض توعية عامة.
    if (analysis.matchedSymptomIds.length >= 2) {
      return HealthDecision(
        action: AppAction.suggestSpecialistReferral,
        response: guidance.response,
        suggestedSpecialty: guidance.recommendedSpecialty,
      );
    }

    return HealthDecision(
      action: AppAction.showEducationalInfoOnly,
      response: guidance.response,
      suggestedSpecialty: guidance.recommendedSpecialty,
    );
  }

  /// تسجيل هذا المحرك ضمن AiEngine المركزي (اختياري — يُستخدم إذا أردنا
  /// توحيد نقطة الدخول بدل استدعاء decide() مباشرة من الواجهة).
  void registerWithAiEngine(AiEngine engine) {
    engine.registerHandler(
      AiQueryType.symptomCheck,
      (query, context) => decide(userInput: query).response,
    );
  }
}

/// امتداد صغير يكشف دالة guideFromAnalysis بشكل عام دون تغيير توقيعها
/// الأصلي في DoctorGuidanceEngine (تجنّباً لتعديل ملف سابق).
extension DoctorGuidancePublicAccess on DoctorGuidanceEngine {
  DoctorGuidanceResult guidanceFromAnalysisPublic(
    SymptomAnalysisResult analysis,
  ) =>
      guideFromAnalysis(analysis);
}
