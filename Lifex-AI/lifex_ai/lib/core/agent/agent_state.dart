/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_state.dart
/// المسار: lib/core/agent/agent_state.dart
/// الوصف: آلة الحالة الرسمية (State Machine) لأي مهمة وكيل. تُستخدم من
/// AgentOrchestrator كمصدر وحيد للحقيقة عن أين وصلت المهمة الحالية،
/// وتمنع تنفيذ إجراءات في حالة غير مسموح بها منطقياً (مثال: لا يجوز
/// تنفيذ Tool وأنت في حالة "completed").
/// =============================================================
library;

/// الحالات الأساسية لدورة حياة مهمة الوكيل الواحدة.
enum AgentTaskState {
  idle,
  understanding,
  planning,
  executing,
  observing,
  validating,
  completed,

  // حالات استثنائية
  retrying,
  waitingForUser,
  blocked,
  failed,
  cancelled,
}

/// يحدّد ما إذا كانت الحالة "نهائية" (لا يمكن للمهمة الانتقال منها إلى
/// حالة أخرى بعد الوصول إليها) — تُستخدم لمنع أي تنفيذ لاحق بالخطأ.
bool isTerminalAgentState(AgentTaskState state) {
  switch (state) {
    case AgentTaskState.completed:
    case AgentTaskState.failed:
    case AgentTaskState.cancelled:
      return true;
    default:
      return false;
  }
}

/// جدول الانتقالات المسموح بها صراحة. أي انتقال غير موجود هنا يُرفض
/// من AgentOrchestrator (fail-closed بدل fail-open) لمنع الوكيل من
/// "القفز" فوق خطوات السلامة (مثل تخطي validating مباشرة إلى completed).
const Map<AgentTaskState, Set<AgentTaskState>> kAllowedAgentTransitions = {
  AgentTaskState.idle: {
    AgentTaskState.understanding,
    AgentTaskState.cancelled,
  },
  AgentTaskState.understanding: {
    AgentTaskState.planning,
    AgentTaskState.blocked,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.planning: {
    AgentTaskState.executing,
    AgentTaskState.waitingForUser, // خطة تحتاج تأكيداً بشرياً قبل التنفيذ
    AgentTaskState.blocked,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.executing: {
    AgentTaskState.observing,
    AgentTaskState.waitingForUser, // إجراء عالي الخطورة يحتاج تأكيداً
    AgentTaskState.blocked,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.observing: {
    AgentTaskState.validating,
    AgentTaskState.retrying,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.validating: {
    AgentTaskState.executing, // خطوة تالية في الخطة
    AgentTaskState.completed,
    AgentTaskState.retrying,
    AgentTaskState.blocked,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.retrying: {
    AgentTaskState.executing,
    AgentTaskState.failed,
    AgentTaskState.cancelled,
  },
  AgentTaskState.waitingForUser: {
    AgentTaskState.planning,
    AgentTaskState.executing,
    AgentTaskState.cancelled,
    AgentTaskState.failed,
  },
  AgentTaskState.blocked: {
    AgentTaskState.cancelled,
    AgentTaskState.failed,
  },
  // الحالات النهائية: لا انتقالات مسموحة خارجها.
  AgentTaskState.completed: {},
  AgentTaskState.failed: {},
  AgentTaskState.cancelled: {},
};

/// يتحقق من صحة انتقال معيّن وفق الجدول أعلاه.
bool isValidAgentTransition(AgentTaskState from, AgentTaskState to) {
  return kAllowedAgentTransitions[from]?.contains(to) ?? false;
}
