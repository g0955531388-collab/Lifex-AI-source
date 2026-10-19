/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: conversation_type_router.dart
/// المسار: lib/features/messaging/conversation_type_router.dart
/// الوصف: تصنيف كل محادثة حسب نوعها (فردية/عائلية/طبية/طوارئ)، لتطبيق
/// سياسات مختلفة على كل نوع (مثلاً: محادثات الطوارئ لا تُحذف تلقائياً).
/// =============================================================
library;

enum ConversationType { direct, family, medical, emergency, meeting }

class ConversationMetadata {
  final String conversationId;
  final ConversationType type;
  final List<String> participantLifexIds;
  final DateTime createdAt;

  ConversationMetadata({
    required this.conversationId,
    required this.type,
    required this.participantLifexIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// موجّه أنواع المحادثات.
class ConversationTypeRouter {
  ConversationTypeRouter();

  final Map<String, ConversationMetadata> _conversations = {};
  int _counter = 0;

  ConversationMetadata createConversation({
    required ConversationType type,
    required List<String> participantLifexIds,
  }) {
    _counter++;
    final metadata = ConversationMetadata(
      conversationId: 'CONV-$_counter',
      type: type,
      participantLifexIds: participantLifexIds,
    );
    _conversations[metadata.conversationId] = metadata;
    return metadata;
  }

  /// غرفة اجتماع محلية. ليست مكالمة فيديو. الاسم المستعار يبقى في هوية العرض.
  ConversationMetadata? openMeetingRoom({
    required List<String> participantLifexIds,
  }) {
    final ids = participantLifexIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.length < 2) return null;
    final metadata = ConversationMetadata(
      conversationId: 'MEET-${DateTime.now().microsecondsSinceEpoch}',
      type: ConversationType.meeting,
      participantLifexIds: ids,
    );
    _conversations[metadata.conversationId] = metadata;
    return metadata;
  }

  ConversationMetadata? getById(String conversationId) =>
      _conversations[conversationId];

  /// محادثات الطوارئ يجب أن تبقى محفوظة دائماً ولا تُحذف تلقائياً بأي
  /// سياسة تنظيف بيانات مستقبلية.
  bool isProtectedFromAutoCleanup(String conversationId) {
    final conversation = _conversations[conversationId];
    return conversation?.type == ConversationType.emergency;
  }

  List<ConversationMetadata> conversationsForUser(String lifexId) {
    return _conversations.values
        .where((c) => c.participantLifexIds.contains(lifexId))
        .toList();
  }
}
