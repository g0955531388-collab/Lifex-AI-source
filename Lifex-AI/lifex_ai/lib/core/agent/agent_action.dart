/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_action.dart
/// المسار: lib/core/agent/agent_action.dart
/// الوصف: تمثيل موحّد لأي إجراء ينوي الوكيل تنفيذه (بند 6). كل خطوة في
/// الخطة تتحول في النهاية إلى AgentAction واحد أو أكثر يُمرَّر إلى
/// AgentExecutor ثم AgentToolRegistry.
/// =============================================================
library;

enum AgentActionStatus {
  pending,
  running,
  succeeded,
  failed,
  skipped,
  awaitingConfirmation,
  cancelled,
}

class AgentAction {
  AgentAction({
    required this.actionId,
    required this.toolName,
    required this.arguments,
    required this.reason,
    this.status = AgentActionStatus.pending,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String actionId;
  final String toolName;
  final Map<String, dynamic> arguments;

  /// شرح مختصر لماذا اختار الوكيل هذا الإجراء تحديداً — يُعرض في
  /// Audit Log وفي واجهة "الأدوات التي استخدمها الوكيل" (بند 22).
  final String reason;

  final DateTime timestamp;
  AgentActionStatus status;

  AgentAction copyWith({AgentActionStatus? status}) {
    return AgentAction(
      actionId: actionId,
      toolName: toolName,
      arguments: arguments,
      reason: reason,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }

  /// ملخص آمن للتسجيل — لا يُدرج القيم الخام الكاملة إن كانت كبيرة أو
  /// حساسة (بند 19: لا تُسجَّل بيانات حساسة في السجلات). يُستخدم من
  /// AgentLogger فقط، وليس كمصدر بيانات فعلي للتنفيذ.
  Map<String, dynamic> toAuditSummary() => {
        'actionId': actionId,
        'toolName': toolName,
        'reason': reason,
        'argumentKeys': arguments.keys.toList(),
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
      };
}
