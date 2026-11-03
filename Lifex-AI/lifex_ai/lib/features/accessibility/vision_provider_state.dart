/// حالة موفر الرؤية كما يسمعها المستخدم. حالة واحدة صريحة، بلا نجاح مفترض.
library lifex_ai.features.accessibility.vision_provider_state;

enum VisionProviderState {
  ready,
  connecting,
  needsPermission,
  needsCloudConsent,
  offline,
  localModelUnavailable,
  initFailed,
  lowConfidence,
}

/// الجمل بالعربية مفاتيحُ القاموس الموحد؛ الإنجليزية في assets/i18n/ui_en.json.
class VisionStateSpeech {
  const VisionStateSpeech._();

  static const checkingModel = 'أتحقق من نموذج الكشف المحلي.';

  static const lines = <VisionProviderState, String>{
    VisionProviderState.ready: 'الرؤية جاهزة.',
    VisionProviderState.connecting: 'جارٍ الاتصال بالرؤية السحابية.',
    VisionProviderState.needsPermission: 'الكاميرا تحتاج إذناً.',
    VisionProviderState.needsCloudConsent:
        'الوصف السحابي يحتاج موافقتك قبل إرسال أي إطار.',
    VisionProviderState.offline:
        'لا إنترنت، والنموذج المحلي غير متاح. لا أستطيع التعرف على الأشياء الآن.',
    VisionProviderState.localModelUnavailable:
        'نموذج الكشف المحلي غير متاح. أسماء الأشياء من تصنيف الصورة فقط، بلا مواضع.',
    VisionProviderState.initFailed: 'فشلت تهيئة الكاميرا.',
    VisionProviderState.lowConfidence: 'لم أتعرف على المشهد بثقة.',
  };

  static String of(VisionProviderState state) => lines[state]!;
}

/// الأولوية: الإذن، ثم التهيئة، ثم الموافقة السحابية، ثم الاتصال، ثم الثقة، ثم توفر مسار.
VisionProviderState resolveVisionProviderState({
  required bool cameraGranted,
  required bool cameraInitFailed,
  required bool localModelLoaded,
  required bool cloudRequested,
  required bool cloudConsent,
  required bool? online,
  required bool cloudConnecting,
  required bool cloudStreaming,
  bool lowConfidence = false,
}) {
  if (!cameraGranted) return VisionProviderState.needsPermission;
  if (cameraInitFailed) return VisionProviderState.initFailed;
  if (cloudRequested && !cloudConsent) {
    return VisionProviderState.needsCloudConsent;
  }
  if (cloudConnecting && !cloudStreaming && online != false) {
    return VisionProviderState.connecting;
  }
  if (lowConfidence) return VisionProviderState.lowConfidence;
  if (localModelLoaded || cloudStreaming) return VisionProviderState.ready;
  if (online == false) return VisionProviderState.offline;
  return VisionProviderState.localModelUnavailable;
}
