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
  SpeechErrorListener? _onError;
  SpeechStatusListener? _onStatus;
  List<String>? _localeIds;

  /// صمت أقصر بعد آخر كلمة. أربع ثوانٍ كانت تُبقي الأمر معلّقاً.
  static const commandPause = Duration(milliseconds: 1500);

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
    var closing = false;

    void finish(SpeechRecognitionResult result) {
      if (ticket != _ticket || closing) return;
      closing = true;
      grace?.cancel();
      if (identical(_latch, latch)) _latch = null;
      latch.finish(result);
      if (_speech.isListening) {
        unawaited(() async {
          try {
            await _speech.stop();
          } catch (_) {}
        }());
      }
    }

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      _onError = (_) {
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
      };
      _onStatus = (status) {
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
      };
      final ready = await _ensureEngine();
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

      final available = await _knownLocales();
      final choice = _localePolicy.chooseRecognition(
        preferred: localeCode,
        available: available,
      );
      if (choice.refusalAr != null) {
        return SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: choice.refusalAr,
        );
      }
      final localeId = choice.localeId ?? localeCode;
      if (!available.contains(localeId) && available.isNotEmpty) {
        return SpeechRecognitionResult(
          status: SpeechRecognitionStatus.error,
          messageAr: 'اللغة $localeCode غير مثبتة في محرك التعرف.',
        );
      }
      VoiceEngine.instance.activeLocaleId = localeId;

      Future<void> startCapture() {
        return _speech.listen(
          localeId: localeId,
          listenFor: const Duration(seconds: 20),
          pauseFor: commandPause,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: ListenMode.confirmation,
            pauseFor: commandPause,
            listenFor: const Duration(seconds: 20),
            localeId: localeId,
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
            if (gate.sawFinal) {
              finish(_fromWords(gate.words, result.confidence));
            }
          },
        );
      }

      try {
        await startCapture();
      } catch (error) {
        if (!speechSessionBusy(error) || ticket != _ticket) rethrow;
        try {
          await _speech.cancel();
        } catch (_) {
          try {
            await _speech.stop();
          } catch (_) {}
        }
        await startCapture();
      }
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

  Future<bool> _ensureEngine() async {
    if (!_speech.isAvailable) {
      final ready = await _speech.initialize(
        onError: (error) => _onError?.call(error),
        onStatus: (status) => _onStatus?.call(status),
      );
      if (!ready) return false;
    }
    _speech.errorListener = (error) => _onError?.call(error);
    _speech.statusListener = (status) => _onStatus?.call(status);
    return true;
  }

  Future<List<String>> _knownLocales() async {
    final cached = _localeIds;
    if (cached != null && cached.isNotEmpty) return cached;
    final available = await _speech.locales();
    final ids = available.map((item) => item.localeId).toList();
    if (ids.isNotEmpty) _localeIds = ids;
    return ids;
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

bool speechSessionBusy(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('busy') ||
      text.contains('error_busy') ||
      text.contains('already started') ||
      text.contains('already listening') ||
      text.contains('previous session');
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
