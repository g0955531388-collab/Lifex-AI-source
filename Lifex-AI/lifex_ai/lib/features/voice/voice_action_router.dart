/// =============================================================
/// Lifex-AI — توجيه نية الصوت إلى شاشة حقيقية.
/// فتح المساعد البصري لا يشترط ملفاً صحياً.
/// =============================================================
library lifex_ai.features.voice.voice_action_router;

import 'command_parser.dart';

enum AssistantDestination {
  liveSight,
  liveSightText,
  stillCamera,
  repeatSight,
  pauseSight,
  resumeSight,
  stopSpeech,
  raiseVolume,
  none,
}

class AssistantRoute {
  const AssistantRoute({
    required this.destination,
    required this.needsHealthProfile,
    required this.spokenAr,
  });

  final AssistantDestination destination;
  final bool needsHealthProfile;
  final String spokenAr;
}

class VoiceActionRouter {
  const VoiceActionRouter();

  AssistantRoute route(VoiceCommandIntent intent) {
    switch (intent) {
      case VoiceCommandIntent.openLiveSight:
        return const AssistantRoute(
          destination: AssistantDestination.liveSight,
          needsHealthProfile: false,
          spokenAr:
              'سأفتح البث الحي لأصف الإطار التالي. إذا لم يظهر تصنيف واضح سأقول ذلك ولن أخترع مشهداً.',
        );
      case VoiceCommandIntent.readVisibleText:
        return const AssistantRoute(
          destination: AssistantDestination.liveSightText,
          needsHealthProfile: false,
          spokenAr: 'سأفتح المساعد البصري لقراءة النص الظاهر. لن أخترع نصاً.',
        );
      case VoiceCommandIntent.openCamera:
        return const AssistantRoute(
          destination: AssistantDestination.stillCamera,
          needsHealthProfile: false,
          spokenAr: 'سأفتح أرشيف اللقطة الواحدة بعد موافقتك.',
        );
      case VoiceCommandIntent.repeatScene:
        return const AssistantRoute(
          destination: AssistantDestination.repeatSight,
          needsHealthProfile: false,
          spokenAr: 'أعيد الوصف الأخير.',
        );
      case VoiceCommandIntent.pauseScene:
        return const AssistantRoute(
          destination: AssistantDestination.pauseSight,
          needsHealthProfile: false,
          spokenAr: 'أوقفت الوصف. العدسة تبقى حتى تغلق الصفحة.',
        );
      case VoiceCommandIntent.resumeScene:
        return const AssistantRoute(
          destination: AssistantDestination.resumeSight,
          needsHealthProfile: false,
          spokenAr: 'استأنفت الوصف.',
        );
      case VoiceCommandIntent.stopReading:
        return const AssistantRoute(
          destination: AssistantDestination.stopSpeech,
          needsHealthProfile: false,
          spokenAr: 'أوقفت القراءة.',
        );
      case VoiceCommandIntent.raiseVolume:
        return const AssistantRoute(
          destination: AssistantDestination.raiseVolume,
          needsHealthProfile: false,
          spokenAr: 'رفعت مستوى الصوت.',
        );
      default:
        return const AssistantRoute(
          destination: AssistantDestination.none,
          needsHealthProfile: false,
          spokenAr: '',
        );
    }
  }
}
