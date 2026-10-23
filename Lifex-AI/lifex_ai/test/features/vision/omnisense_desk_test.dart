import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_scene_brief.dart';
import 'package:lifex_ai/features/accessibility/live_vision_provider.dart';
import 'package:lifex_ai/features/vision/camera_rig_policy.dart';
import 'package:lifex_ai/features/vision/omnisense_desk.dart';
import 'package:lifex_ai/features/vision/optical_radar_engine.dart';

void main() {
  test('غياب حسّاس العمق ينتج Unknown ولا يعلن أمتاراً', () {
    final reading = OmniSenseDesk.depth(
      meters: 1.5,
      hardwareSensorAvailable: false,
    );
    expect(reading.state, PhysicalReadingState.unknown);
    expect(reading.value, isNull);
    expect(reading.announcedAsMeasurement, isFalse);
    expect(reading.spokenAr, contains('Unknown'));
    expect(reading.spokenAr.contains('1.5'), isFalse);
    expect(reading.spokenAr.contains('متر'), isFalse);

    final math = OpticalDistanceEngine.measureDistance(
      roundTripTimeSeconds:
          OpticalDistanceEngine.expectedRoundTripTimeSeconds(1),
    );
    final fromMath = OmniSenseDesk.depth(
      meters: math?.distanceMeters,
      hardwareSensorAvailable: false,
    );
    expect(fromMath.state, PhysicalReadingState.unknown);
    expect(fromMath.spokenAr.contains('1'), isFalse);
  });

  test('غياب مصدر الكتلة يمنع إعلان كتلة أو كثافة مقاسة', () {
    final reading = OmniSenseDesk.mass(
      kilograms: 70,
      scaleAvailable: false,
    );
    expect(reading.state, PhysicalReadingState.unknown);
    expect(reading.value, isNull);
    expect(reading.spokenAr, contains('Unknown'));
    expect(reading.spokenAr.contains('70'), isFalse);
    expect(reading.spokenAr, contains('لا ميزان'));
    expect(reading.spokenAr, contains('لا'));
    expect(reading.spokenAr.contains('كثافة نسيج'), isFalse);
  });

  test('اللون الأحمر والتباين لا ينتجان تشخيصاً سريرياً', () {
    final note = OmniSenseDesk.appearance(redRatio: 0.92, contrast: 40);
    expect(note.clinicalDiagnosis, isNull);
    expect(note.spokenAr, contains('ملاحظة'));
    expect(note.spokenAr, contains('ليست تشخيصاً'));
    expect(note.spokenAr.contains('دم'), isFalse);
    expect(note.spokenAr.contains('جرح'), isFalse);
    expect(note.spokenAr.contains('التهاب'), isFalse);
    expect(note.spokenAr.contains('أشعة'), isFalse);
    expect(note.spokenAr.contains('مرض'), isFalse);
  });

  test('تعطل الشبكة أو غياب المفتاح لا ينتج رداً سحابياً', () {
    const canned = 'تم التحليل بواسطة Gemini. المشهد مستقر.';
    final offline = OmniSenseDesk.link(
      endpointConfigured: true,
      frameLeaveConsent: true,
      online: false,
    );
    expect(offline.phase, OmniSenseLinkPhase.unavailable);
    expect(offline.framesLeaveDevice, isFalse);
    expect(offline.attributedToGemini, isFalse);
    expect(offline.spokenAr.contains(canned), isFalse);
    expect(offline.spokenAr.contains('Gemini'), isFalse);
    expect(offline.spokenAr, contains('لم تُرسل'));

    final missingKey = OmniSenseDesk.link(
      endpointConfigured: false,
      frameLeaveConsent: true,
      online: true,
    );
    expect(missingKey.phase, OmniSenseLinkPhase.unconfigured);
    expect(missingKey.framesLeaveDevice, isFalse);
    expect(missingKey.attributedToGemini, isFalse);
    expect(missingKey.spokenAr.contains('مستقر'), isFalse);
  });

  test('غياب الموافقة يمنع إرسال الإطار', () async {
    final blocked = OmniSenseDesk.link(
      endpointConfigured: true,
      frameLeaveConsent: false,
      online: true,
    );
    expect(blocked.phase, OmniSenseLinkPhase.awaitingConsent);
    expect(blocked.framesLeaveDevice, isFalse);

    final gemini = GeminiLiveVisionProvider(
      ephemeralTokenIssuerConfigured: true,
    );
    final sent = await gemini.sendFrame(Uint8List.fromList([1, 2, 3]));
    expect(sent.phase, LiveVisionPhase.awaitingConsent);
    expect(sent.framesLeaveDevice, isFalse);
    expect(sent.spokenAr, contains('لم يُرسل'));
    expect(sent.spokenAr.contains('مستقر'), isFalse);
  });

  test('الفشل لا ينطق نتيجة إيجابية مختلقة', () async {
    final speech = OmniSenseDesk.failureSpeech();
    expect(speech, BlindSceneBrief.noAnalysisAr);
    expect(speech.contains('مستقر'), isFalse);
    expect(speech.contains('تم التحليل'), isFalse);
    expect(speech.contains('اكتمل'), isFalse);

    final gemini = GeminiLiveVisionProvider();
    gemini.grantFrameLeaveConsent();
    final sent = await gemini.sendFrame(Uint8List.fromList(const [9]));
    expect(sent.framesLeaveDevice, isFalse);
    expect(sent.spokenAr.contains('مستقر'), isFalse);
    expect(sent.spokenAr.contains('تم التحليل'), isFalse);
    expect(sent.spokenAr, contains('لم يُرسل'));

    final probe = OpticalRadarEngine.instance.probe();
    expect(probe.success, isFalse);
    expect(probe.distanceMeters, isNull);
    expect(probe.messageAr.contains('مستقر'), isFalse);
  });

  test('النطق المحلي يستمر عند تعطيل السحابة', () {
    final cloud = OmniSenseDesk.link(
      endpointConfigured: false,
      frameLeaveConsent: false,
      online: false,
    );
    expect(cloud.framesLeaveDevice, isFalse);
    final local = OmniSenseDesk.localWhenCloudOff(const [
      SceneHit('chair', 0.8),
    ]);
    expect(local, contains('كرسي'));
    expect(local, contains('تصنيف'));
    expect(local.contains('متر'), isFalse);
    expect(local.contains('تشخيص'), isFalse);

    final channels = OmniSenseDesk.composeLocalSpeech(
      scene: local,
      recognizedText: 'ROOM 4',
      barcodes: const ['123'],
    );
    expect(channels, contains('كرسي'));
    expect(channels, contains('ROOM 4'));
    expect(channels, contains('الرموز'));
    expect(channels.indexOf('كرسي'), lessThan(channels.indexOf('ROOM 4')));
    expect(channels.indexOf('ROOM 4'), lessThan(channels.indexOf('الرموز')));
  });

  test('فلاش الهاتف لا يُعلن عند 3000 أو 3500 هرتز', () {
    expect(const CameraRigPolicy().mapsMasterToFlashHz, isFalse);
    expect(OmniSenseDesk.phoneFlashHzAvailable(3000), isFalse);
    expect(OmniSenseDesk.phoneFlashHzAvailable(3500), isFalse);
    expect(OmniSenseDesk.flashHzSpokenAr(3500), contains('غير متاح'));
    expect(OmniSenseDesk.flashHzSpokenAr(3000).contains('متاح على فلاش') &&
            !OmniSenseDesk.flashHzSpokenAr(3000).contains('غير متاح'),
        isFalse);
  });
}
