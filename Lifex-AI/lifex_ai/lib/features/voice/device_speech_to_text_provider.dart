/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: device_speech_to_text_provider.dart
/// استماع متكرر عبر جلسة تعرّف واحدة مُهيّأة، بلا نتائج وهمية.
/// =============================================================
library lifex_ai.features.voice.device_speech_to_text_provider;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_to_text_processor.dart';
import 'voice_engine.dart';
import 'voice_locale_policy.dart';

class DeviceSpeechToTextProvider implements SpeechToTextProvider {
  DeviceSpeechToTextProvider({
    SpeechToText? speech,
    VoiceLocalePolicy localePolicy = const VoiceLocalePolicy(),
  })  : _speech = speech ?? SpeechToText(),
        _localePolicy = localePolicy;

  final SpeechToText _speech;
  final VoiceLocalePolicy _localePolicy;

  bool _initialized = false;
  Future<bool>? _initializing;
  Completer<SpeechRecognitionResult>? _activeSession;
  String _lastWords = '';
  double _lastConfidence = 0.0;

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    final pending = _initializing;
    if (pending != null) return pending;

    final initialization = _speech.initialize(
      onError: (_) => unawaited(_stopAndFinishActiveSession()),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _finishActiveSession();
        }
      },
    );
    _initializing = initialization;
    try {
      final ready = await initialization;
      _initialized = ready;
      return ready;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _stopAndFinishActiveSession() async {
    try {
      await _speech.stop();
    } finally {
      _finishActiveSession();
    }
  }

  void _finishActiveSession() {
    final session = _activeSession;
    if (session == null) return;
    _activeSession = null;
    if (!session.isCompleted) {
      session.complete(_fromWords(_lastWords, _lastConfidence));
    }
  }

  @override
  Future<SpeechRecognitionResult> listenOnce({String localeCode = 'ar'}) async {
    if (_activeSession != null) {
      await stop();
    }

    final completer = Completer<SpeechRecognitionResult>();
    _activeSession = completer;
    _lastWords = '';
    _lastConfidence = 0.0;

    try {
      final ready = await _ensureInitialized();
      if (!ready) {
        if (identical(_activeSession, completer)) _activeSession = null;
        return const SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
        );
      }

      final available = await _speech.locales();
      final localeId = _localePolicy.matchAvailable(
        preferred: localeCode,
        available: available.map((item) => item.localeId).toList(),
      );
      VoiceEngine.instance.activeLocaleId = localeId;
      VoiceEngine.instance.signalAr('أستمع وأسجّل الآن — $localeId');

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _lastConfidence = result.confidence;
          VoiceEngine.instance.reportPartial(_lastWords);
          // Wait for the recognizer's done/notListening status before allowing
          // another session, so a late status from this session cannot close
          // the next one.
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 47),
        onTimeout: () async {
          await _speech.stop();
          final result = _fromWords(_lastWords, _lastConfidence);
          _finishActiveSession();
          return result;
        },
      );
    } on MissingPluginException {
      if (identical(_activeSession, completer)) _activeSession = null;
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
      );
    } catch (_) {
      if (identical(_activeSession, completer)) _activeSession = null;
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
      );
    } finally {
      if (identical(_activeSession, completer)) _activeSession = null;
    }
  }

  SpeechRecognitionResult _fromWords(String words, double confidence) {
    final trimmed = words.trim();
    if (trimmed.isEmpty) {
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.noSpeechDetected,
      );
    }
    return SpeechRecognitionResult(
      status: SpeechRecognitionStatus.success,
      recognizedText: trimmed,
      confidence: confidence,
    );
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _finishActiveSession();
  }
}
