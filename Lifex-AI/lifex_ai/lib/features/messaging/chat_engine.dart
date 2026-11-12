/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: chat_engine.dart
/// المسار: lib/features/messaging/chat_engine.dart
/// الوصف: المحرك المركزي للدردشة — إرسال واستقبال الرسائل، بمعزل عن
/// منطق الصلاحيات (messaging_permissions_manager.dart) ونوع المحادثة
/// (conversation_type_router.dart).
/// =============================================================
library;

enum MessageContentType { text, medicalAttachment, systemNotice }

class ChatMessage {
  final String messageId;
  final String conversationId;
  final String senderLifexId;
  final MessageContentType contentType;
  final String content;
  final DateTime sentAt;
  bool delivered;
  bool read;

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderLifexId,
    required this.contentType,
    required this.content,
    DateTime? sentAt,
    this.delivered = false,
    this.read = false,
  }) : sentAt = sentAt ?? DateTime.now();
}

/// المحرك المركزي للدردشة.
class ChatEngine {
  ChatEngine();

  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  int _counter = 0;

  ChatMessage sendMessage({
    required String conversationId,
    required String senderLifexId,
    required String content,
    MessageContentType contentType = MessageContentType.text,
  }) {
    _counter++;
    final message = ChatMessage(
      messageId: 'MSG-$_counter',
      conversationId: conversationId,
      senderLifexId: senderLifexId,
      contentType: contentType,
      content: content,
    );
    _messagesByConversation.putIfAbsent(conversationId, () => []).add(message);
    return message;
  }

  void markDelivered(String messageId) {
    for (final messages in _messagesByConversation.values) {
      for (final message in messages) {
        if (message.messageId == messageId) {
          message.delivered = true;
          return;
        }
      }
    }
  }

  void markRead(String conversationId, String readerLifexId) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) return;
    for (final message in messages) {
      if (message.senderLifexId != readerLifexId) {
        message.read = true;
      }
    }
  }

  List<ChatMessage> messagesFor(String conversationId) =>
      List.unmodifiable(_messagesByConversation[conversationId] ?? const []);
}
