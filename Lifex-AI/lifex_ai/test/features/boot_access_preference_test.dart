import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/boot_access_preference.dart';

void main() {
  test('خيار الإقلاع لا يشغّل الكاميرا ولا الميكروفون', () {
    final off = BootAccessPreference.decide(userEnabled: false, english: false);
    expect(off.remembered, isFalse);
    expect(off.cameraStartsAtBoot, isFalse);
    expect(off.microphoneStartsAtBoot, isFalse);

    final on = BootAccessPreference.decide(userEnabled: true, english: false);
    expect(on.remembered, isTrue);
    expect(on.cameraStartsAtBoot, isFalse);
    expect(on.microphoneStartsAtBoot, isFalse);
    expect(on.speech, contains('لن يفتح الكاميرا'));
  });

  test('البيان لا يعلن مستقبلاً للإقلاع ولا تجاهل البطارية', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(xml.contains('RECEIVE_BOOT_COMPLETED'), isFalse);
    expect(xml.contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'), isFalse);
  });
}
