// =============================================================
// Lifex-AI — اختبارات قارئ البطارية
// يستخدم FakeSource عند حد المنصة فقط؛ منطق PlatformBatteryReader
// و BatteryMonitor حقيقي.
// =============================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/energy/battery_monitor.dart';
import 'package:lifex_ai/features/energy/platform_battery_reader.dart';

class FakeSource implements BatterySource {
  int levelValue = 50;
  bool charging = false;
  Object? levelError;
  Object? chargingError;
  final StreamController<bool> controller = StreamController<bool>();

  @override
  Future<int> level() async {
    if (levelError != null) throw levelError!;
    return levelValue;
  }

  @override
  Future<bool> isCharging() async {
    if (chargingError != null) throw chargingError!;
    return charging;
  }

  @override
  Stream<bool> chargingChanges() => controller.stream;
}

void main() {
  late FakeSource source;
  late PlatformBatteryReader reader;

  setUp(() {
    source = FakeSource();
    reader = PlatformBatteryReader(source: source);
  });

  tearDown(() => source.controller.close());

  group('currentLevel', () {
    test('returns the real level', () async {
      source.levelValue = 75;
      expect(await reader.currentLevel(), 75);
    });

    test('clamps below 0 and above 100', () async {
      source.levelValue = -10;
      expect(await reader.currentLevel(), 0);
      source.levelValue = 150;
      expect(await reader.currentLevel(), 100);
    });

    test('failure is reported, never replaced by a made-up value', () async {
      source.levelError = Exception('no battery');
      expect(reader.currentLevel(), throwsA(isA<BatteryReadException>()));
    });
  });

  group('isCharging', () {
    test('reflects the source', () async {
      source.charging = true;
      expect(await reader.isCharging(), isTrue);
      source.charging = false;
      expect(await reader.isCharging(), isFalse);
    });

    test('failure is reported, not defaulted', () async {
      source.chargingError = Exception('no state');
      expect(reader.isCharging(), throwsA(isA<BatteryReadException>()));
    });
  });

  group('statusStream', () {
    test('emits level + charging on each change', () async {
      source.levelValue = 42;
      final future = reader.statusStream().first;
      source.controller.add(true);
      final status = await future;
      expect(status.level, 42);
      expect(status.isCharging, isTrue);
    });

    test('event whose level read fails is skipped; stream continues',
        () async {
      final received = <BatteryStatus>[];
      final sub = reader.statusStream().listen(received.add);

      source.levelError = Exception('transient');
      source.controller.add(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);

      source.levelError = null;
      source.levelValue = 30;
      source.controller.add(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.single.level, 30);
      expect(received.single.isCharging, isFalse);
      await sub.cancel();
    });

    test('source stream errors do not end or crash the stream', () async {
      final received = <BatteryStatus>[];
      final sub = reader.statusStream().listen(received.add);
      source.controller.addError(StateError('plugin'));
      source.levelValue = 20;
      source.controller.add(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(received.single.level, 20);
      await sub.cancel();
    });
  });

  group('BatteryMonitor with PlatformBatteryReader', () {
    test('startMonitoring forwards real stream updates to listeners', () async {
      source.levelValue = 15;
      final monitor = BatteryMonitor(reader: reader);
      final seen = <BatteryStatus>[];
      monitor.addListener(seen.add);
      monitor.startMonitoring();

      source.controller.add(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1));
      expect(monitor.lastKnownStatus.level, 15);
      expect(monitor.lastKnownStatus.isCharging, isFalse);
    });
  });
}
