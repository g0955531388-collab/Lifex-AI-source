/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: short_term_memory.dart
/// المسار: lib/core/agent/memory/short_term_memory.dart
/// الوصف: ذاكرة خاصة بمهمة واحدة فقط (بند 10). تُمسح تلقائياً عند
/// انتهاء المهمة (نجاحاً أو فشلاً) — لا تُخزَّن بشكل دائم أبداً.
/// =============================================================
library;

import '../agent_action.dart';
import '../agent_observation.dart';

class ShortTermMemory {
  ShortTermMemory(this.taskId);

  final String taskId;

  String? currentPlanSummary;
  final List<AgentAction> currentActions = [];
  final List<AgentObservation> observations = [];

  /// سياق مؤقت حر الشكل — قيم وسيطة بين خطوات نفس المهمة (مثال: نص
  /// مستخرج من OCR في خطوة 1، يُستخدم في خطوة 3).
  final Map<String, dynamic> temporaryContext = {};

  void recordAction(AgentAction action) => currentActions.add(action);

  void recordObservation(AgentObservation observation) =>
      observations.add(observation);

  void setTemp(String key, dynamic value) => temporaryContext[key] = value;

  T? getTemp<T>(String key) => temporaryContext[key] as T?;

  /// يُستدعى دائماً عند وصول المهمة لحالة نهائية (completed/failed/
  /// cancelled) — يمنع تسرّب بيانات مهمة إلى مهمة تالية لنفس الجلسة.
  void clear() {
    currentPlanSummary = null;
    currentActions.clear();
    observations.clear();
    temporaryContext.clear();
  }
}
