/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_logger.dart
/// المسار: lib/core/agent/agent_logger.dart
/// الوصف: سجل تدقيق (Audit Log) لكل عمليات الوكيل (بند 19). يسجّل
/// ملخصات فقط (لا وسائط خام، لا مفاتيح API، لا نصوص كاملة قد تحمل
/// بيانات حساسة) — بنفس روح ErrorHandler الموجود في core/error_handler.dart
/// لكن مخصص لدورة حياة الوكيل تحديداً.
/// =============================================================
library;

import 'agent_action.dart';
import 'agent_confidence.dart';
import 'agent_observation.dart';

class AgentAuditEntry {
  AgentAuditEntry({
    required this.sessionId,
    required this.taskId,
    required this.agentName,
    required this.eventType,
    this.action,
    this.observation,
    this.statusNote,
    this.errorCode,
    this.confidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String sessionId;
  final String taskId;
  final String agentName;

  /// نوع الحدث كنص صريح (مثال: 'action_dispatched', 'observation',
  /// 'state_transition', 'blocked', 'completed') — وليس enum مغلق، حتى
  /// يسهل توسيعه من وكلاء مستقبليين دون تعديل هذا الملف.
  final String eventType;

  final AgentAction? action;
  final AgentObservation? observation;
  final String? statusNote;
  final String? errorCode;
  final AgentConfidence? confidence;
  final DateTime timestamp;

  /// تمثيل JSON آمن للتخزين/العرض. لا يحتوي أبداً على:
  /// - قيم الوسائط الخام الكاملة (فقط argumentKeys)
  /// - أي نص قد يحمل مفتاح API أو بيانات اعتماد
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
        'taskId': taskId,
        'agent': agentName,
        'eventType': eventType,
        if (action != null) 'action': action!.toAuditSummary(),
        if (observation != null) 'observation': observation!.toAuditSummary(),
        if (statusNote != null) 'statusNote': statusNote,
        if (errorCode != null) 'error': errorCode,
        if (confidence != null) 'confidence': confidence!.name,
      };
}

/// توقيع دالة الاستماع لأحداث تدقيق الوكيل — يسمح لواجهة "الأدوات
/// المستخدمة" (بند 22) بالتحديث الحي دون الحاجة لاستعلام السجل يدوياً.
typedef AgentAuditListener = void Function(AgentAuditEntry entry);

class AgentLogger {
  AgentLogger._internal();
  static final AgentLogger instance = AgentLogger._internal();

  final List<AgentAuditEntry> _entries = [];
  final List<AgentAuditListener> _listeners = [];

  List<AgentAuditEntry> get entries => List.unmodifiable(_entries);

  void addListener(AgentAuditListener listener) => _listeners.add(listener);
  void removeListener(AgentAuditListener listener) =>
      _listeners.remove(listener);

  void log(AgentAuditEntry entry) {
    _entries.add(entry);
    for (final listener in List<AgentAuditListener>.from(_listeners)) {
      listener(entry);
    }
  }

  /// كل إدخالات مهمة واحدة، بترتيب حدوثها — يُستخدم لبناء واجهة تتبع
  /// "الأدوات التي استخدمها الوكيل" بعد انتهاء المهمة.
  List<AgentAuditEntry> entriesForTask(String taskId) =>
      _entries.where((e) => e.taskId == taskId).toList(growable: false);

  void clear() => _entries.clear();
}
