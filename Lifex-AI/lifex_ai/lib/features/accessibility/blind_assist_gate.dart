/// تأكيد الدخول من شريط المكفوفين. كل قسم ينطق أولاً، واللمسة الثانية على نفس المكان تفتح.
library lifex_ai.features.accessibility.blind_assist_gate;

enum BlindAssistStep { ask, open, ignore }

enum BlindRailZone { assistant, front }

class BlindAssistGate {
  BlindRailZone? armedZone;

  static const assistantAskAr = 'لتشغيل المساعد البصري اضغط نفس المكان';

  static const frontAskAr = 'لتشغيل الكاميرا الامامية اضغط نفس المكان';

  static const openedAr = 'تم فتح كاميرا المساعد البصري';

  bool get armed => armedZone != null;

  BlindAssistStep press(BlindRailZone zone) {
    if (armedZone == zone) {
      armedZone = null;
      return BlindAssistStep.open;
    }
    armedZone = zone;
    return BlindAssistStep.ask;
  }

  BlindAssistStep hear(String? text) {
    if (armedZone == null) return BlindAssistStep.ignore;
    final trimmed = (text ?? '').trim();
    if (trimmed == 'نعم' || trimmed.startsWith('نعم ')) {
      armedZone = null;
      return BlindAssistStep.open;
    }
    return BlindAssistStep.ignore;
  }

  void reset() {
    armedZone = null;
  }
}
