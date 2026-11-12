import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/voice/assistant_session.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/device_speech_to_text_provider.dart';
import 'package:lifex_ai/features/voice/speech_capture_gate.dart';
import 'package:lifex_ai/features/voice/speech_to_text_processor.dart';

void main() {
  test('حالة فارغة بعد الاستماع لا تُغلق الجلسة فوراً', () {
    final gate = SpeechCaptureGate()..onStatus('listening');
    expect(gate.shouldCloseNow('notListening'), isFalse);
    expect(gate.waitForLateWords, isTrue);
  });

  test('الكلمات المتأخرة بعد notListening تُعتمد ولا تُمسح', () {
    final gate = SpeechCaptureGate()..onStatus('listening');
    expect(gate.shouldCloseNow('notListening'), isFalse);
    gate.onWords('', isFinal: false);
    expect(gate.words, isEmpty);
    gate.onWords('افتح الكاميرا', isFinal: true);
    expect(gate.words, 'افتح الكاميرا');
    expect(gate.sawFinal, isTrue);
    expect(gate.shouldCloseNow('done'), isTrue);
  });

  test('نتيجة جزئية ثم نهائية لا تكرر الجملة', () {
    final gate = SpeechCaptureGate()..onStatus('listening');
    gate.onWords('افتح', isFinal: false);
    gate.onWords('افتح الكاميرا', isFinal: true);
    expect(gate.words, 'افتح الكاميرا');
  });

  test('done قبل بدء الاستماع لا يُغلق الجلسة', () {
    final gate = SpeechCaptureGate();
    expect(gate.shouldCloseNow('done'), isFalse);
    expect(gate.shouldCloseNow('notListening'), isFalse);
  });

  test('نتيجة جزئية غير فارغة تُغلق عند انتهاء الجلسة', () {
    final gate = SpeechCaptureGate()..onStatus('listening');
    gate.onWords('مرحبا', isFinal: false);
    expect(gate.shouldCloseNow('done'), isTrue);
    expect(gate.waitForLateWords, isFalse);
  });

  test('رسالة الخطأ الفارغة لا تُعامل كنجاح', () {
    final command = CommandParser().parse('أوقف النطق');
    expect(command.intent, VoiceCommandIntent.stopReading);
    expect(CommandParser().parse('stop speaking').intent,
        VoiceCommandIntent.stopReading);
  });

  test('أوامر العدسة والنص والأطباء والفحص تُفهم', () {
    final parser = CommandParser();
    expect(parser.parse('افتح العدسة').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('اقرأ لي النص').intent, VoiceCommandIntent.readVisibleText);
    expect(parser.parse('افتح الأطباء').intent, VoiceCommandIntent.openDoctors);
    expect(parser.parse('افتح المواعيد').intent, VoiceCommandIntent.openAppointments);
    expect(parser.parse('افتح ملفي الصحي').intent, VoiceCommandIntent.openHealthProfile);
    expect(
      parser.parse('اقرأ لي نتيجة الفحص').intent,
      VoiceCommandIntent.readLastLabResult,
    );
    expect(parser.parse('أوقف القراءة').intent, VoiceCommandIntent.stopReading);
  });

  test('النص الموقوف يُستعاد مرة واحدة ولا يُستبدل بتأكيد الإيقاف', () {
    final session = AssistantSession.instance;
    session.heldReading = null;
    session.holdForResume('نتيجة ظاهرة على الشاشة');
    session.holdForResume('أوقفت القراءة. قل: تابع القراءة.');
    expect(session.takeHeldReading(), 'نتيجة ظاهرة على الشاشة');
    expect(session.takeHeldReading(), isNull);
  });

  test('إيقاف الجلسة بلا نص يُغلق فوراً ولا يُسجَّل نجاحاً', () async {
    final gate = SpeechCaptureGate()..onStatus('listening');
    final latch = SpeechListenLatch(gate);
    latch.finishStopped();
    final result = await latch.completer.future;
    expect(result.status, SpeechRecognitionStatus.noSpeechDetected);
    expect(result.recognizedText, isNull);
    expect(result.messageAr, contains('أوقفت الاستماع'));
  });

  test('إيقاف الجلسة بعد نص جزئي يُبقي النص ولا يختلق جملة', () async {
    final gate = SpeechCaptureGate()..onStatus('listening');
    gate.onWords('افتح الكاميرا', isFinal: false);
    final latch = SpeechListenLatch(gate);
    latch.finishStopped();
    final result = await latch.completer.future;
    expect(result.status, SpeechRecognitionStatus.success);
    expect(result.recognizedText, 'افتح الكاميرا');
  });

  test('رسالة الخطأ الفارغة لا تُعامل كنجاح', () {
    const result = SpeechRecognitionResult(
      status: SpeechRecognitionStatus.noSpeechDetected,
      messageAr: 'انتهت مهلة الجلسة دون نص.',
    );
    expect(result.recognizedText, isNull);
    expect(result.messageAr, contains('مهلة'));
  });
}
