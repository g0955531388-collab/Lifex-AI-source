/// جمل SPOT حسب لغة الجهاز. التصنيف الإنجليزي يبقى اسم المصنّف.
/// العربية والإنجليزية والفرنسية لها جمل جاهزة. أي لغة أخرى تُقال بالإنجليزية.
library lifex_ai.features.spot.spot_speech;

import 'package:flutter/widgets.dart';

import '../accessibility/blind_camera_speech.dart';
import '../voice/voice_locale_policy.dart';

class SpotSpeech {
  const SpotSpeech._();

  static String languageOf(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    if (code.startsWith('ar')) return 'ar';
    if (code.startsWith('fr')) return 'fr';
    if (code.startsWith('en')) return 'en';
    return 'en';
  }

  static String deviceLanguage() =>
      languageOf(const VoiceLocalePolicy().deviceLocale());

  static bool askedFor(String? heard) {
    final text = (heard ?? '').trim().toLowerCase();
    if (text.isEmpty) return false;
    if (text == 'spot' || text.startsWith('spot ')) return true;
    return text.contains('سبوت');
  }

  static String armAsk(String languageCode) {
    switch (languageOf(Locale(languageCode))) {
      case 'ar':
        return 'لتشغيل SPOT اضغط نفس المكان';
      case 'fr':
        return 'Pour ouvrir SPOT, appuyez au même endroit';
      default:
        return 'To start SPOT, press the same place';
    }
  }

  static String intro(String languageCode) {
    switch (languageOf(Locale(languageCode))) {
      case 'ar':
        return 'SPOT. النظام البصري على هذا الجهاز. أسمي ما يظهر في التصنيف. هذا ليس تشخيصاً ولا أقول إن الطريق آمن أو مفتوح. فتح المساعد البصري يغلق SPOT.';
      case 'fr':
        return 'SPOT. Assistant visuel de cet appareil. Je nomme ce que le classificateur montre. Ce n’est pas un diagnostic, et je ne dis pas que le passage est sûr ou ouvert. Ouvrir l’autre assistant ferme SPOT.';
      default:
        return 'SPOT. The visual assistant on this device. I name what the labeler shows. This is not a diagnosis, and I do not say the way is safe or open. Opening the other assistant closes SPOT.';
    }
  }

  static String alreadyOpen(String languageCode) {
    switch (languageOf(Locale(languageCode))) {
      case 'ar':
        return 'SPOT يعمل الآن.';
      case 'fr':
        return 'SPOT est déjà ouvert.';
      default:
        return 'SPOT is already open.';
    }
  }

  static String lensFacing(bool rear, String languageCode) {
    switch (languageOf(Locale(languageCode))) {
      case 'ar':
        return rear ? 'العدسة الخلفية.' : 'العدسة الأمامية.';
      case 'fr':
        return rear ? 'Caméra arrière.' : 'Caméra avant.';
      default:
        return rear ? 'Rear camera.' : 'Front camera.';
    }
  }

  static String switchLens(String languageCode) {
    switch (languageOf(Locale(languageCode))) {
      case 'ar':
        return 'بدّل العدسة';
      case 'fr':
        return 'Changer de caméra';
      default:
        return 'Switch camera';
    }
  }

  static String scene(Iterable<String> labels, String languageCode) {
    final code = languageOf(Locale(languageCode));
    final spoken = BlindCameraSpeech.sceneFromLabels(
      labels,
      languageCode: code == 'ar' ? 'ar' : 'en',
    );
    if (code != 'fr' || spoken != BlindCameraSpeech.noSceneEn) return spoken;
    return 'Aucun libellé clair. Aucune scène n’est inventée.';
  }

  static String textRead(String raw, String languageCode) {
    final code = languageOf(Locale(languageCode));
    final text = raw.trim();
    if (text.isEmpty) {
      switch (code) {
        case 'ar':
          return 'لا نص واضحاً. لم أخترع كلمات. القارئ المحلي يقرأ الحرف اللاتيني المطبوع.';
        case 'fr':
          return 'Aucun texte clair. Rien n’est inventé. Le lecteur local lit le latin imprimé.';
        default:
          return 'No clear text was read. Nothing is invented. The local reader reads printed Latin.';
      }
    }
    switch (code) {
      case 'ar':
        return 'نص مقروء: $text. النص قد يخطئ. ليس تشخيصاً. القارئ المحلي يقرأ الحرف اللاتيني المطبوع.';
      case 'fr':
        return 'Texte latin imprimé: $text. Le texte peut être faux. Ce n’est pas un diagnostic.';
      default:
        return 'Text read: $text. The text may be wrong. It is not a diagnosis.';
    }
  }
}
