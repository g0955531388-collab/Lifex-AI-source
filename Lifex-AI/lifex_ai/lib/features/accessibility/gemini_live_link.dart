/// قرار اتصال جيميني الحي: يُفتح مع الإنترنت، ويُغلق عند غيابه.
library lifex_ai.features.accessibility.gemini_live_link;

enum GeminiLiveLinkStep { stayClosed, close, open, keep }

class GeminiLiveLinkOrder {
  const GeminiLiveLinkOrder(this.step, {this.announce = false});

  final GeminiLiveLinkStep step;

  /// نطق مرة واحدة: إغلاق بلا شبكة، أو إعادة الفتح عند رجوعها.
  final bool announce;
}

/// إيقاف مؤقت من SPOT. لا يفتح جلسة ولا يرسل إطارات.
class GeminiBlindLink {
  static var held = false;

  static Future<void> hold() async {
    held = true;
  }

  static void release() {
    held = false;
  }
}

/// بلا موافقة لا تُرسل الإطارات. بلا إنترنت تُغلق الجلسة الجاهزة.
GeminiLiveLinkOrder geminiLiveLinkOrder({
  required bool consent,
  required bool online,
  required bool sessionReady,
  required bool announcedOffline,
}) {
  if (!consent) {
    return const GeminiLiveLinkOrder(GeminiLiveLinkStep.stayClosed);
  }
  if (!online) {
    if (sessionReady) {
      return const GeminiLiveLinkOrder(
        GeminiLiveLinkStep.close,
        announce: true,
      );
    }
    return GeminiLiveLinkOrder(
      GeminiLiveLinkStep.stayClosed,
      announce: !announcedOffline,
    );
  }
  if (!sessionReady) {
    return GeminiLiveLinkOrder(
      GeminiLiveLinkStep.open,
      announce: announcedOffline,
    );
  }
  return const GeminiLiveLinkOrder(GeminiLiveLinkStep.keep);
}
