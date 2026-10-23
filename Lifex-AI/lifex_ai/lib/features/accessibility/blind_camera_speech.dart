/// =============================================================
/// Lifex-AI — كاميرا المكفوفين
/// يصوغ ما أعاده المحرك. التصنيف الفارغ والنص الفارغ يبقيان فارغين.
/// =============================================================
library lifex_ai.features.accessibility.blind_camera_speech;

class BlindCameraSpeech {
  const BlindCameraSpeech._();

  static const noSceneAr = 'لم يظهر تصنيف واضح في الإطار. لن أخترع مشهداً.';

  static const noTextAr = 'لم يُقرأ نص واضح. لن يُخترع محتوى.';

  static const noCurrencyAr = 'فئة العملة لا تُستنتج من الصورة. لن أعلن رقماً.';

  static const noPathAr = 'وصلت الصورة بلا مسار. لن أخترع مشهداً ولا نصاً.';

  static const noFrameAr = 'الإطار الحي لم يُقرأ. لن أخترع مشهداً.';

  static const noFrameEn = 'The live frame was not read. No scene is invented.';

  static const noSceneEn = 'No clear label appeared. No scene is invented.';

  /// أسماء شائعة يعيدها نموذج التصنيف بالإنجليزية. ما غاب عن الجدول يبقى كما عاد.
  static const labelAr = <String, String>{
    'person': 'شخص',
    'human': 'شخص',
    'people': 'أشخاص',
    'man': 'رجل',
    'woman': 'امرأة',
    'boy': 'طفل',
    'girl': 'طفل',
    'child': 'طفل',
    'obstacle': 'عائق',
    'chair': 'كرسي',
    'door': 'باب',
    'car': 'سيارة',
    'tree': 'شجرة',
    'table': 'طاولة',
    'bottle': 'قارورة',
    'phone': 'هاتف',
    'mobile phone': 'هاتف',
    'stairs': 'درج',
    'window': 'نافذة',
    'dog': 'كلب',
    'cat': 'قطة',
    'food': 'طعام',
    'book': 'كتاب',
    'cup': 'كوب',
    'glasses': 'نظارة',
    'footwear': 'حذاء',
    'clothing': 'ملابس',
    'building': 'مبنى',
    'road': 'طريق',
    'plant': 'نبات',
    'flower': 'زهرة',
    'hand': 'يد',
    'face': 'وجه',
    'smile': 'ابتسامة',
    'teeth': 'أسنان',
    'tooth': 'سن',
    'furniture': 'أثاث',
    'desk': 'مكتب',
    'couch': 'أريكة',
    'bed': 'سرير',
    'house': 'بيت',
    'vehicle': 'مركبة',
    'bicycle': 'دراجة',
    'motorcycle': 'دراجة نارية',
    'bus': 'حافلة',
    'truck': 'شاحنة',
    'traffic light': 'إشارة مرور',
    'sidewalk': 'رصيف',
    'sky': 'سماء',
    'drink': 'شراب',
    'plate': 'طبق',
    'computer': 'حاسوب',
    'laptop': 'حاسوب محمول',
    'bag': 'حقيبة',
    'bird': 'طائر',
    'animal': 'حيوان',
    'hair': 'شعر',
    'eye': 'عين',
    'shoe': 'حذاء',
    'hat': 'قبعة',
    'jacket': 'سترة',
    'shirt': 'قميص',
    'watch': 'ساعة',
    'camera': 'كاميرا',
    'television': 'تلفاز',
    'screen': 'شاشة',
    'keyboard': 'لوحة مفاتيح',
    'paper': 'ورقة',
    'document': 'وثيقة',
    'key': 'مفتاح',
    'clock': 'ساعة',
    'lamp': 'مصباح',
    'light': 'ضوء',
    'floor': 'أرضية',
    'wall': 'جدار',
    'room': 'غرفة',
    'kitchen': 'مطبخ',
    'bathroom': 'حمّام',
    'sink': 'مغسلة',
    'mirror': 'مرآة',
    'toy': 'لعبة',
    'ball': 'كرة',
    'wheel': 'عجلة',
    'street': 'شارع',
    'sign': 'لافتة',
    'box': 'صندوق',
    'shelf': 'رف',
  };

