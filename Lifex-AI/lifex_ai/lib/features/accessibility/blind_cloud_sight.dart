/// سؤال سحابي عن المشهد. بلا مفتاح لا يُرسل شيء، ولا تُحفظ الإطارات للإرسال لاحقاً.
library lifex_ai.features.accessibility.blind_cloud_sight;

class BlindCloudAnswer {
  const BlindCloudAnswer({
    required this.spokenAr,
    required this.sent,
  });

  final String spokenAr;
  final bool sent;
}

class BlindCloudSight {
  BlindCloudSight({
    this.endpointConfigured = false,
    this.liveVideoSupported = false,
  });

  /// لا مفتاح ولا واجهة رؤية رسمية في هذا البناء.
  final bool endpointConfigured;

  /// Gemini Live وCopilot الاستهلاكي لا يقدمان هنا بث فيديو عاماً من التطبيق.
  final bool liveVideoSupported;

  int queuedFrames = 0;

  BlindCloudAnswer ask({
    required bool userAllowsCloud,
    bool? online,
  }) {
    if (!userAllowsCloud) {
      return const BlindCloudAnswer(
        spokenAr: 'الإرسال السحابي متوقف حتى توافق عليه. الوصف المحلي مستمر.',
        sent: false,
      );
    }
    if (online == false) {
      return const BlindCloudAnswer(
        spokenAr:
            'لا اتصال. الوصف المحلي مستمر، ولن تُرسل إطارات قديمة عند عودة الشبكة.',
        sent: false,
      );
    }
    if (!endpointConfigured || !liveVideoSupported) {
      return const BlindCloudAnswer(
        spokenAr:
            'المسار السحابي غير مربوط بمفتاح أو واجهة رسمية في هذا البناء. '
            'لم تُرسل صورة. الوصف المحلي مستمر.',
        sent: false,
      );
    }
    return const BlindCloudAnswer(
      spokenAr: 'القناة السحابية جاهزة، ولم يُختر إرسال في هذا المسار.',
      sent: false,
    );
  }

  /// عودة الشبكة لا تشغّل طابور صور.
  BlindCloudAnswer onNetworkReturned() {
    queuedFrames = 0;
    return const BlindCloudAnswer(
      spokenAr: 'عادت الشبكة. لم تُرسل صور قديمة. الوصف المحلي مستمر.',
      sent: false,
    );
  }
}
