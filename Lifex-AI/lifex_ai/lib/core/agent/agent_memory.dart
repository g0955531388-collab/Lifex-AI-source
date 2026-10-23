/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_memory.dart
/// المسار: lib/core/agent/agent_memory.dart
/// الوصف: واجهة موحّدة (Facade) تجمع الذاكرة قصيرة/طويلة الأمد والمحادثة
/// معاً، حتى لا يضطر AgentOrchestrator للتعامل مع 3 كائنات منفصلة.
/// نمط مطابق لـ AiModuleBundle/AiBridge الموجود في features/ai/.
/// =============================================================
library;

import 'memory/conversation_memory.dart';
import 'memory/long_term_memory.dart';
import 'memory/memory_store.dart';
import 'memory/short_term_memory.dart';

class AgentMemory {
  AgentMemory({
    AgentMemoryStore? store,
    LongTermMemoryPolicy longTermPolicy = LongTermMemoryPolicy.disabled,
    ConversationMemory? conversationMemory,
  })  : longTerm = LongTermMemory(
          store: store ?? InMemoryAgentMemoryStore(),
          policy: longTermPolicy,
        ),
        conversation = conversationMemory ?? ConversationMemory();

  final LongTermMemory longTerm;
  final ConversationMemory conversation;

  final Map<String, ShortTermMemory> _shortTermByTask = {};

  ShortTermMemory shortTermFor(String taskId) =>
      _shortTermByTask.putIfAbsent(taskId, () => ShortTermMemory(taskId));

  /// يُستدعى دائماً عند وصول مهمة لحالة نهائية — يمنع تراكم ذاكرة قصيرة
  /// الأمد لمهام منتهية (بند 33: إدارة الذاكرة بعناية على الهاتف).
  void releaseShortTermFor(String taskId) {
    _shortTermByTask[taskId]?.clear();
    _shortTermByTask.remove(taskId);
  }

  /// ملخص مختصر يُستخدم في AgentContext.memorySummary — وليس الذاكرة
  /// الكاملة (بند 11: Context Filtering).
  Map<String, dynamic> summaryFor(String profileId, String taskId) {
    final shortTerm = _shortTermByTask[taskId];
    return {
      'recentConversationTurns': conversation.recentTextsFor(profileId).length,
      'completedActionsInTask': shortTerm?.currentActions.length ?? 0,
    };
  }
}
