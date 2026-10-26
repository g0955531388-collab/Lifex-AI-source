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

/// تحية المساعد البصري. لا تُقال قبل ثبوت البث والتحليل والاستماع والنطق معاً.
class VisualAssistOpening {
  const VisualAssistOpening._();

  static const welcomeAr =
      'أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى';

  static const welcomeEn =
      'Welcome. I am your visual assistant in Lifex. I hear and see.';

  static const unsureAr = 'لم أتمكن من تحديد المشهد بثقة.';

  static const unsureEn = 'I cannot identify this scene with confidence.';

  static const hearingOffAr =
      'الكاميرا تعمل. الاستماع غير متاح، لذلك لن أقول إنني أسمع.';

  static const hearingOffEn =
      'The camera is on. Listening is not available, so I will not say that I can hear you.';

  static const speechOffAr = 'النطق غير مربوط. لن أقول إن الجلسة تتكلم.';

  static const speechOffEn =
      'Speech is not connected. I will not say that the session is speaking.';

  static const cameraAskAr =
      'أحتاج إذن الكاميرا لأبدأ. ستظهر نافذة النظام. يمكنك إيقاف الجلسة في أي وقت.';

  static const cameraAskEn =
      'I need the camera permission to start. The system window will appear. You can stop the session at any time.';

  static const micAskAr = 'أحتاج إذن الميكروفون لأسمعك. ستظهر نافذة النظام.';

  static const micAskEn =
      'I need the microphone permission to hear you. The system window will appear.';

  static const micDeniedAr =
      'لم يُمنح الميكروفون. أصف ما تظهره الكاميرا، ولا أقول إنني أسمعك.';

  static const micDeniedEn =
      'The microphone was not granted. I describe what the camera shows, and I do not say that I can hear you.';

  static const cloudSendingAr =
      'أُرسل الإطار إلى جيميني بعد جاهزية الجلسة. هذا وصف سحابي، وليس قياساً للمسافة.';

  static const cloudSendingEn =
      'The frame is going to Gemini after the session became ready. This is a cloud description, not a distance measurement.';

  static const cloudDownAr =
      'تعذّر اتصال جيميني. الوصف المحلي مستمر إن عاد المصنّف بنتيجة.';

  static const cloudDownEn =
      'The Gemini connection did not start. Local description continues if the labeler returns a result.';

  static const cloudStoppedAr = 'أوقفت الإرسال السحابي. الوصف المحلي مستمر.';

  static const cloudStoppedEn =
      'Cloud sending is stopped. Local description continues.';

  static const offlineClosedAr =
      'لا إنترنت. أُغلق اتصال جيميني. الوصف المحلي مستمر. لا تُرسل صور قديمة.';

  static const offlineClosedEn =
      'No internet. The Gemini connection is closed. Local description continues. Old pictures are not sent.';

  static const offlineStayAr =
      'لا إنترنت. اتصال جيميني مغلق حتى ترجع الشبكة. الوصف المحلي مستمر.';

  static const offlineStayEn =
      'No internet. Gemini stays closed until the network returns. Local description continues.';

  static String _pick(String languageCode, String arabic, String english) =>
      BlindCameraSpeech.explainsInArabic(languageCode) ? arabic : english;

  static String cameraAsk(String languageCode) =>
      _pick(languageCode, cameraAskAr, cameraAskEn);

  static String micAsk(String languageCode) =>
      _pick(languageCode, micAskAr, micAskEn);

  static String micDenied(String languageCode) =>
      _pick(languageCode, micDeniedAr, micDeniedEn);

  static String unsure(String languageCode) =>
      _pick(languageCode, unsureAr, unsureEn);

  static String hearingOff(String languageCode) =>
      _pick(languageCode, hearingOffAr, hearingOffEn);

  static String speechOff(String languageCode) =>
      _pick(languageCode, speechOffAr, speechOffEn);

  static String cloudSending(String languageCode) =>
      _pick(languageCode, cloudSendingAr, cloudSendingEn);

  static String cloudDown(String languageCode) =>
      _pick(languageCode, cloudDownAr, cloudDownEn);

  static String cloudStopped(String languageCode) =>
      _pick(languageCode, cloudStoppedAr, cloudStoppedEn);

  static String offline({
    required String languageCode,
    required bool wasOpen,
  }) =>
      wasOpen
          ? _pick(languageCode, offlineClosedAr, offlineClosedEn)
          : _pick(languageCode, offlineStayAr, offlineStayEn);

  /// فارغ يعني: لا تُنطق التحية. النقص ليس نجاحاً.
  static String? welcome({
    required String languageCode,
    required bool cameraStreaming,
    required bool analysisReady,
    required bool hearingReady,
    required bool speakingReady,
  }) {
    if (!cameraStreaming ||
        !analysisReady ||
        !hearingReady ||
        !speakingReady) {
      return null;
    }
    return _pick(languageCode, welcomeAr, welcomeEn);
  }
}
