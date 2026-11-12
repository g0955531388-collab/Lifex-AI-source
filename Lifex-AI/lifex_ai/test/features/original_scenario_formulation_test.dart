import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/assistive_vision_engine.dart';
import 'package:lifex_ai/features/accessibility/live_sight_conductor.dart';
import 'package:lifex_ai/features/device_guardian/device_presence_note.dart';
import 'package:lifex_ai/features/device_guardian/watch_bond_ledger.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/wake_word_detector.dart';

void main() {
  test('طي التشكيل لا يضيّع نداء ليفكس', () {
    final cue = WakeWordDetector();
    expect(cue.containsWakeWord('يَا لِيفكْس افتح الصيدلية'), isTrue);
    expect(cue.strip('ليفكس، أين أقرب طبيب؟'), 'أين أقرب طبيب؟');
    expect(cue.strip('Lifex, open pharmacy'), 'open pharmacy');
  });

  test('البث الحي لا يخترع مشهداً إن غاب المحرك', () {
    final conductor = LiveSightConductor();
    final first = conductor.pulse(
      cameraReady: true,
      userConsentedOnThisScreen: true,
      frameBytes: [1, 2, 3],
      vision: AssistiveVisionResult.failure('هذه الميزة غير متاحة حالياً.'),
    );
    expect(first.speakNow, isTrue);
    expect(first.engineReady, isFalse);
    expect(first.spokenAr, contains('لن أخترع'));
    final second = conductor.pulse(
      cameraReady: true,
      userConsentedOnThisScreen: true,
      frameBytes: [1, 2, 3],
      vision: AssistiveVisionResult.failure('هذه الميزة غير متاحة حالياً.'),
    );
    expect(second.speakNow, isFalse);
  });

  test('البث يرفض العمل قبل الموافقة الظاهرة', () {
    final pulse = LiveSightConductor().pulse(
      cameraReady: true,
      userConsentedOnThisScreen: false,
      frameBytes: [9],
    );
    expect(pulse.spokenAr, contains('موافقتك'));
  });

  test('ربط البث الحي يحتاج الطرفين ولا يدّعي قناة', () {
    final ledger = WatchBondLedger([]);
    final pending = ledger.propose(
      counterpartProfileId: 'watcher',
      grade: WatchBondGrade.liveWatch,
      counterpartStandingHere: false,
    );
    expect(pending.bothSidesAgreed, isFalse);
    expect(pending.honestyAr(), contains('ناقص'));
    final ready = ledger.propose(
      counterpartProfileId: 'watcher',
      grade: WatchBondGrade.liveWatch,
      counterpartStandingHere: true,
    );
    expect(ready.bothSidesAgreed, isTrue);
    expect(ready.honestyAr(), contains('قناة شبكة'));
  });

  test('حضور الجهاز بلا نقطة GPS مختلقة', () {
    final text = const DevicePresenceNote().describe(
      lastLocalHeartbeat: DateTime(2026, 9, 16, 21),
      lostReported: true,
      locationReaderBound: false,
    );
    expect(text, contains('2026-09-16'));
    expect(text, isNot(contains('خط عرض')));
    expect(text, contains('لن أرسم خريطة'));
  });

  test('الأمر الصوتي يفتح البث الحي لا لقطة الأرشيف', () {
    final parser = CommandParser();
    expect(
      parser.parse('ليفكس ما الموجود أمامي').intent,
      VoiceCommandIntent.openLiveSight,
    );
    expect(
      parser.parse('افتح الكاميرا الحية').intent,
      VoiceCommandIntent.openLiveSight,
    );
    expect(parser.parse('لايف').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('live').intent, VoiceCommandIntent.openLiveSight);
  });
}
