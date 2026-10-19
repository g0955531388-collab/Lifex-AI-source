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

import 'assistant_permission_desk.dart';
import 'speech_capture_gate.dart';
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
  int _ticket = 0;
  SpeechListenLatch? _latch;

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      return const AssistantPermissionDesk().ensure(
        read: () async {
          final status = await Permission.microphone.status;
          return AssistantPermissionDesk.classify(
            granted: status.isGranted,
            blocked: status.isPermanentlyDenied || status.isRestricted,
          );
        },
        request: () async {
          final status = await Permission.microphone.request();
          return AssistantPermissionDesk.classify(
            granted: status.isGranted,
            blocked: status.isPermanentlyDenied || status.isRestricted,
          );
        },
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SpeechRecognitionResult> listenOnce({String localeCode = 'ar'}) async {
    final ticket = ++_ticket;
    final gate = SpeechCaptureGate();
    final latch = SpeechListenLatch(gate);
    _latch = latch;
    Timer? grace;

    void finish(SpeechRecognitionResult result) {
      if (ticket != _ticket) return;
      grace?.cancel();
      if (identical(_latch, latch)) _latch = null;
      latch.finish(result);
    }

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      final ready = await _speech.initialize(
        onError: (_) {
          gate.sawError = true;
          grace?.cancel();
          if (gate.words.trim().isNotEmpty) {
            finish(_fromWords(gate.words, 0));
            return;
          }
          finish(const SpeechRecognitionResult(
            status: SpeechRecognitionStatus.error,
            messageAr:
                'تعطل محرك التعرف أثناء الجلسة. النص لم يُفقد إن كان ظاهراً، ويمكنك الكتابة.',
          ));
        },
        onStatus: (status) {
          if (ticket != _ticket) return;
          gate.onStatus(status);
          if (gate.shouldCloseNow(status)) {
            finish(_fromWords(gate.words, 0));
            return;
          }
          if (gate.waitForLateWords &&
              (status == 'done' || status == 'notListening') &&
              grace == null) {
            grace = Timer(const Duration(milliseconds: 900), () {
              if (gate.words.trim().isNotEmpty) {
                finish(_fromWords(gate.words, 0));
              } else {
                finish(const SpeechRecognitionResult(
                  status: SpeechRecognitionStatus.noSpeechDetected,
                  messageAr:
                      'انتهت مهلة الجلسة دون نص. هذا ليس دليلاً على أن الميكروفون مغلق.',
                ));
              }
            });
          }
        },
      );
      if (ticket != _ticket) {
        return const SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: 'أُلغيت الجلسة قبل أن تبدأ.',
        );
      }
      if (!ready) {
        return const SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr:
              'خدمة التعرف على الكلام غير متاحة على هذا الجهاز. يمكنك الكتابة.',
        );
      }

      final available = await _speech.locales();
      final choice = _localePolicy.chooseRecognition(
        preferred: localeCode,
        available: available.map((item) => item.localeId).toList(),
      );
      if (choice.refusalAr != null) {
        return SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: choice.refusalAr,
        );
      }
      final localeId = choice.localeId ?? localeCode;
      if (!available.any((item) => item.localeId == localeId) &&
          available.isNotEmpty) {
        return SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: 'اللغة $localeCode غير مثبتة في محرك التعرف.',
        );
      }
      VoiceEngine.instance.activeLocaleId = localeId;

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (ticket != _ticket) return;
          gate.onWords(
            result.recognizedWords,
            isFinal: result.finalResult,
          );
          if (gate.words.isNotEmpty) {
            VoiceEngine.instance.reportPartial(gate.words);
          }
          if (gate.sawFinal) finish(_fromWords(gate.words, result.confidence));
        },
      );
      if (ticket != _ticket) {
        return const SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: 'أُلغيت الجلسة.',
        );
      }
      VoiceEngine.instance.noteCaptureStarted();

      return latch.completer.future.timeout(
        const Duration(seconds: 22),
        onTimeout: () {
          unawaited(_speech.stop());
          if (gate.words.trim().isNotEmpty) return _fromWords(gate.words, 0);
          return const SpeechRecognitionResult(
            status: SpeechRecognitionStatus.noSpeechDetected,
            messageAr: 'انتهت مهلة الاستماع دون نص نهائي.',
          );
        },
      );
    } on MissingPluginException {
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
        messageAr: 'إضافة التعرف غير مربوطة في هذا البناء.',
      );
    } catch (_) {
      return const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.error,
        messageAr: 'تعذر فتح جلسة التعرف. يمكنك الكتابة.',
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
  Future<void> stop() async {
    _ticket++;
    final latch = _latch;
    _latch = null;
    latch?.finishStopped();
    try {
      await _speech.stop();
    } catch (_) {}
  }
}

/// جلسة تعرّف واحدة. الإيقاف يُغلقها فوراً بالنص الذي وصل، أو برفض صريح إن لم يصل نص.
class SpeechListenLatch {
  SpeechListenLatch(this.gate);

  final SpeechCaptureGate gate;
  final Completer<SpeechRecognitionResult> completer =
      Completer<SpeechRecognitionResult>();

  void finish(SpeechRecognitionResult result) {
    if (completer.isCompleted) return;
    completer.complete(result);
  }

  void finishStopped() {
    final trimmed = gate.words.trim();
    if (trimmed.isNotEmpty) {
      finish(SpeechRecognitionResult(
        status: SpeechRecognitionStatus.success,
        recognizedText: trimmed,
        confidence: 0,
      ));
      return;
    }
    finish(const SpeechRecognitionResult(
      status: SpeechRecognitionStatus.noSpeechDetected,
      messageAr: 'أوقفت الاستماع قبل وصول نص.',
    ));
  }
}
