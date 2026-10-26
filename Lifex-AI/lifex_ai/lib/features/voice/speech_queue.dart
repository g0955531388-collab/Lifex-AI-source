/// طابور نطق واحد. الطلب العادي يُرفض أثناء النطق.
/// الطلب العاجل يقطع الجملة الحالية، والاهتزاز ينتظر نهايتها.
library lifex_ai.features.voice.speech_queue;

import 'voice_engine.dart';

class SpeechQueue {
  int _epoch = 0;
  bool _busy = false;
  Future<void> Function()? _haptic;

  bool get isSpeaking => _busy;

  Future<bool> speakQueued({
    required String text,
    required Future<bool> Function(String text) speak,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return Future<bool>.value(false);
    return _run(trimmed, speak);
  }

  Future<bool> speakInterruptible({
    required String text,
    required Future<bool> Function(String text) speak,
    required Future<void> Function() stop,
    Future<void> Function()? hapticAfter,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    _haptic = null;
    _epoch++;
    if (_busy) await stop();
    _haptic = hapticAfter;
    return _run(trimmed, speak);
  }

  Future<bool> _run(
    String text,
    Future<bool> Function(String text) speak,
  ) async {
    final epoch = _epoch;
    _busy = true;
    var ok = false;
    try {
      ok = await speak(text);
    } finally {
      if (epoch == _epoch) {
        final haptic = _haptic;
        _haptic = null;
        if (haptic != null) await haptic();
        if (epoch == _epoch) _busy = false;
      }
    }
    return ok;
  }
}

/// المدخل الوحيد الذي تمر منه جمل الواجهة نحو محرك النطق.
class SpeechDesk {
  SpeechDesk({SpeechQueue? queue}) : queue = queue ?? SpeechQueue();

  static final SpeechDesk instance = SpeechDesk();

  final SpeechQueue queue;

  Future<bool> speakQueued(String text) {
    return queue.speakQueued(
      text: text,
      speak: (value) async => (await VoiceEngine.instance.speak(value)).success,
    );
  }

  Future<bool> speakInterruptible(
    String text, {
    Future<void> Function()? hapticAfter,
  }) {
    return queue.speakInterruptible(
      text: text,
      hapticAfter: hapticAfter,
      stop: VoiceEngine.instance.stopSpeaking,
      speak: (value) async => (await VoiceEngine.instance.speak(value)).success,
    );
  }
}
