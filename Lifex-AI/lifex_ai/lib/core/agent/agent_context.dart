/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_context.dart
/// المسار: lib/core/agent/agent_context.dart
/// الوصف: السياق الموحّد لمهمة وكيل واحدة (بند 11). يحمل كل ما يحتاجه
/// التخطيط والتنفيذ، لكنه لا يُرسل كاملاً للنموذج في كل مرة — بل يوفّر
/// forModelRequest() الذي يبني نسخة مفلترة ومختصرة فقط (Context
/// Filtering) قبل أي استدعاء فعلي لمزوّد الذكاء الاصطناعي.
/// =============================================================
library;

import 'agent_permissions.dart';

class AgentContext {
  AgentContext({
    required this.taskId,
    required this.profileId,
    required this.userRequest,
    required this.permissions,
    this.conversationContext = const [],
    this.taskContext = const {},
    this.availableToolNames = const [],
    this.memorySummary = const {},
    this.knowledgeContext = const {},
    this.isCancelled = false,
  });

  final String taskId;
  final String profileId;
  final String userRequest;

  final AgentGrantedPermissions permissions;

  /// آخر N رسائل من المحادثة (نصوص فقط) — وليس السجل الكامل، لتقليل
  /// حجم الـ Context المُرسَل (بند 33).
  final List<String> conversationContext;

  final Map<String, dynamic> taskContext;
  final List<String> availableToolNames;

  /// ملخص من الذاكرة (وليس محتوى الذاكرة الكامل) — يُبنى من
  /// AgentMemory.summaryFor() قبل بناء السياق.
  final Map<String, dynamic> memorySummary;

  /// نتائج مسترجعة من قاعدة المعرفة ذات صلة فقط بالطلب الحالي (وليس
  /// قاعدة المعرفة كاملة) — تُبنى من KnowledgeRetriever.
  final Map<String, dynamic> knowledgeContext;

  bool isCancelled;

  /// Cancel token بسيط — AgentExecutor يفحص هذا قبل كل خطوة تنفيذ
  /// (بند 20)، وليس فقط في البداية.
  void cancel() => isCancelled = true;

  AgentContext copyWith({
    Map<String, dynamic>? taskContext,
    Map<String, dynamic>? memorySummary,
    Map<String, dynamic>? knowledgeContext,
    AgentGrantedPermissions? permissions,
  }) {
    return AgentContext(
      taskId: taskId,
      profileId: profileId,
      userRequest: userRequest,
      permissions: permissions ?? this.permissions,
      conversationContext: conversationContext,
      taskContext: taskContext ?? this.taskContext,
      availableToolNames: availableToolNames,
      memorySummary: memorySummary ?? this.memorySummary,
      knowledgeContext: knowledgeContext ?? this.knowledgeContext,
      isCancelled: isCancelled,
    );
  }

  /// بناء نسخة مختصرة ومفلترة مخصّصة فعلياً لإرسالها لمزوّد الذكاء
  /// الاصطناعي عبر AgentModelClient. هذا يمنع تسريب بيانات لا صلة لها
  /// بالطلب الحالي (وبالتالي يقلل التكلفة ويحسّن الخصوصية أيضاً).
  Map<String, dynamic> forModelRequest({int maxConversationTurns = 6}) {
    final trimmedConversation = conversationContext.length > maxConversationTurns
        ? conversationContext.sublist(
            conversationContext.length - maxConversationTurns)
        : conversationContext;

    return {
      'userRequest': userRequest,
      'recentConversation': trimmedConversation,
      'availableTools': availableToolNames,
      // فقط مفاتيح المعرفة ذات الصلة، لا الكائن الكامل.
      'knowledgeContextSummary': knowledgeContext.keys.toList(),
      'relevantKnowledge': knowledgeContext,
    };
  }
}
