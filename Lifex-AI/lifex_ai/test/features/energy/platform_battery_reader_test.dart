/// =============================================================
/// Lifex-AI — اختبارات ��لطاقة
/// الملف: platform_battery_reader_test.dart
/// الوصف: اختبارات وحدة لقارئ البطارية الحقيقي.
/// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:mockito/mockito.dart';

import 'package:lifex_ai/features/energy/battery_monitor.dart';
import 'package:lifex_ai/features/energy/platform_battery_reader.dart';

// توليد Mock للـ Battery plugin
class MockBattery extends Mock implements Battery {}

void main() {
  group('PlatformBatteryReader', () {
    late MockBattery mockBattery;
    late PlatformBatteryReader reader;

    setUp(() {
      mockBattery = MockBattery();
      reader = PlatformBatteryReader(battery: mockBattery);
    });

    test('currentLevel returns valid battery percentage', () async {
      when(mockBattery.batteryLevel).thenAnswer((_) async => 75);
      final level = await reader.currentLevel();
      expect(level, 75);
      expect(level, greaterThanOrEqualTo(0));
      expect(level, lessThanOrEqualTo(100));
    });

    test('currentLevel clamps value at 0', () async {
      when(mockBattery.batteryLevel).thenAnswer((_) async => -10);
      final level = await reader.currentLevel();
      expect(level, 0);
    });

    test('currentLevel clamps value at 100', () async {
      when(mockBattery.batteryLevel).thenAnswer((_) async => 150);
      final level = await reader.currentLevel();
      expect(level, 100);
    });

    test('currentLevel defaults to 100 on error', () async {
      when(mockBattery.batteryLevel).thenThrow(Exception('Test error'));
      final level = await reader.currentLevel();
      expect(level, 100);
    });

    test('isCharging returns true when charging', () async {
      when(mockBattery.batteryState).thenAnswer((_) async => BatteryState.charging);
      final charging = await reader.isCharging();
      expect(charging, true);
    });

    test('isCharging returns false when discharging', () async {
      when(mockBattery.batteryState).thenAnswer((_) async => BatteryState.discharging);
      final charging = await reader.isCharging();
      expect(charging, false);
    });

    test('isCharging returns false when full', () async {
      when(mockBattery.batteryState).thenAnswer((_) async => BatteryState.full);
      final charging = await reader.isCharging();
      expect(charging, false);
    });

    test('isCharging defaults to false on error', () async {
      when(mockBattery.batteryState).thenThrow(Exception('Test error'));
      final charging = await reader.isCharging();
      expect(charging, false);
    });

    test('statusStream emits BatteryStatus correctly', () async {
      when(mockBattery.batteryLevel).thenAnswer((_) async => 50);
      when(mockBattery.batteryState).thenAnswer((_) async => BatteryState.discharging);
      when(mockBattery.onBatteryStateChanged).thenAnswer(
        (_) => Stream.value(BatteryState.discharging),
      );

      final statusFuture = reader.statusStream().first;
      final status = await statusFuture;

      expect(status.level, 50);
      expect(status.isCharging, false);
      expect(status.readAt, isNotNull);
    });

    test('dispose cancels subscription', () async {
      reader.dispose();
      // dispose should not throw
      expect(reader.dispose, returnsNormally);
    });
  });

  group('BatteryMonitor with PlatformBatteryReader', () {
    late MockBattery mockBattery;
    late PlatformBatteryReader reader;
    late BatteryMonitor monitor;

    setUp(() {
      mockBattery = MockBattery();
      reader = PlatformBatteryReader(battery: mockBattery);
      monitor = BatteryMonitor(reader: reader);
    });

    test('monitor starts with default status', () {
      expect(monitor.lastKnownStatus.level, 100);
      expect(monitor.lastKnownStatus.isCharging, false);
    });

    test('monitor updates status via updateStatus', () {
      final newStatus = BatteryStatus(level: 25, isCharging: true);
      monitor.updateStatus(newStatus);
      expect(monitor.lastKnownStatus.level, 25);
      expect(monitor.lastKnownStatus.isCharging, true);
    });

    test('monitor notifies listeners on status update', () {
      var notified = false;
      monitor.addListener((_) {
        notified = true;
      });
      final newStatus = BatteryStatus(level: 50, isCharging: false);
      monitor.updateStatus(newStatus);
      expect(notified, true);
    });

    test('monitor can remove listeners', () {
      var notifiedCount = 0;
      final listener = (_) {
        notifiedCount++;
      };
      monitor.addListener(listener);
      monitor.updateStatus(BatteryStatus(level: 50, isCharging: false));
      monitor.removeListener(listener);
      monitor.updateStatus(BatteryStatus(level: 40, isCharging: false));
      expect(notifiedCount, 1);
    });
  });
}
