/// =============================================================
/// Lifex-AI — الطاقة والاستدامة
/// الملف: platform_battery_reader.dart
/// الوصف: تنفيذ BatteryReader فوق battery_plus. يعزل الحزمة خلف
/// [BatterySource] ليكون المنطق قابلاً للاختبار بلا اعتماد على شكل
/// كلاس الحزمة. لا يختلق أي قراءة: عند فشل القراءة يُرمى
/// [BatteryReadException] في القراءة المباشرة، ويُتخطى الحدث في الـ stream.
/// =============================================================

import 'package:battery_plus/battery_plus.dart';

import 'battery_monitor.dart';

/// فشل قراءة البطارية من النظام.
class BatteryReadException implements Exception {
  const BatteryReadException(this.message);
  final String message;

  @override
  String toString() => 'BatteryReadException: $message';
}

/// مصدر خام لبيانات البطارية.
abstract class BatterySource {
  Future<int> level();
  Future<bool> isCharging();
  Stream<bool> chargingChanges();
}

/// التنفيذ الإنتاجي فوق battery_plus.
class BatteryPlusSource implements BatterySource {
  BatteryPlusSource() : _battery = Battery();

  final Battery _battery;

  @override
  Future<int> level() => _battery.batteryLevel;

  @override
  Future<bool> isCharging() async =>
      (await _battery.batteryState) == BatteryState.charging;

  @override
  Stream<bool> chargingChanges() => _battery.onBatteryStateChanged
      .map((state) => state == BatteryState.charging);
}

class PlatformBatteryReader implements BatteryReader {
  PlatformBatteryReader({BatterySource? source})
      : _source = source ?? BatteryPlusSource();

  final BatterySource _source;

  @override
  Future<int> currentLevel() async {
    try {
      final level = await _source.level();
      return level.clamp(0, 100);
    } catch (e) {
      throw BatteryReadException('level unavailable: $e');
    }
  }

  @override
  Future<bool> isCharging() async {
    try {
      return await _source.isCharging();
    } catch (e) {
      throw BatteryReadException('charging state unavailable: $e');
    }
  }

  /// يصدر حالة عند كل تغيّر في الشحن. إن فشلت قراءة المستوى لحدث ما
  /// يُتخطى الحدث (لا قيمة مختلقة)، وأخطاء المصدر نفسه تُبتلع بلا إنهاء.
  @override
  Stream<BatteryStatus> statusStream() {
    return _source
        .chargingChanges()
        .asyncExpand<BatteryStatus>((charging) async* {
      try {
        final level = (await _source.level()).clamp(0, 100);
        yield BatteryStatus(level: level, isCharging: charging);
      } catch (_) {
        // قراءة المستوى فشلت: لا نصدر حالة غير حقيقية.
      }
    }).handleError((Object _) {});
  }
}
