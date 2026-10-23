/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: hardware_cue_calibrator.dart
/// أي زر يستدعي الميكروفون، وبكم ضغطة. بلا Device Admin.
/// =============================================================
library lifex_ai.features.voice.hardware_cue_calibrator;

enum HardwareCueKind {
  volumeUpDouble,
  volumeDownDouble,
  headsetHook,
  onScreenHold,
  powerDouble,
}

enum StartSignalKind { voice, tone, both }

class HardwareCueCalibrator {
  HardwareCueKind kind = HardwareCueKind.volumeUpDouble;
  int tapCount = 2;
  int windowMs = 480;
  StartSignalKind startSignal = StartSignalKind.both;

  bool get powerButtonIsSystemOwned => kind == HardwareCueKind.powerDouble;

  String honestyAr() {
    switch (kind) {
      case HardwareCueKind.powerDouble:
        return 'زر الطاقة ملك النظام (غالباً الكاميرا). التطبيق العادي لا يخطفه. '
            'يمكن طلب دور المساعد لاحقاً. بلا Device Admin. عاير رفع/خفض الصوت أو السماعة.';
      case HardwareCueKind.volumeUpDouble:
        return _volumeCueHonesty('رفع');
      case HardwareCueKind.volumeDownDouble:
        return _volumeCueHonesty('خفض');
      case HardwareCueKind.headsetHook:
        return 'زر السماعة السلكية أو بلوتوث إن أوصله النظام لهذا التطبيق.';
      case HardwareCueKind.onScreenHold:
        return 'الزر الظاهر في شريط الصوت. يعمل حتى في وضع بقاء الطاقة كدفعة واحدة.';
    }
  }

  String _volumeCueHonesty(String direction) {
    return '$direction الصوت $tapCount مرات متتالية يستدعي الميكروفون فقط بينما شاشة ليفكس في الأمام. '
        'إشعار المراقبة لا يلتقط زر الصوت في الخلفية ولا من شاشة القفل. '
        'البديل المتاح هو زر التحدث على الشاشة.';
  }

  String kindLabelAr(HardwareCueKind value) {
    switch (value) {
      case HardwareCueKind.volumeUpDouble:
        return 'رفع الصوت';
      case HardwareCueKind.volumeDownDouble:
        return 'خفض الصوت';
      case HardwareCueKind.headsetHook:
        return 'زر السماعة';
      case HardwareCueKind.onScreenHold:
        return 'الزر على الشاشة';
      case HardwareCueKind.powerDouble:
        return 'زر الطاقة (معايرة محدودة)';
    }
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'tapCount': tapCount.clamp(2, 4),
        'windowMs': windowMs.clamp(250, 1800),
        'startSignal': startSignal.name,
      };

  void applyMap(Map<String, dynamic> raw) {
    for (final value in HardwareCueKind.values) {
      if (value.name == raw['kind']) kind = value;
    }
    final taps = raw['tapCount'];
    if (taps is int) tapCount = taps.clamp(2, 4);
    final window = raw['windowMs'];
    if (window is int) windowMs = window.clamp(250, 1800);
    for (final value in StartSignalKind.values) {
      if (value.name == raw['startSignal']) startSignal = value;
    }
  }
}

/// عدّاد ضغطات داخل النافذة الزمنية. مستقل عن أندرويد ليُختبر.
class HardwareTapWindow {
  HardwareTapWindow({required this.needed, required this.window});

  final int needed;
  final Duration window;
  final List<DateTime> _hits = [];

  bool register(DateTime at, {required bool matchingKind}) {
    if (!matchingKind) {
      _hits.clear();
      return false;
    }
    _hits.removeWhere((hit) => at.difference(hit) > window);
    _hits.add(at);
    if (_hits.length < needed) return false;
    _hits.clear();
    return true;
  }
}