  static bool explainsInArabic(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar');

  static String phraseForLabel(String label, String languageCode) {
    final name = label.trim();
    if (!explainsInArabic(languageCode)) return name;
    return labelAr[name.toLowerCase()] ?? name;
  }

  /// إشارات إنسان في التصنيف نفسه. «كلب» معها خطأ شائع لمصنّف الصورة.
  static const humanCue = {
    'person',
    'human',
    'people',
    'man',
    'woman',
    'boy',
    'girl',
    'child',
    'face',
    'clothing',
    'shirt',
    'jacket',
    'glasses',
    'hair',
    'hand',
    'outerwear',
    'coat',
    'selfie',
    'human face',
    'fashion accessory',
  };

  static const dogBesideHuman = {'dog', 'puppy', 'canine', 'hound'};

  static List<String> distinctLabels(Iterable<String> labels) {
    final seen = <String>{};
    final names = <String>[];
    for (final raw in labels) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      names.add(name);
    }
    return names;
  }

  /// يسقط الكلب إذا وُجدت إشارة إنسان في الأسماء نفسها.
  static List<String> withoutFalseDog(Iterable<String> labels) {
    final names = distinctLabels(labels);
    final keys = names.map((name) => name.toLowerCase()).toSet();
    if (!keys.any(humanCue.contains)) return names;
    return [
      for (final name in names)
        if (!dogBesideHuman.contains(name.toLowerCase())) name,
    ];
  }

  static String sceneFromLabels(
    Iterable<String> labels, {
    String languageCode = 'ar',
  }) {
    final names = [
      for (final label in withoutFalseDog(labels))
        phraseForLabel(label, languageCode),
    ];
    if (names.isEmpty) {
      return explainsInArabic(languageCode) ? noSceneAr : noSceneEn;
    }
    return names.join(explainsInArabic(languageCode) ? '، ' : ', ');
  }

  static String textFromRaw(String raw, {String languageCode = 'ar'}) {
    final text = raw.trim();
    if (text.isEmpty) {
      return explainsInArabic(languageCode)
          ? noTextAr
          : 'No clear text was read. Nothing is invented.';
    }
    if (explainsInArabic(languageCode)) {
      return 'نص مقروء:\n$text\nالنص قد يخطئ. ليس تشخيصاً.';
    }
    return 'Text read:\n$text\nThe text may be wrong. It is not a diagnosis.';
  }

  static String liveFrom({
    required Iterable<String> labels,
    required String text,
    String languageCode = 'ar',
    bool includeScene = true,
    bool includeText = true,
  }) {
    if (!includeScene && includeText) {
      return textFromRaw(text, languageCode: languageCode);
    }
    final parts = <String>[];
    if (includeScene) {
      parts.add(sceneFromLabels(labels, languageCode: languageCode));
    }
    if (includeText && text.trim().isNotEmpty) {
      parts.add(textFromRaw(text, languageCode: languageCode));
    }
    if (parts.isEmpty) {
      return explainsInArabic(languageCode) ? noSceneAr : noSceneEn;
    }
    return parts.join('\n');
  }

  /// العربية والإنجليزية من جدول الجهاز. أي لغة أخرى تبقى الجملة الإنجليزية مع تصريح بالنقص.
  static String forDeviceLanguage(String spoken, String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.isEmpty || code.startsWith('ar') || code.startsWith('en')) {
      return spoken;
    }
    return 'No on-device glossary for $code. $spoken';
  }

  static String unreadableFrame(String languageCode) =>
      explainsInArabic(languageCode) ? noFrameAr : noFrameEn;

  static String lensOpen(String languageCode, {required bool live}) {
    if (explainsInArabic(languageCode)) {
      return live
          ? 'تم فتح كاميرا المساعد البصري'
          : 'اللقطة الواحدة جاهزة. اضغط التقط لسماع شرح واحد.';
    }
    return live
        ? 'Live view is open on this screen. I explain when the frame changes. Closing the page stops the lens.'
        : 'One frame is ready. Press capture to hear a single explanation.';
  }

  static String lensFailed(String languageCode) => explainsInArabic(languageCode)
      ? 'تعذّر تشغيل العدسة على هذا الجهاز. يمكنك اختيار لقطة واحدة.'
      : 'The lens did not start on this device. You can choose a single frame.';

  static String cameraDenied(String languageCode) =>
      explainsInArabic(languageCode)
          ? 'رفض النظام إذن الكاميرا. البث متوقف.'
          : 'The system denied the camera. The view is stopped.';

  static String noLens(String languageCode) => explainsInArabic(languageCode)
      ? 'لا توجد عدسة ظاهرة لهذا الجهاز.'
      : 'No lens is visible on this device.';

  static bool hasScene(Iterable<String> labels) =>
      distinctLabels(labels).isNotEmpty;

  static bool hasReading({
    required Iterable<String> labels,
    required String text,
  }) =>
      hasScene(labels) || text.trim().isNotEmpty;
}
