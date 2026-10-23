// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: voice_pipeline_test.dart
// =============================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/voice/device_speech_to_text_provider.dart';
import 'package:lifex_ai/features/voice/device_text_to_speech_provider.dart';
import 'package:lifex_ai/features/voice/speech_to_text_processor.dart';
import 'package:lifex_ai/features/voice/text_to_speech_manager.dart';
import 'package:lifex_ai/features/voice/voice_engine.dart';
import 'package:lifex_ai/features/voice/voice_locale_policy.dart';
import 'package:lifex_ai/features/voice/wake_word_detector.dart';

class _FakeSpeech implements SpeechToTextProvider {
  _FakeSpeech(this.result);
  final SpeechRecognitionResult result;
  String? lastLocale;

  @override
  Future<SpeechRecognitionResult> listenOnce({String localeCode = 'ar'}) async {
    lastLocale = localeCode;
    return result;
  }

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<void> stop() async {}
}

class _HoldTts implements TextToSpeechProvider {
  int stops = 0;
  Completer<void>? hold;

  @override
  String? get lastBlockAr => null;

  @override
  Future<bool> get isLanguageSupported async => true;

  @override
  Future<bool> speak(String text, SpeechSettings settings) async {
    hold = Completer<void>();
    await hold!.future;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    final pending = hold;
    if (stops > 1 && pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }
}

class _NoArabicTts implements TextToSpeechProvider {
  @override
  String? get lastBlockAr =>
      'بيانات النطق العربي غير مثبتة على هذا الجهاز. النص ظاهر على الشاشة، ولم أختلق سماعاً.';

  @override
  Future<bool> get isLanguageSupported async => true;

  @override
  Future<bool> speak(String text, SpeechSettings settings) async => false;

  @override
  Future<void> stop() async {}
}

class _FakeTts implements TextToSpeechProvider {
  String? lastLocale;
  String? lastText;

  @override
  String? get lastBlockAr => null;

  @override
  Future<bool> get isLanguageSupported async => true;

