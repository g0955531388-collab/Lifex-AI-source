/// يحوّل نص الأمر إلى أثر واحد. الشاشة تنفّذ هذا الأثر ولا تعيد تفسير الجملة.
library lifex_ai.features.voice.voice_turn_desk;

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
  final raw = text.trim();
  final folded = raw.toLowerCase();
  if (raw.isEmpty) return const VoiceTurn.pass();
  if (raw.contains('أين جوالي')) {
    return const VoiceTurn(VoiceTurnKind.findPhone, '');
  }
  if (raw.contains('أوقف التحديث التلقائي') || raw.contains('اوقف التحديث التلقائي')) {
    return const VoiceTurn(
      VoiceTurnKind.disableAuto,
      'أوقفت التحديث التلقائي. لن يعود إلا إذا فعّلته أنت.',
    );
  }
  if (raw.contains('حدّث ذكاء الكاميرا') || raw.contains('حدث ذكاء الكاميرا')) {
    return const VoiceTurn(VoiceTurnKind.updateModel, '');
  }
  if (raw.contains('أوقف الوصف') || raw.contains('اوقف الوصف')) {
    return const VoiceTurn(VoiceTurnKind.pauseDescription, 'أوقفت الوصف.');
  }
  if (raw.contains('استأنف الوصف')) {
    return const VoiceTurn(VoiceTurnKind.resumeDescription, 'استأنفت الوصف.');
  }
  if (raw.contains('الكاميرا الأمامية') || raw.contains('كاميرا أمامية')) {
    return const VoiceTurn(VoiceTurnKind.frontCamera, '');
  }
  if (raw.contains('الكاميرا الخلفية') || raw.contains('كاميرا خلفية')) {
    return const VoiceTurn(VoiceTurnKind.backCamera, '');
  }
  if (raw.contains('أعطني التفاصيل') || raw.contains('تفاصيل المشهد')) {
    return const VoiceTurn(VoiceTurnKind.details, '');
  }
  if (raw.contains('اسأل الذكاء') || raw.contains('اسأل عن المشهد')) {
    return const VoiceTurn(VoiceTurnKind.askCloud, '');
  }
  if (raw.contains('اقرأ النص')) {
    return const VoiceTurn(VoiceTurnKind.readText, '');
  }
  if (raw.contains('اقرأ الباركود') || raw.contains('اقرأ الرمز')) {
    return const VoiceTurn(
      VoiceTurnKind.barcode,
      'سأفتح العدسة لقراءة الرمز. النص المقروء ليس تفسيراً لدواء.',
    );
  }
  if (raw.contains('كاميرا المكفوفين')) {
    return const VoiceTurn(
      VoiceTurnKind.openBlindCamera,
      'أفتح كاميرا المكفوفين. الوصف الأساسي أولاً، والتفاصيل عند الطلب.',
    );
  }
  if (raw.contains('ماذا يوجد أمامي') ||
      raw.contains('ماذا أمامي') ||
      raw.contains('صف المشهد') ||
      raw.contains('صف ما أمامي') ||
      raw.contains('اقرأ ما أمامي')) {
    return const VoiceTurn(
      VoiceTurnKind.scene,
      'سأفتح البث الحي لأصف الإطار التالي. إذا لم يظهر تصنيف واضح سأقول ذلك ولن أخترع مشهداً.',
    );
  }
  if (raw.contains('أبطئ') ||
      raw.contains('ابطئ') ||
      raw.contains('خفّض سرعة') ||
      raw.contains('خفض سرعة') ||
      raw.contains('اخفض سرعة') ||
      raw.contains('خفّض السرعة') ||
      raw.contains('خفض السرعة') ||
      folded.contains('slow down') ||
      folded.contains('slow the reading')) {
    return const VoiceTurn(VoiceTurnKind.slower, '');
  }
  if (raw.contains('أسرع القراءة') ||
      raw.contains('اسرع القراءة') ||
      raw.contains('ارفع سرعة القراءة') ||
      raw.contains('ارفع السرعة') ||
      folded.contains('read faster') ||
      folded.contains('faster reading')) {
    return const VoiceTurn(VoiceTurnKind.faster, '');
  }
  return const VoiceTurn.pass();
}
