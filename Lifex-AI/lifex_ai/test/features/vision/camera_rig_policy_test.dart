import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/network_canon.dart';
import 'package:lifex_ai/features/vision/camera_rig_policy.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  const rig = CameraRigPolicy();

  test('×200 و20 ثانية ليستا عتاداً', () {
    final planned = rig.plan(
      advertisedZoom: 200,
      advertisedExposureSeconds: 20,
      advertisedShutter: 1,
      advertisedFlashPercent: 50,
      advertisedBrightness: 1.4,
      advertisedContrast: 1.2,
      minZoom: 1,
      maxZoom: 8,
      minExposureOffset: -2,
      maxExposureOffset: 2,
      torchAvailable: true,
      exposureAvailable: true,
    );
    expect(planned.zoom, 8);
    expect(planned.exposureOffset, 2);
    expect(planned.torchOn, isTrue);
    expect(rig.cssZoomIsOptical, isFalse);
    expect(rig.advertisedSecondsAreShutter, isFalse);
    expect(rig.flashPercentIsTorchCurrent, isFalse);
    expect(rig.previewFilterChangesSensor, isFalse);
    expect(rig.ppmIsCameraRaw, isFalse);
    expect(planned.messageAr, contains('معاينة'));
    expect(planned.messageAr, isNot(contains('أمتار')));
    expect(rig.refuseCssZoomAr(8), contains('8.0'));
    expect(rig.exportHonestyAr(), contains('ليس RAW'));
    expect(rig.mapsMasterToFlashHz, isFalse);
    expect(
      rig.mapMaster(
        target: StudioMasterTarget.zoom,
        master: 100,
        minZoom: 1,
        maxZoom: 8,
      ),
      8,
    );
    expect(
      rig.mapMaster(
        target: StudioMasterTarget.flash,
        master: 50,
        minZoom: 1,
        maxZoom: 8,
      ),
      50,
    );
    expect(
      rig.mapMaster(
        target: StudioMasterTarget.timer,
        master: 100,
        minZoom: 1,
        maxZoom: 8,
      ),
      15,
    );
    expect(rig.overlayAlphaHonestyAr(), contains('ليست تجسيماً'));
    expect(rig.stampMarkAr(), 'Lifex-AI system');
  });

  test('المؤقت يُحصر وقصّ الشريحة الصغيرة يُرفض', () {
    expect(rig.clampTimerSeconds(40), 15);
    expect(rig.clampTimerSeconds(-3), 0);
    expect(
      CameraRigPolicy.normalizeCrop(left: 0.1, top: 0.1, width: 0.01, height: 0.4),
      isNull,
    );
    final board = StudioSliceBoard();
    expect(
      board.addCrop(left: 0.1, top: 0.1, width: 0.4, height: 0.3),
      isNotNull,
    );
    board.addCamera(path: 'a.jpg', zoom: 4);
    expect(board.remove(board.tiles.first.id), isFalse);
  });

  test('الصوت وصفحات HTML تُطوى إلى استوديو الشرائح', () {
    final parser = CommandParser();
    expect(
      parser.parse('افتح التحكم بالكاميرا').intent,
      VoiceCommandIntent.openLayeredLens,
    );
    expect(parser.parse('x200').intent, VoiceCommandIntent.openLayeredLens);
    expect(
      parser.parse('افتح الكاميرا').intent,
      VoiceCommandIntent.openLiveSight,
    );
    expect(NetworkCanon.match('الزوم الكبير')?.unitId, 'radiology');
    expect(NetworkCanon.seatForInboxFile('x200.html'), 'radiology');
    expect(NetworkCanon.seatForInboxFile('camera-control.html'), 'radiology');
  });
}
