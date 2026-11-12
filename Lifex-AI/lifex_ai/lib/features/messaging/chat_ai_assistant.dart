/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: chat_ai_assistant.dart
/// المسار: lib/features/messaging/chat_ai_assistant.dart
/// الوصف: مساعد ذكي اختياري داخل الدردشة — ترجمة، تلخيص، شرح تقارير
/// طبية بلغة مبسّطة. يُستدعى فقط بطلب صريح من المستخدم داخل المحادثة،
/// ولا يقرأ أو يحلّل الرسائل تلقائياً دون طلب.
/// =============================================================
library;

enum ChatAiActionType { translate, summarize, explainMedicalReport }

class ChatAiAssistantResponse {
  final String resultText;
  final String disclaimer;

  const ChatAiAssistantResponse({
    required this.resultText,
    this.disclaimer =
        'هذا شرح آلي مبسّط بمساعدة الذكاء الاصطناعي وقد يحتوي أخطاء. '
        'للحصول على تفسير دقيق لأي تقرير طبي، راجع طبيبك المختص.',
  });
}

/// عقد أي مزوّد معالجة لغوية فعلي (سيُربط لاحقاً بـ ai_engine.dart
/// المركزي أو خدمة لغوية متخصصة).
abstract class ChatAiProcessor {
  Future<String> translate(String text, String targetLanguageCode);
  Future<String> summarize(String text);
  Future<String> explainInSimpleTerms(String medicalText);
}

/// المساعد الذكي داخل الدردشة.
class ChatAiAssistant {
  ChatAiAssistant({required this.processor});

  final ChatAiProcessor processor;

  Future<ChatAiAssistantResponse> performAction({
    required ChatAiActionType action,
    required String inputText,
    String? targetLanguageCode,
  }) async {
    switch (action) {
      case ChatAiActionType.translate:
        final result = await processor.translate(
          inputText,
          targetLanguageCode ?? 'ar',
        );
        return ChatAiAssistantResponse(resultText: result);

      case ChatAiActionType.summarize:
        final result = await processor.summarize(inputText);
        return ChatAiAssistantResponse(resultText: result);

      case ChatAiActionType.explainMedicalReport:
        final result = await processor.explainInSimpleTerms(inputText);
        return ChatAiAssistantResponse(resultText: result);
    }
  }
}
