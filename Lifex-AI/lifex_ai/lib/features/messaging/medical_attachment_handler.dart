/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: medical_attachment_handler.dart
/// المسار: lib/features/messaging/medical_attachment_handler.dart
/// الوصف: إرفاق بيانات طبية (وصفة، نتيجة تحليل، صورة أشعة) داخل محادثة،
/// بربط آمن بمصدر البيانات الأصلي بدلاً من نسخها.
/// =============================================================
library;

enum MedicalAttachmentType { prescription, labResult, imagingRecord, generalDocument }

class MedicalAttachment {
  final String attachmentId;
  final MedicalAttachmentType type;

  /// مرجع لمصدر البيانات الأصلي (مثلاً requestId من lab_test_request_manager)
  /// بدلاً من تضمين البيانات الطبية الكاملة مباشرة داخل رسالة الدردشة.
  final String sourceReferenceId;
  final String conversationId;
  final DateTime attachedAt;

  MedicalAttachment({
    required this.attachmentId,
    required this.type,
    required this.sourceReferenceId,
    required this.conversationId,
    DateTime? attachedAt,
  }) : attachedAt = attachedAt ?? DateTime.now();
}

/// معالج المرفقات الطبية داخل الدردشة.
class MedicalAttachmentHandler {
  MedicalAttachmentHandler();

  final Map<String, List<MedicalAttachment>> _attachmentsByConversation = {};
  int _counter = 0;

  MedicalAttachment attachToConversation({
    required String conversationId,
    required MedicalAttachmentType type,
    required String sourceReferenceId,
  }) {
    _counter++;
    final attachment = MedicalAttachment(
      attachmentId: 'ATT-$_counter',
      type: type,
      sourceReferenceId: sourceReferenceId,
      conversationId: conversationId,
    );
    _attachmentsByConversation
        .putIfAbsent(conversationId, () => [])
        .add(attachment);
    return attachment;
  }

  List<MedicalAttachment> attachmentsFor(String conversationId) =>
      List.unmodifiable(_attachmentsByConversation[conversationId] ?? const []);
}
