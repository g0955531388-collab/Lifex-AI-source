/// =============================================================
/// Lifex-AI — الطاقة والاستدامة
/// الملف: platform_battery_reader.dart
/// المسار: lib/features/energy/platform_battery_reader.dart
/// الوصف: تنفيذ حقيقي لقارئ البطارية باستخدام battery_plus.
/// يحقن BatteryReader الحقيقي في BatteryMonitor عند الإقلاع.
/// =============================================================

import 'package:battery_plus/battery_plus.dart';
import 'battery_monitor.dart';

/// تنفيذ حقيقي لواجهة BatteryReader باستخدام battery_plus.
class PlatformBatteryReader implements BatteryReader {
  PlatformBatteryReader({Battery? battery})
      : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<int> currentLevel() async {
    try {
      final level = await _battery.batteryLevel;
      // تثبيت القيمة بين 0 و 100
      return level.clamp(0, 100);
    } catch (_) {
      // عند الفشل، نفترض البطارية على حالة جيدة (100%)
      return 100;
    }
  }

  @override
  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging;
    } catch (_) {
      // عند الفشل، نفترض عدم الشحن
      return false;
    }
  }

  @override
  Stream<BatteryStatus> statusStream() {
    return _battery.onBatteryStateChanged
        .asyncMap((state) async {
          final level = await currentLevel();
          final isCharging = state == BatteryState.charging;
          return BatteryStatus(
            level: level,
            isCharging: isCharging,
          );
        })
        .handleError((_) {
          // إذا حدث خطأ في البث، نرجع حالة آمنة
          return BatteryStatus(level: 100, isCharging: false);
        });
  }

  /// تنظيف الموارد (اختياري في هذا السياق)
  void dispose() {
    // لا تو��د موارد قابلة للإطلاق من Battery نفسه
  }
}
