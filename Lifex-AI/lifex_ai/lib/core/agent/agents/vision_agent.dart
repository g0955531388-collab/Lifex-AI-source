/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: vision_agent.dart
/// المسار: lib/core/agent/agents/vision_agent.dart
/// الوصف: الوكيل البصري (بند 14). مسؤوليته تفسير مخرجات ImageAnalysisTool/
/// OcrTool/DocumentReaderTool وتحديد أي وكيل يجب أن يستلم النتيجة بعده
/// (طبي عادة). لا يحتوي منطق رؤية حاسوبية بذاته — ذلك يبقى في
/// SmartVisionEngine الموجود فعلاً.
/// =============================================================
library;

import '../agent_confidence.dart';
import 'specialized_agent.dart';

class VisionAgentInterpretation {
  const VisionAgentInterpretation({
    required this.shouldForwardToMedicalAgent,
    required this.extractedTextForNextStep,
    required this.confidence,
  });

  /// هل يستدعي محتوى الصورة تحليلاً طبياً إضافياً، أم أنه معلومة عامة
  /// (مثل صورة جدول مواعيد وليست تقريراً طبياً)؟
  final bool shouldForwardToMedicalAgent;

  final String extractedTextForNextStep;
  final AgentConfidence confidence;
}

class VisionAgent implements SpecializedAgent {
  const VisionAgent();

  @override
  String get agentName => 'VisionAgent';

  @override
  String get responsibilityAr =>
      'تفسير نتائج تحليل الصور/OCR وتمريرها للوكيل المناسب.';

  /// يفسّر مخرجات image_analysis / document_ocr / raw_ocr_text القادمة
  /// من AgentObservation.data (بعد أن نفّذتها الأداة فعلياً).
  VisionAgentInterpretation interpret(Map<String, dynamic> toolResultData) {
    final dataType = toolResultData['dataType'] as String?;
    final confidenceStr = toolResultData['confidence'] as String?;
    final confidence = _parseConfidence(confidenceStr);

    final text = (toolResultData['extractedText'] as String?) ??
        (toolResultData['summaryAr'] as String?) ??
        '';

    // أنواع المستندات/الصور التي تستحق تحليلاً طبياً إضافياً — أي شيء
    // له نص مستخرج غير فارغ يُعتبر مرشحاً افتراضياً، بحذر (fail-safe:
    // من الأفضل تمرير معلومة غير ضرورية للتحليل الطبي من إسقاط معلومة
    // طبية فعلية بالخطأ).
    final shouldForward = dataType != null && text.trim().isNotEmpty;

    return VisionAgentInterpretation(
      shouldForwardToMedicalAgent: shouldForward,
      extractedTextForNextStep: text,
      confidence: confidence,
    );
  }

  AgentConfidence _parseConfidence(String? value) {
    switch (value) {
      case 'high':
        return AgentConfidence.high;
      case 'medium':
        return AgentConfidence.medium;
      case 'low':
        return AgentConfidence.low;
      default:
        return AgentConfidence.unknown;
    }
  }
}
