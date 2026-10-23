import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/vision_model_update_desk.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  VisionModelRelease offer(String digest) {
    return VisionModelRelease(
      id: 'demo',
      version: '2',
      source: Uri.parse('https://example.com/model.bin'),
      sha256Hex: digest,
      licenseAr: 'اختبار',
    );
  }

  test('بلا حزمة موقّعة يبقى النموذج العامل', () async {
    final desk = VisionModelUpdateDesk(confirmedWifi: true);
    final report = await desk.request(manual: true);
    expect(report.outcome, ModelUpdateOutcome.noCandidate);
    expect(report.messageAr, contains('بقي كما هو'));
    expect(desk.active, isNull);
  });

  test('التحديث التلقائي الموقوف لا يتنزّل ولا يعود وحده', () async {
    var called = false;
    final desk = VisionModelUpdateDesk(
      autoEnabled: false,
      confirmedWifi: true,
      staged: offer('abc'),
      fetch: (_) async {
        called = true;
        return bytes;
      },
    );
    final report = await desk.request(manual: false);
    expect(report.outcome, ModelUpdateOutcome.skippedAutoOff);
    expect(called, isFalse);
    expect(desk.autoEnabled, isFalse);
  });

  test('بصمة خاطئة لا تستبدل الإصدار المستقر', () async {
    final desk = VisionModelUpdateDesk(
      confirmedWifi: true,
      staged: offer('0000'),
      fetch: (_) async => bytes,
      probe: (_) async => true,
    );
    desk.active = VisionModelRelease(
      id: 'stable',
      version: '1',
      source: Uri.parse('https://example.com/stable.bin'),
      sha256Hex: 'stable',
      licenseAr: 'اختبار',
    );
    final report = await desk.request(manual: true);
    expect(report.outcome, ModelUpdateOutcome.hashMismatch);
    expect(desk.active!.version, '1');
  });

  test('اختبار فاشل يبقي النسخة العاملة', () async {
    final digest = await VisionModelUpdateDesk.sha256Hex(bytes);
    final stable = VisionModelRelease(
      id: 'stable',
      version: '1',
      source: Uri.parse('https://example.com/stable.bin'),
      sha256Hex: digest,
      licenseAr: 'اختبار',
    );
    final desk = VisionModelUpdateDesk(
      confirmedWifi: true,
      staged: offer(digest),
      fetch: (_) async => bytes,
      probe: (_) async => false,
    );
    desk.active = stable;
    final report = await desk.request(manual: true);
    expect(report.outcome, ModelUpdateOutcome.probeFailed);
    expect(desk.active!.version, '1');
    expect(desk.previous, isNull);
  });

  test('اختبار ناجح يفعّل الحزمة ويبقي السابقة', () async {
    final digest = await VisionModelUpdateDesk.sha256Hex(bytes);
    final stable = VisionModelRelease(
      id: 'stable',
      version: '1',
      source: Uri.parse('https://example.com/stable.bin'),
      sha256Hex: digest,
      licenseAr: 'اختبار',
    );
    final desk = VisionModelUpdateDesk(
      confirmedWifi: true,
      staged: offer(digest),
      fetch: (_) async => bytes,
      probe: (_) async => true,
    );
    desk.active = stable;
    final report = await desk.request(manual: true);
    expect(report.outcome, ModelUpdateOutcome.activated);
    expect(desk.active!.version, '2');
    expect(desk.previous!.version, '1');
  });

  test('بلا قياس Wi-Fi لا يبدأ التنزيل', () async {
    var called = false;
    final desk = VisionModelUpdateDesk(
      wifiOnly: true,
      staged: offer('abc'),
      fetch: (_) async {
        called = true;
        return bytes;
      },
    );
    final report = await desk.request(manual: true);
    expect(report.outcome, ModelUpdateOutcome.waitingForWifi);
    expect(called, isFalse);
  });
}
