import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_assist_gate.dart';
import 'package:lifex_ai/features/accessibility/blind_camera_speech.dart';
import 'package:lifex_ai/features/voice/first_run_voice.dart';

void main() {
  test('كل قسم ينطق أولاً واللمسة الثانية على نفس المكان تفتح', () {
    final gate = BlindAssistGate();
    expect(gate.press(BlindRailZone.assistant), BlindAssistStep.ask);
    expect(gate.hear('لاحقاً'), BlindAssistStep.ignore);
    expect(gate.armedZone, BlindRailZone.assistant);
    expect(gate.hear('نعم'), BlindAssistStep.open);
    expect(gate.armed, isFalse);

    expect(gate.press(BlindRailZone.front), BlindAssistStep.ask);
    expect(gate.press(BlindRailZone.assistant), BlindAssistStep.ask);
    expect(gate.armedZone, BlindRailZone.assistant);
    expect(gate.press(BlindRailZone.assistant), BlindAssistStep.open);

    expect(gate.press(BlindRailZone.front), BlindAssistStep.ask);
    expect(gate.press(BlindRailZone.front), BlindAssistStep.open);
    expect(
      BlindAssistGate.assistantAskAr,
      'لتشغيل المساعد البصري اضغط نفس المكان',
    );
    expect(
      BlindAssistGate.frontAskAr,
      'لتشغيل الكاميرا الامامية اضغط نفس المكان',
    );
    expect(
      BlindCameraSpeech.lensOpen('ar', live: true),
      BlindAssistGate.openedAr,
    );
  });

  test('الإعداد الصوتي ينتظر إذن الميكروفون ولا يتكرر', () {
    expect(
      FirstRunVoice.shouldOffer(
        alreadyOffered: false,
        microphoneGranted: false,
      ),
      isFalse,
    );
    expect(
      FirstRunVoice.shouldOffer(
        alreadyOffered: false,
        microphoneGranted: true,
      ),
      isTrue,
    );
    expect(
      FirstRunVoice.shouldOffer(
        alreadyOffered: true,
        microphoneGranted: true,
      ),
      isFalse,
    );
    expect(FirstRunVoice.introAr, contains('شاشة القفل'));
  });
}
