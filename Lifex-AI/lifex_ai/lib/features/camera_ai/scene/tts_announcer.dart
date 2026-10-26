/// نطق فوق VoiceEngine. الجملة الحرجة تقطع القراءة الحالية.
/// التكرار خلال المهلة يُسقط حتى لا يتحول الوصف إلى ضجيج.
library lifex_ai.features.camera_ai.scene.tts_announcer;

import '../../voice/voice_engine.dart';

enum AnnouncePriority { normal, important, critical }

class TtsAnnouncer {
  TtsAnnouncer({
    required this.voiceEngine,
    this.cooldownPerPhraseSeconds = 8,
    this.minIntervalMs = 2500,
  });

  final VoiceEngine voiceEngine;
  final int cooldownPerPhraseSeconds;
  final int minIntervalMs;

  final Map<String, DateTime> _lastSpokenAt = {};
  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isDuplicate(String phrase) {
    final last = _lastSpokenAt[phrase];
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < cooldownPerPhraseSeconds;
  }

  Future<void> announce(
    String phrase, {
    AnnouncePriority priority = AnnouncePriority.normal,
  }) async {
    final critical = priority == AnnouncePriority.critical;
    if (!critical && _isDuplicate(phrase)) return;
    final now = DateTime.now();
    if (!critical &&
        now.difference(_lastSpeakTime).inMilliseconds < minIntervalMs) {
      return;
    }
    if (!critical &&
        priority == AnnouncePriority.normal &&
        voiceEngine.state == VoiceEngineState.speaking) {
      return;
    }
    if (critical) {
      await voiceEngine.interruptIfSpeaking();
    }
    _lastSpokenAt[phrase] = now;
    _lastSpeakTime = now;
    await voiceEngine.speak(phrase);
  }

  Future<void> alertCritical(String phrase) =>
      announce(phrase, priority: AnnouncePriority.critical);
}
