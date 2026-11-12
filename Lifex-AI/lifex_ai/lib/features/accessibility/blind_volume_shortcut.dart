/// أربع ضغطات على رفع الصوت تفتح مساعدة الرؤية وواجهة التطبيق في الأمام.
library lifex_ai.features.accessibility.blind_volume_shortcut;

class BlindVolumeShortcut {
  const BlindVolumeShortcut._();

  static const confirmationAr = 'نظام ليفكس يعمل، جارٍ تشغيل مساعدة الرؤية';
  static const taps = 4;
  static const windowMs = 1600;
  static const prefsKey = 'lifex_blind_volume_shortcut_v1';
  static const foregroundOnlyAr =
      'أربع ضغطات تعمل وواجهة ليفكس في الأمام. لا تُلتقط من شاشة القفل ولا والتطبيق مغلق.';

  static bool armed({
    required bool accessModeEnabled,
    required bool shortcutChosen,
  }) =>
      accessModeEnabled || shortcutChosen;
}
