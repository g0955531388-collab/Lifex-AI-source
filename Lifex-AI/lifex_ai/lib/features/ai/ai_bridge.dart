/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: ai_bridge.dart
/// المسار: lib/features/ai/ai_bridge.dart
/// الوصف: نقطة التهيئة الموحدة (composition root) التي تُنشئ كل المحركات
/// الفرعية وتربطها ببعضها وبـ AiEngine المركزي دفعة واحدة عند بدء التطبيق،
/// بدلاً من تكرار هذا الربط في كل شاشة على حدة.
/// =============================================================
library;

import 'ai_engine.dart';
import 'doctor_guidance_engine.dart';
import 'health_analysis_engine.dart';
import 'health_decision_engine.dart';

/// حزمة تحمل كل المحركات الجاهزة بعد التهيئة، لتُمرَّر لبقية التطبيق
/// (عبر Provider/GetIt/أي حل حقن اعتماديات يُختار لاحقاً).
class AiModuleBundle {
  final AiEngine engine;
  final HealthAnalysisEngine analysisEngine;
  final DoctorGuidanceEngine guidanceEngine;
  final HealthDecisionEngine decisionEngine;

  const AiModuleBundle({
    required this.engine,
    required this.analysisEngine,
    required this.guidanceEngine,
    required this.decisionEngine,
  });
}

/// الجسر المسؤول عن تجميع (wiring) كل محركات الذكاء الاصطناعي الصحي.
///
/// هذا الملف هو المكان الوحيد الذي يعرف كيف تتصل كل المحركات الفرعية
/// ببعضها؛ أي وحدة أخرى في التطبيق يجب أن تتعامل فقط مع [AiModuleBundle]
/// الناتج، وليس مع كل محرك فرعي بشكل منفصل.
class AiBridge {
  AiBridge._();

  /// بناء وتوصيل كل محركات الذكاء الاصطناعي بالبيانات القادمة من
  /// medical_knowledge.json و symptoms_database.json (تُمرَّر كخرائط
  /// جاهزة بعد تحميلها من طبقة تحميل البيانات، دون قراءة JSON هنا).
  static AiModuleBundle initialize({
    required Map<String, String> symptomKeywordMap,
    required Set<String> emergencySymptomIds,
    required Map<String, String> symptomBodySystemMap,
  }) {
    final engine = AiEngine.instance;

    final analysisEngine = HealthAnalysisEngine(
      symptomKeywordMap: symptomKeywordMap,
      emergencySymptomIds: emergencySymptomIds,
    );

    final guidanceEngine = DoctorGuidanceEngine(
      symptomBodySystemMap: symptomBodySystemMap,
    );

    final decisionEngine = HealthDecisionEngine(
      analysisEngine: analysisEngine,
      guidanceEngine: guidanceEngine,
    );

    // ترتيب التسجيل مهم: نسجّل محرك القرار (الأعلى مستوى) كمعالج رئيسي
    // لاستعلامات فحص الأعراض، لأنه يُنسّق بين التحليل والتوجيه معاً.
    decisionEngine.registerWithAiEngine(engine);
    guidanceEngine.registerWithAiEngine(engine, analysisEngine);

    return AiModuleBundle(
      engine: engine,
      analysisEngine: analysisEngine,
      guidanceEngine: guidanceEngine,
      decisionEngine: decisionEngine,
    );
  }
}
