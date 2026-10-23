/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_result.dart
/// المسار: lib/core/agent/agent_result.dart
/// الوصف: النتيجة النهائية لمهمة وكيل كاملة — ما يُعرض فعلياً للمستخدم
/// في نهاية التنفيذ (بند 38). تحمل دائماً مستوى ثقة وتنويهاً واضحاً،
/// ولا يمكن بناؤها بحالة "مكتملة" دون هذين الحقلين.
/// =============================================================
library;

import 'agent_action.dart';
import 'agent_confidence.dart';
import 'agent_state.dart';

class AgentResult {
  const AgentResult({
    required this.taskId,
    required this.finalState,
    required this.summaryAr,
    required this.confidence,
    required this.disclaimerAr,
    this.completedActions = const [],
    this.reportData,
    this.errorMessageAr,
  });

  final String taskId;
  final AgentTaskState finalState;

  /// الملخص النهائي المعروض للمستخدم — نص واضح، وليس تفكيراً داخلياً.
  final String summaryAr;

  final AgentConfidence confidence;

  /// تنويه إلزامي — يُطبَّق دائماً نفس منطق AiResponse.disclaimer
  /// الموجود في ai_engine.dart، حتى تبقى رسالة السلامة موحدة عبر كل
  /// نقاط التطبيق (Chat Mode وAgent Mode معاً).
  final String disclaimerAr;

  final List<AgentAction> completedActions;

  /// بيانات تقرير منظّم (إن وُجد) — يُستخدم من ReportAgent لتمرير محتوى
  /// منظم (وليس نصاً حراً فقط) يمكن للواجهة عرضه كبطاقات/أقسام.
  final Map<String, dynamic>? reportData;

  final String? errorMessageAr;

  bool get isSuccessful => finalState == AgentTaskState.completed;

  factory AgentResult.failed({
    required String taskId,
    required String reasonAr,
    List<AgentAction> completedActions = const [],
  }) {
    return AgentResult(
      taskId: taskId,
      finalState: AgentTaskState.failed,
      summaryAr: 'تعذّر إكمال المهمة.',
      confidence: AgentConfidence.unknown,
      disclaimerAr: kAgentDefaultDisclaimerAr,
      completedActions: completedActions,
      errorMessageAr: reasonAr,
    );
  }

  factory AgentResult.cancelled({
    required String taskId,
    List<AgentAction> completedActions = const [],
  }) {
    return AgentResult(
      taskId: taskId,
      finalState: AgentTaskState.cancelled,
      summaryAr: 'تم إلغاء المهمة بناءً على طلب المستخدم.',
      confidence: AgentConfidence.unknown,
      disclaimerAr: kAgentDefaultDisclaimerAr,
      completedActions: completedActions,
    );
  }
}

/// نفس نص التنويه الافتراضي المستخدم في AiResponse (ai_engine.dart)،
/// معاد تعريفه هنا لتجنّب اعتماد دائري بين core/ وfeatures/ (اتجاه
/// الاعتماديات في هذا المشروع: features/ تعتمد على core/، وليس العكس).
/// أي استدعاء فعلي من الواجهة يجب أن يفضّل نص AiResponse.disclaimer
/// الأصلي عند توفره في نفس السياق.
const String kAgentDefaultDisclaimerAr =
    'هذه النتيجة تحليل مساعد من الذكاء الاصطناعي وليست تشخيصاً طبياً '
    'نهائياً. يُرجى دائماً استشارة طبيب مختص، وفي حال وجود أعراض خطيرة '
    'اتصل بالإسعاف فوراً.';
