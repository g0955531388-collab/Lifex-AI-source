/// رغبة المستخدم باستئناف وضع الوصول بعد إقلاع الهاتف.
/// لا تشغّل الكاميرا ولا الميكروفون عند الإقلاع.
library lifex_ai.features.accessibility.boot_access_preference;

class BootAccessDecision {
  const BootAccessDecision({
    required this.remembered,
    required this.cameraStartsAtBoot,
    required this.microphoneStartsAtBoot,
    required this.speech,
  });

  final bool remembered;
  final bool cameraStartsAtBoot;
  final bool microphoneStartsAtBoot;
  final String speech;

  static const cameraBlocked = false;
  static const microphoneBlocked = false;
}

class BootAccessPreference {
  const BootAccessPreference._();

  static const key = 'lifex_access_after_boot_v1';

  static BootAccessDecision decide({
    required bool userEnabled,
    required bool english,
  }) {
    final remembered = userEnabled;
    final speech = !remembered
        ? (english
            ? 'Automatic start after boot is off.'
            : 'البدء بعد إقلاع الهاتف متوقف.')
        : (english
            ? 'The choice is saved. Android will not open the camera or microphone at boot. Accessibility mode returns when you open Lifex-AI.'
            : 'الخيار محفوظ. أندرويد لن يفتح الكاميرا أو الميكروفون عند الإقلاع. وضع الوصول يعود عندما تفتح Lifex-AI.');
    return BootAccessDecision(
      remembered: remembered,
      cameraStartsAtBoot: false,
      microphoneStartsAtBoot: false,
      speech: speech,
    );
  }
}
