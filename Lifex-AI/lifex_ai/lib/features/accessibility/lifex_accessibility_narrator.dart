/// =============================================================
/// Lifex-AI — راوي إمكانية الوصول + طابور نطق بأولويات
/// الملف: lifex_accessibility_narrator.dart
/// TTS على شاشة واحدة ≠ نظام ناطق. هذا يوحّد: Semantics + Speak + Priority.
/// لا يدّعي استماعاً خلفياً دائماً أو AccessibilityService مفعّلاً دون المستخدم.
/// =============================================================
library lifex_ai.features.accessibility.lifex_accessibility_narrator;

import '../voice/voice_engine.dart';

enum SpeechPriority { emergency, critical, high, normal, low }

enum VoiceAvailabilityState {
  voiceAvailable,
  voiceInitializing,
  listening,
  processing,
  speaking,
  paused,
  stopped,
  error,
  unavailable,
}

class _QueuedUtterance {
  _QueuedUtterance({
    required this.text,
    required this.priority,
    required this.id,
  });

  final String text;
  final SpeechPriority priority;
  final String id;
}

/// راوي مركزي — يستخدم VoiceEngine الموجود، لا ينشئ TTS مكرراً.
class LifexAccessibilityNarrator {
  LifexAccessibilityNarrator({VoiceEngine? engine})
      : _engine = engine ?? VoiceEngine.instance;

  final VoiceEngine _engine;
  final List<_QueuedUtterance> _queue = [];
  bool _draining = false;
  String? _lastSpokenNormalized;
  DateTime? _lastSpokenAt;
  int _seq = 0;

  /// Android AccessibilityService يجب تفعيله من إعدادات النظام — لا يكفي وجود كود.
  bool get claimsSystemAccessibilityServiceEnabled => false;

  /// الاستماع المستمر والشاشة مغلقة مقيّد في Android الحديث.
  bool get claimsAlwaysOnMicWhileScreenOff => false;

  VoiceAvailabilityState mapEngineState(VoiceEngineState s) {
    switch (s) {
      case VoiceEngineState.idle:
        return VoiceAvailabilityState.voiceAvailable;
      case VoiceEngineState.listening:
        return VoiceAvailabilityState.listening;
      case VoiceEngineState.processing:
        return VoiceAvailabilityState.processing;
      case VoiceEngineState.speaking:
        return VoiceAvailabilityState.speaking;
      case VoiceEngineState.error:
        return VoiceAvailabilityState.error;
    }
  }

  /// نطق مع أولوية وخصم تكرار. الطوارئ تقطع العادي.
  Future<void> speak(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final normalized = trimmed.toLowerCase();
    final now = DateTime.now();
    if (_lastSpokenNormalized == normalized &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < const Duration(seconds: 2) &&
        priority.index >= SpeechPriority.high.index) {
      return;
    }

    if (priority == SpeechPriority.emergency ||
        priority == SpeechPriority.critical) {
      _queue.removeWhere((u) => u.priority.index > priority.index);
    }

    _queue.add(
      _QueuedUtterance(
        text: trimmed,
        priority: priority,
        id: 'utt_${++_seq}',
      ),
    );
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    await _drain();
  }

  Future<void> narrateState({
    required String label,
    required String stateAr,
    SpeechPriority priority = SpeechPriority.normal,
  }) {
    return speak('$label. الحالة: $stateAr.', priority: priority);
  }

  Future<void> narrateResult({
    required String actionAr,
    required String resultAr,
    SpeechPriority priority = SpeechPriority.high,
  }) {
    return speak('$actionAr. النتيجة: $resultAr.', priority: priority);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        _lastSpokenNormalized = next.text.toLowerCase();
        _lastSpokenAt = DateTime.now();
        await _engine.speak(next.text);
      }
    } finally {
      _draining = false;
    }
  }
}
