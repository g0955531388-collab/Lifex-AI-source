/// =============================================================
/// Lifex-AI — مساعدة بصرية
/// الملف: live_sight_conductor.dart
/// نبض البث الحي: يقرر ماذا يُنطق بعد كل إطار، بلا اختراع أجسام.
/// =============================================================
library lifex_ai.features.accessibility.live_sight_conductor;

import 'assistive_vision_engine.dart';

class LiveSightPulse {
  const LiveSightPulse({
    required this.spokenAr,
    required this.speakNow,
    this.engineReady = false,
    this.waitingForFrame = false,
  });

  final String spokenAr;
  final bool speakNow;
  final bool engineReady;
  final bool waitingForFrame;
}

class LiveSightScheduler {
  LiveSightScheduler({this.interval = const Duration(seconds: 2)});

  Duration interval;
  bool busy = false;
  bool narrationEnabled = true;
  DateTime nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);

  bool claim(DateTime now) {
    if (!narrationEnabled || busy || now.isBefore(nextAllowed)) return false;
    busy = true;
    nextAllowed = now.add(interval);
    return true;
  }

  void release() {
    busy = false;
  }
}

/// موصل البث: الكاميرا المفتوحة ليست وصفاً، والمحرك الغائب ليس مشهداً.
class LiveSightConductor {
  bool _alreadyToldEngineMissing = false;
  String? _lastSpoken;

  LiveSightPulse pulse({
    required bool cameraReady,
    required bool userConsentedOnThisScreen,
    List<int>? frameBytes,
    AssistiveVisionResult? vision,
    bool force = false,
  }) {
    if (!userConsentedOnThisScreen) {
      return const LiveSightPulse(
        spokenAr: 'البث الحي لا يبدأ قبل موافقتك الظاهرة على هذه الشاشة.',
        speakNow: true,
      );
    }
    if (!cameraReady) {
      return const LiveSightPulse(
        spokenAr: 'لم تُفتح الكاميرا بعد. أحتاج إذناً من النظام ثم عدسة جاهزة.',
        speakNow: true,
      );
    }
    if (frameBytes == null || frameBytes.isEmpty) {
      return const LiveSightPulse(
        spokenAr: 'العدسة مفتوحة. أنتظر إطاراً حياً.',
        speakNow: false,
        waitingForFrame: true,
      );
    }
    if (vision == null) {
      return const LiveSightPulse(
        spokenAr: 'وصل إطار. لم تُطلب منه قراءة بعد.',
        speakNow: false,
      );
    }
    if (!vision.success) {
      final message =
          'البث الحي يعمل على هذه الشاشة فقط. ${vision.spokenMessageAr} '
          'لن أخترع جداراً أو شخصاً أو نصاً.';
      final speak = !_alreadyToldEngineMissing;
      _alreadyToldEngineMissing = true;
      _lastSpoken = message;
      return LiveSightPulse(spokenAr: message, speakNow: speak);
    }
    _alreadyToldEngineMissing = false;
    final spoken = vision.spokenMessageAr.trim();
    final speak = force || (spoken.isNotEmpty && spoken != _lastSpoken);
    _lastSpoken = spoken;
    return LiveSightPulse(
      spokenAr: spoken,
      speakNow: speak,
      engineReady: true,
    );
  }
}
