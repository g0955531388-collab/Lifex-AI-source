/// طابور نطق واحد. الطلب العادي يُرفض أثناء النطق.
/// الطلب العاجل يقطع الجملة الحالية، والاهتزاز ينتظر نهايتها.
library lifex_ai.features.voice.speech_queue;

class SpeechQueue {
  int _epoch = 0;
  bool _busy = false;
  Future<void> Function()? _haptic;

  bool get isSpeaking => _busy;

  /// يلغي اهتزاز الجملة الجارية حتى لا يتبع الإيقاف صوتاً جديداً.
  void abandon() {
    _haptic = null;
    _epoch++;
    _busy = false;
  }

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
