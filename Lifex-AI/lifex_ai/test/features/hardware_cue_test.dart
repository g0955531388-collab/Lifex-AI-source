import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/hardware_cue_calibrator.dart';
import 'package:lifex_ai/features/voice/start_listen_signal.dart';
import 'package:lifex_ai/features/vision/optical_zoom_policy.dart';

void main() {
  test('ضغطتان متتاليتان داخل النافذة تشعلان الإشارة', () {
    final window = HardwareTapWindow(
      needed: 2,
      window: const Duration(milliseconds: 480),
    );
    final t0 = DateTime(2026, 9, 16, 22, 17);
    expect(window.register(t0, matchingKind: true), isFalse);
    expect(
      window.register(
        t0.add(const Duration(milliseconds: 200)),
        matchingKind: true,
      ),
      isTrue,
    );
  });

  test('ضغطة متأخرة أو زر مختلف لا تختلق نجاحاً', () {
    final window = HardwareTapWindow(
      needed: 2,
      window: const Duration(milliseconds: 480),
    );
    final t0 = DateTime(2026, 9, 16, 22, 17);
    expect(window.register(t0, matchingKind: true), isFalse);
    expect(
      window.register(
        t0.add(const Duration(milliseconds: 900)),
        matchingKind: true,
      ),
      isFalse,
    );
    expect(window.register(t0, matchingKind: false), isFalse);
  });

  test('أربع ضغطات على رفع الصوت لا تُنسب إلى إشعار الخلفية', () {
    final calibrator = HardwareCueCalibrator()
      ..kind = HardwareCueKind.volumeUpDouble
      ..tapCount = 4;
    final text = calibrator.honestyAr();
    expect(text, contains('4'));
    expect(text, contains('في الأمام'));
    expect(text, contains('لا يلتقط زر الصوت'));
    expect(text, isNot(contains('أو بإشعار المراقبة')));
  });

  test('زر الطاقة يبقى ملك النظام بلا Device Admin', () {
    final calibrator = HardwareCueCalibrator()
      ..kind = HardwareCueKind.powerDouble;
    expect(calibrator.powerButtonIsSystemOwned, isTrue);
    expect(calibrator.honestyAr(), contains('بلا Device Admin'));
  });

  test('إشارة البدء نطق عربي صادق', () {
    expect(const StartListenSignal().spokenCue(arabic: true), contains('أسمعك'));
  });

  test('النص المكتوب يُفهم بنفس محلل الصوت', () {
    final parser = CommandParser();
    expect(
      parser.parse('ملفي الصحي').intent,
      parser.parse('ليفكس ملفي الصحي').intent,
    );
    expect(parser.parse('بنك الدم').intent, VoiceCommandIntent.openNetworkUnit);
    expect(
      parser.parse('بنك الدم').parameters['unitId'],
      parser.parse('ليفكس افتح بنك الدم').parameters['unitId'],
    );
  });

  test('التكبير الجلدي لا يتجاوز سقف العدسة', () {
    const policy = OpticalZoomPolicy();
    expect(
      policy.clampToHardware(requested: 40, minZoom: 1, maxZoom: 8),
      8,
    );
    expect(
      policy.honestyAr(zoom: 8, maxZoom: 8, hardwareRead: true),
      contains('سقف'),
    );
    expect(
      policy.honestyAr(zoom: 1, maxZoom: 8, hardwareRead: false),
      contains('لم تُقرأ'),
    );
  });
}
