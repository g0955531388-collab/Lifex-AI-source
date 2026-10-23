/// =============================================================
/// Lifex-AI — المراقبة الصحية
/// الملف: clinical_watch_policy.dart
/// ميكروفون/عدسة بموافقة وإشعار ظاهر. ليست تجسساً وليست أرشيفاً.
/// =============================================================
library lifex_ai.features.voice.clinical_watch_policy;

enum ClinicalWatchPurpose {
  commands,
  unusualSounds,
  deviceAlarms,
  breathing,
  fallImpact,
  bedsideCamera,
}

class ClinicalWatchPolicy {
  const ClinicalWatchPolicy();

  bool mayListenAwayFromScreen({
    required bool userOptIn,
    required bool persistentNoticeVisible,
  }) {
    return userOptIn && persistentNoticeVisible;
  }

  bool mayOpenCameraWithoutArchive({
    required bool userOptIn,
    required bool persistentNoticeVisible,
  }) {
    return userOptIn && persistentNoticeVisible;
  }

  bool get storesImageBytes => false;
  bool get storesVideoBytes => false;
  bool get hiddenCapture => false;
  bool get usesDeviceAdmin => false;
  bool get usesSimulatedClassifier => false;

  String purposeAr(ClinicalWatchPurpose purpose) {
    switch (purpose) {
      case ClinicalWatchPurpose.commands:
        return 'أوامر صوتية بعد إشارة الزر المعاير.';
      case ClinicalWatchPurpose.unusualSounds:
        return 'استماع لأصوات غير معتادة بجانب المريض.';
      case ClinicalWatchPurpose.deviceAlarms:
        return 'استماع لأجهزة إنذار صحية ظاهرة في الغرفة.';
      case ClinicalWatchPurpose.breathing:
        return 'متابعة نمط التنفس الصوتي إن وُجد محرك معتمد.';
      case ClinicalWatchPurpose.fallImpact:
        return 'متابعة سقوط أو اصطدام إن وُجد محرك معتمد.';
      case ClinicalWatchPurpose.bedsideCamera:
        return 'فتح العدسة حياً بلا حفظ إطار.';
    }
  }

  String engineHonestyAr(ClinicalWatchPurpose purpose) {
    switch (purpose) {
      case ClinicalWatchPurpose.commands:
        return 'أوامر صوتية ما دام إشعار الحماية ظاهراً، حتى والتطبيق في الخلفية. إيقاف الإشعار يوقف الميكروفون. لا اتصال صامت.';
      case ClinicalWatchPurpose.bedsideCamera:
        return 'العدسة تُفتح وتُعرض. لا أرشيف صور. الوصف الآلي يحتاج محرك رؤية معتمداً.';
      case ClinicalWatchPurpose.unusualSounds:
      case ClinicalWatchPurpose.deviceAlarms:
      case ClinicalWatchPurpose.breathing:
      case ClinicalWatchPurpose.fallImpact:
        return 'الميكروفون يعمل بموافقتك مع إشعار ظاهر. تصنيف الصوت (تنفس/سقوط/إنذار) '
            'لا يُعلن حتى يُربط محرك صوتي معتمد. لن أخترع حدثاً.';
    }
  }

  /// صياغة للمتجر والجهات: حاجة سريرية ظاهرة، ليست تصويراً خفياً.
  String storeAndLegalJustificationAr() =>
      'ليفكس يستخدم الميكروفون والعدسة لمراقبة سريرية اختيارية بجانب المريض '
      '(إنذارات أجهزة، نداء أوامر، مساعدة مكفوفين، متابعة سقوط محتمل). '
      'يعمل ذلك فقط بعد موافقة ظاهرة، مع إشعار نظام دائم يمكن إيقافه فوراً. '
      'لا Device Admin، لا تصوير خفي لمن يمسك الهاتف، ولا حفظ صور أو مقاطع '
      'من جلسة المراقبة: العملية فتح حسّاس حي ثم إتلاف الإطار بعد المحاولة. '
      'لا يُستخدم تصنيف صوتي عشوائي ولا تسجيل فيديو خلفي. '
      'هذا استخدام صحي معلن وفق حاجة ماسّة للمراقبة، وليس أرشيفاً ولا تتبعاً خفياً.';
}
