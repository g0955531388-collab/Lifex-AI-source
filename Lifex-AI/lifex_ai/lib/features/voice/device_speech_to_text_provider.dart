/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: device_speech_to_text_provider.dart
/// استماع وتسجيل حقيقي عبر محرّك الجهاز. بلا نتيجة وهمية.
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

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SpeechRecognitionResult> listenOnce({String localeCode = 'ar'}) async {
    final completer = Completer<SpeechRecognitionResult>();
    var lastWords = '';
    var lastConfidence = 0.0;

    try {
      final ready = await _speech.initialize(
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(_fromWords(lastWords, lastConfidence));
          }
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              !completer.isCompleted) {
            completer.complete(_fromWords(lastWords, lastConfidence));
          }
        },
      );
      if (!ready) {
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
          lastWords = result.recognizedWords;
          lastConfidence = result.confidence;
          VoiceEngine.instance.reportPartial(lastWords);
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(_fromWords(lastWords, lastConfidence));
          }
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 47),
        onTimeout: () {
          unawaited(_speech.stop());
          return _fromWords(lastWords, lastConfidence);
        },
      );
    } on MissingPluginException {
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
      );
    } catch (_) {
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
      );
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
  Future<void> stop() => _speech.stop();
}
