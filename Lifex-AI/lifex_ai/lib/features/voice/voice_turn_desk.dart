/// يحوّل نص الأمر إلى أثر واحد. الشاشة تنفّذ هذا الأثر ولا تعيد تفسير الجملة.
library lifex_ai.features.voice.voice_turn_desk;

import 'spoken_fold.dart';

enum VoiceTurnKind {
  pass,
  slower,
  faster,
  scene,
  barcode,
  updateModel,
  disableAuto,
  findPhone,
  openBlindCamera,
  details,
  readText,
  pauseDescription,
  resumeDescription,
  frontCamera,
  backCamera,
  askCloud,
  grantCloud,
  revokeCloud,
  openLens,
}

class VoiceTurn {
  const VoiceTurn.pass()
      : kind = VoiceTurnKind.pass,
        messageAr = '';

  const VoiceTurn(this.kind, this.messageAr);

  final VoiceTurnKind kind;
  final String messageAr;
}

VoiceTurn planVoiceTurn(String text) {
  final folded = foldSpoken(text);
  if (folded.isEmpty) return const VoiceTurn.pass();
  bool heard(String needle) => spokenContains(folded, needle);
  if (heard('عدسة جوجل') ||
      heard('عدسة google') ||
      heard('google lens') ||
      heard('جوجل لينس')) {
    return const VoiceTurn(VoiceTurnKind.openLens, '');
  }
  if (heard('أين جوالي') || heard('وين جوالي') || heard('فين جوالي')) {
    return const VoiceTurn(VoiceTurnKind.findPhone, '');
  }
  if (heard('أوقف التحديث التلقائي')) {
    return const VoiceTurn(
      VoiceTurnKind.disableAuto,
      'أوقفت التحديث التلقائي. لن يعود إلا إذا فعّلته أنت.',
    );
  }
  if (heard('حدّث ذكاء الكاميرا') || heard('حدث ذكاء الكاميرا')) {
    return const VoiceTurn(VoiceTurnKind.updateModel, '');
  }
  if (heard('أوقف الوصف') || heard('وقف الوصف')) {
    return const VoiceTurn(VoiceTurnKind.pauseDescription, 'أوقفت الوصف.');
  }
  if (heard('استأنف الوصف') || heard('كمل الوصف')) {
    return const VoiceTurn(VoiceTurnKind.resumeDescription, 'استأنفت الوصف.');
  }
  if (heard('الكاميرا الأمامية') || heard('كاميرا أمامية')) {
    return const VoiceTurn(VoiceTurnKind.frontCamera, '');
  }
  if (heard('الكاميرا الخلفية') || heard('كاميرا خلفية')) {
    return const VoiceTurn(VoiceTurnKind.backCamera, '');
  }
  if (heard('أعطني التفاصيل') ||
      heard('عطني التفاصيل') ||
      heard('تفاصيل المشهد') ||
      heard('صف لي المكان بالتفصيل')) {
    return const VoiceTurn(VoiceTurnKind.details, '');
  }
  if (heard('أوافق على الإرسال السحابي') ||
      heard('وافق على السحابة') ||
      heard('أرسل للسحابة')) {
    return const VoiceTurn(
      VoiceTurnKind.grantCloud,
      'سأفتح جلسة Gemini الحية وأرسل صورة مخفّضة ما دامت الموافقة قائمة.',
    );
  }
  if (heard('أوقف الإرسال السحابي') || heard('أوقف السحابة')) {
    return const VoiceTurn(
      VoiceTurnKind.revokeCloud,
      'أوقفت الإرسال السحابي. الوصف المحلي مستمر.',
    );
  }
  if (heard('اسأل الذكاء') || heard('اسأل عن المشهد')) {
    return const VoiceTurn(VoiceTurnKind.askCloud, '');
  }
  if (heard('اقرأ النص')) {
    return const VoiceTurn(VoiceTurnKind.readText, '');
  }
  if (heard('اقرأ الباركود') || heard('اقرأ الرمز')) {
    return const VoiceTurn(
      VoiceTurnKind.barcode,
      'سأفتح العدسة لقراءة الرمز. النص المقروء ليس تفسيراً لدواء.',
    );
  }
  if (heard('كاميرا المكفوفين')) {
    return const VoiceTurn(
      VoiceTurnKind.openBlindCamera,
      'أفتح كاميرا المكفوفين. الوصف الأساسي أولاً، والتفاصيل عند الطلب.',
    );
  }
  if (heard('ماذا يوجد أمامي') ||
      heard('ماذا أمامي') ||
      heard('صف المشهد') ||
      heard('صف ما أمامي') ||
      heard('اقرأ ما أمامي')) {
    return const VoiceTurn(
      VoiceTurnKind.scene,
      'سأفتح البث الحي لأصف الإطار التالي. إذا لم يظهر تصنيف واضح سأقول ذلك ولن أخترع مشهداً.',
    );
  }
  if (heard('أبطئ') ||
      heard('خفّض سرعة') ||
      heard('خفض سرعة') ||
      heard('اخفض سرعة') ||
      heard('خفّض السرعة') ||
      heard('خفض السرعة') ||
      heard('slow down') ||
      heard('slow the reading')) {
    return const VoiceTurn(VoiceTurnKind.slower, '');
  }
  if (heard('أسرع القراءة') ||
      heard('ارفع سرعة القراءة') ||
      heard('ارفع السرعة') ||
      heard('read faster') ||
      heard('faster reading')) {
    return const VoiceTurn(VoiceTurnKind.faster, '');
  }
  return const VoiceTurn.pass();
}
