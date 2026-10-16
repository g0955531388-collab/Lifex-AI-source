/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: speech_to_text_processor.dart
/// المسار: lib/features/voice/speech_to_text_processor.dart
/// الوصف: معالج تحويل الصوت إلى نص. هذا الملف يوفر البنية والعقد
/// (Interface) الذي سيُنفَّذ لاحقاً عبر مكتبة تعرّف صوتي حقيقية
/// (مثل speech_to_text على Flutter)، دون ربط هذا الملف بمكتبة محددة الآن.
/// =============================================================
library;

import '../../core/app_config.dart';
import 'assistant_permission_desk.dart';
import 'voice_engine.dart';
import 'voice_locale_policy.dart';

/// حالة نتيجة التعرّف الصوتي.
enum SpeechRecognitionStatus {
  success,
  noSpeechDetected,
  permissionDenied,
  error
}

class SpeechRecognitionResult {
  final SpeechRecognitionStatus status;
  final String? recognizedText;
  final double? confidence;
  final String? messageAr;

  const SpeechRecognitionResult({
    required this.status,
    this.recognizedText,
    this.confidence,
    this.messageAr,
  });
}

/// عقد أي مزوّد تعرّف صوتي فعلي (Speech-to-Text provider). يُنفَّذ هذا
/// العقد لاحقاً بواسطة حزمة خارجية معينة، بينما بقية النظام يتعامل مع
/// هذا العقد المجرّد فقط.
abstract class SpeechToTextProvider {
  Future<bool> requestMicrophonePermission();
  Future<SpeechRecognitionResult> listenOnce({String localeCode = 'ar'});
  Future<void> stop();
}

/// معالج تحويل الصوت إلى نص — يربط بين VoiceEngine المركزي وأي مزوّد
/// تعرّف صوتي فعلي عبر SpeechToTextProvider.
class SpeechToTextProcessor {
  SpeechToTextProcessor({required this.provider});

  final SpeechToTextProvider provider;

  /// تسجيل هذا المعالج كمنفّذ فعلي داخل VoiceEngine المركزي. يُستدعى
  /// مرة واحدة عند تهيئة التطبيق.
  void registerWithVoiceEngine(VoiceEngine engine) {
    engine.bindListeningImplementation(_listenAndConvert);
    engine.bindStopListeningImplementation(provider.stop);
  }

  Future<VoiceOperationResult> _listenAndConvert() async {
    final hasPermission = await provider.requestMicrophonePermission();
    if (!hasPermission) {
      return VoiceOperationResult.failure(
        AssistantPermissionDesk.lastExplanationAr ??
            'لم يتم منح إذن الميكروفون. لا يمكن استخدام الأوامر الصوتية بدونه.',
      );
    }

    final appLanguage =
        AppConfig.instance.defaultLanguage == AppLanguage.english ? 'en' : 'ar';
    final locale =
        const VoiceLocalePolicy().listenCode(appLanguage: appLanguage);
    VoiceEngine.instance.activeLocaleId = locale;
    final result = await provider.listenOnce(localeCode: locale);

    switch (result.status) {
      case SpeechRecognitionStatus.success:
        return VoiceOperationResult.success(textResult: result.recognizedText);
      case SpeechRecognitionStatus.noSpeechDetected:
        return VoiceOperationResult.failure(
          result.messageAr ??
              'لم يصلني نص هذه المرة. يمكنك المحاولة مجدداً أو الكتابة.',
        );
      case SpeechRecognitionStatus.permissionDenied:
        return const VoiceOperationResult.failure(
          'إذن الميكروفون مرفوض. يمكنك تفعيله من إعدادات الجهاز.',
        );
      case SpeechRecognitionStatus.error:
        return VoiceOperationResult.failure(
          result.messageAr ??
              'خدمة التعرف على الكلام غير متاحة الآن. يمكنك الكتابة أو المحاولة لاحقاً.',
        );
    }
  }
}
