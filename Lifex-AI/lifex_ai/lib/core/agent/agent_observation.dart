/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_observation.dart
/// المسار: lib/core/agent/agent_observation.dart
/// الوصف: نتيجة تنفيذ إجراء واحد (Observation) قبل أن تمر على
/// AgentValidator. هذا الكائن هو ما "يراه" الوكيل بعد استدعاء أداة،
/// ويُستخدم لتقرير الخطوة التالية (متابعة/إعادة محاولة/توقف).
/// =============================================================
library;

import 'agent_confidence.dart';
import 'agent_error.dart';

class AgentObservation {
  const AgentObservation({
    required this.actionId,
    required this.success,
    this.data,
    this.error,
    this.confidence = AgentConfidence.unknown,
    this.notesAr,
  });

  final String actionId;
  final bool success;

  /// البيانات الناتجة عن التنفيذ (شكلها يعتمد على الأداة نفسها).
  final Map<String, dynamic>? data;

  final AgentError? error;
  final AgentConfidence confidence;

  /// ملاحظة عربية مختصرة قابلة للعرض مباشرة في واجهة "حالة التنفيذ"
  /// (بند 21) دون تسريب أي تفكير داخلي (Chain-of-Thought) للنموذج.
  final String? notesAr;

  factory AgentObservation.failure({
    required String actionId,
    required AgentError error,
    String? notesAr,
  }) {
    return AgentObservation(
      actionId: actionId,
      success: false,
      error: error,
      confidence: AgentConfidence.unknown,
      notesAr: notesAr,
    );
  }

  factory AgentObservation.success({
    required String actionId,
    required Map<String, dynamic> data,
    AgentConfidence confidence = AgentConfidence.medium,
    String? notesAr,
  }) {
    return AgentObservation(
      actionId: actionId,
      success: true,
      data: data,
      confidence: confidence,
      notesAr: notesAr,
    );
  }

  Map<String, dynamic> toAuditSummary() => {
        'actionId': actionId,
        'success': success,
        'confidence': confidence.name,
        'error': error?.code,
        'resultDataKeys': data?.keys.toList(),
      };
}