  @override
  Future<bool> speak(String text, SpeechSettings settings) async {
    lastText = text;
    lastLocale = settings.localeCode;
    return true;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  test('نجاح النطق يُقبل من الرقم 1', () {
    expect(ttsCallSpoke(1), isTrue);
    expect(ttsCallSpoke('1'), isTrue);
    expect(ttsCallSpoke(0), isFalse);
    expect(ttsCallSpoke(null), isFalse);
  });

  test('يطابق أقرب لغة متاحة على الجهاز', () {
    const policy = VoiceLocalePolicy();
    expect(
      policy.matchAvailable(
        preferred: 'ar_SY',
        available: ['ar_SA', 'en_US'],
      ),
      'ar_SA',
    );
    expect(
      policy.matchAvailable(
        preferred: 'fr_FR',
        available: ['en_GB', 'fr_CA'],
      ),
      'fr_CA',
    );
  });

  test('نطق النص العربي يفضّل ar إن وُجد', () {
    const policy = VoiceLocalePolicy();
    expect(
      policy.speakCodeForText(
        text: 'افتح ملفي الصحي',
        availableTts: ['en-US', 'ar-SA'],
      ),
      'ar-SA',
    );
  });

  test('الاستماع المربوط يعيد النص ولا يصمت', () async {
    final engine = VoiceEngine.instance;
    final speech = _FakeSpeech(
      const SpeechRecognitionResult(
        status: SpeechRecognitionStatus.success,
        recognizedText: 'افتح الصيدلية',
      ),
    );
    SpeechToTextProcessor(provider: speech).registerWithVoiceEngine(engine);
    TextToSpeechManager(provider: _FakeTts()).registerWithVoiceEngine(engine);

    final heard = await engine.startListening();
    expect(heard.success, isTrue);
    expect(heard.textResult, 'افتح الصيدلية');

    final spoken = await engine.speak('سمعتك');
    expect(spoken.success, isTrue);
  });

  test('إيقاف القراءة يقطع النطق الجاري', () async {
    final engine = VoiceEngine.instance;
    final tts = _HoldTts();
    TextToSpeechManager(provider: tts).registerWithVoiceEngine(engine);
    final pending = engine.speak('نص طويل يُقرأ الآن');
    await Future<void>.delayed(Duration.zero);
    expect(engine.state, VoiceEngineState.speaking);
    final epoch = engine.speechEpoch;
    await engine.stopSpeaking();
    final result = await pending;
    expect(result.success, isTrue);
    expect(engine.speechEpoch, epoch + 1);
    expect(engine.state, VoiceEngineState.idle);
    expect(engine.lastSignalAr, 'أوقفت القراءة.');
  });

  test('النطق العربي لا يثبت أن التعرف العربي مثبت', () {
    const policy = VoiceLocalePolicy();
    expect(
      policy.speakCodeForText(
        text: 'افتح العدسة',
        availableTts: ['en-US', 'ar-SA'],
      ),
      'ar-SA',
    );
    final choice = policy.chooseRecognition(
      preferred: 'ar',
      available: ['en_US'],
    );
    expect(choice.accepted, isFalse);
    expect(choice.refusalAr, contains('التعرف'));
    expect(choice.refusalAr, contains('النطق'));
    final ready = policy.chooseRecognition(
      preferred: 'ar',
      available: ['en_US', 'ar_SA'],
    );
    expect(ready.accepted, isTrue);
    expect(ready.localeId, 'ar_SA');
  });

  test('كلمة التنبيه ليست استماعاً دائماً', () {
    const limit = WakeListenLimit();
    expect(limit.continuousWhileScreenOff, isFalse);
    expect(limit.requirementAr, contains('غير مفعّلة'));
  });

  test('كلمة التنبيه تُلتقط وتُزال', () {
    final detector = WakeWordDetector();
    expect(detector.containsWakeWord('ليفكس، أين أقرب طبيب؟'), isTrue);
    expect(detector.strip('ليفكس، أين أقرب طبيب؟'), 'أين أقرب طبيب؟');
    expect(detector.strip('Lifex, open pharmacy'), 'open pharmacy');
  });

  test('جلسة استماع ثانية تُرفض ما دامت الأولى جارية', () async {
    final engine = VoiceEngine.instance;
    final gate = Completer<VoiceOperationResult>();
    engine.bindStopSpeakingImplementation(() async {});
    engine.bindListeningImplementation(() => gate.future);
    final first = engine.startListening();
    final second = await engine.startListening();
    expect(second.success, isFalse);
    expect(second.errorMessageAr, contains('لم تنته'));
    gate.complete(const VoiceOperationResult.success(textResult: 'مرحبا'));
    expect((await first).textResult, 'مرحبا');
  });

  test('بعد إيقاف الجلسة تبدأ جلسة استماع جديدة', () async {
    final engine = VoiceEngine.instance;
    var calls = 0;
    final firstGate = Completer<VoiceOperationResult>();
    engine.bindStopSpeakingImplementation(() async {});
    engine.bindStopListeningImplementation(() async {
      if (!firstGate.isCompleted) {
        firstGate.complete(const VoiceOperationResult.failure('أوقفت الاستماع'));
      }
    });
    engine.bindListeningImplementation(() {
      calls += 1;
      if (calls == 1) return firstGate.future;
      return Future.value(
        const VoiceOperationResult.success(textResult: 'الثانية'),
      );
    });
    final first = engine.startListening();
    await Future<void>.delayed(Duration.zero);
    await engine.stopListening();
    final second = await engine.startListening();
    expect(second.success, isTrue);
    expect(second.textResult, 'الثانية');
    expect((await first).errorMessageAr, contains('أوقفت'));
  });

  test('غياب صوت العربية يُعاد كنص واضح ولا يُعد سماعاً', () async {
    final engine = VoiceEngine.instance;
    TextToSpeechManager(provider: _NoArabicTts()).registerWithVoiceEngine(engine);
    final spoken = await engine.speak('أمامك وصف');
    expect(spoken.success, isFalse);
    expect(spoken.errorMessageAr, contains('النطق العربي'));
    expect(spoken.errorMessageAr, contains('لم أختلق سماعاً'));
  });

  test('انشغال جلسة التعرف يُعرف من نص الخطأ', () {
    expect(speechSessionBusy(Exception('error_busy')), isTrue);
    expect(speechSessionBusy(Exception('previous session active')), isTrue);
    expect(speechSessionBusy(Exception('permission denied')), isFalse);
  });
}
