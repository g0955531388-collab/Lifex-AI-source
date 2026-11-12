/// =============================================================
/// Lifex-AI — الطاقة والاستدامة
/// الملف: energy_manager.dart
/// المسار: lib/features/energy/energy_manager.dart
/// الوصف: المدير المركزي لسياسات استهلاك الطاقة داخل التطبيق — يقرر
/// أي ميزات تُخفَّف أو تُعطَّل مؤقتاً بناءً على حالة البطارية.
/// =============================================================
library;

import '../../core/app_config.dart';
import 'battery_monitor.dart';
import 'intermittent_sense_policy.dart';
import 'phone_battery_brief.dart';
import 'survival_energy_mode.dart';

/// المدير المركزي للطاقة.
class EnergyManager {
  EnergyManager({
    required this.batteryMonitor,
    required this.survivalMode,
    this.sensePolicy = const IntermittentSensePolicy(),
  }) {
    batteryMonitor.addListener(_onBatteryChanged);
  }

  final BatteryMonitor batteryMonitor;
  final SurvivalEnergyMode survivalMode;
  final IntermittentSensePolicy sensePolicy;
  final BatteryAlertGate alerts = BatteryAlertGate();
  void Function(String line)? onAlert;

  void _onBatteryChanged(BatteryStatus status) {
    if (batteryMonitor.hasDeviceReading) {
      final english =
          AppConfig.instance.defaultLanguage == AppLanguage.english;
      final lines = alerts.onReading(
        level: status.level,
        charging: status.isCharging,
        english: english,
      );
      final sink = onAlert;
      if (sink != null) {
        for (final line in lines) {
          sink(line);
        }
      }
    }
    if (status.level <= survivalMode.activationThresholdPercent &&
        !status.isCharging) {
      survivalMode.activate();
    } else if (survivalMode.isActive &&
        (status.isCharging || status.level > survivalMode.deactivationThresholdPercent)) {
      survivalMode.deactivate();
    }
  }

  /// هل ميزة معيّنة (بالاسم) يجب أن تعمل بكامل طاقتها حالياً، أم يجب
  /// تخفيفها بسبب وضع البقاء؟
  bool isFeatureFullyEnabled(String featureName) {
    if (!survivalMode.isActive) return true;
    return !survivalMode.restrictedFeatures.contains(featureName);
  }
}
