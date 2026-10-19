/// =============================================================
/// Lifex-AI — محرك الطاقة والطوارئ 81
/// لا إيقاف عشوائي. لا كاميرا صامتة. لا ضمان مدة بطارية.
/// =============================================================
library lifex_ai.core.power_management.power_engine;

import 'power_types.dart';

class LifexPowerManagementEngine {
  PowerThresholdPolicy thresholds;
  var emergencyActive = false;
  var survivalActive = false;

  LifexPowerManagementEngine({PowerThresholdPolicy? thresholds})
      : thresholds = thresholds ?? const PowerThresholdPolicy();

  bool get powerSavingIsEmergencyShutdown => false;
  bool get inventsOsBatteryFields => false;
  bool get canDisableOsRadiosUnconditionally => false;
  bool get silentCamera => false;
  bool get silentMicrophone => false;
  bool get emergencyReserveIsPhysicalBattery => false;
  bool get guaranteesRemainingRuntime => false;
  bool get survivalClaimsFixedPercentSavings => false;
  bool get aiFindingIsHardwareFault => false;
  bool get autoChangesMedicalDeviceSettings => false;
  bool get stopsCriticalMonitoringToSavePower => false;
  bool get bypassesAndroidPermissions => false;

  PowerMode modeFor({
    required BatteryReading battery,
    required bool emergency,
    required ThermalState thermal,
  }) {
    if (!battery.osProvided) return PowerMode.powerFailure;
    if (thermal == ThermalState.thermalCritical) {
      return PowerMode.thermalProtection;
    }
    if (emergency) return PowerMode.emergencyPower;
    if (battery.charging) return PowerMode.charging;
    final p = battery.levelPercent;
    if (p <= thresholds.criticalBelow) return PowerMode.criticalPower;
    if (p <= thresholds.lowPowerBelow) return PowerMode.lowPower;
    if (p <= thresholds.powerSavingBelow) return PowerMode.powerSaving;
    if (p <= thresholds.balancedBelow) return PowerMode.balanced;
    return PowerMode.normal;
  }

  bool mayRun(ServicePowerPolicy service, PowerMode mode) {
    if (mode == PowerMode.emergencyPower) {
      return service.allowedDuringEmergency ||
          service.priority == PowerPriority.emergency ||
          service.priority == PowerPriority.criticalMedical ||
          service.priority == PowerPriority.safety;
    }
    if (mode == PowerMode.survival || mode == PowerMode.criticalPower) {
      return service.allowedDuringSurvival ||
          service.priority == PowerPriority.emergency ||
          service.priority == PowerPriority.criticalMedical ||
          service.priority == PowerPriority.safety;
    }
    if (mode == PowerMode.powerSaving || mode == PowerMode.lowPower) {
      return service.priority != PowerPriority.analytics &&
          service.priority != PowerPriority.nonCritical;
    }
    return true;
  }

  bool freezeNonCritical(PowerMode mode) {
    return mode == PowerMode.emergencyPower ||
        mode == PowerMode.survival ||
        mode == PowerMode.criticalPower;
  }

  PowerPrediction predictRemaining(BatteryReading battery) {
    if (!battery.osProvided) {
      return const PowerPrediction(estimated: true, guaranteed: false);
    }
    return PowerPrediction(
      estimated: true,
      guaranteed: false,
      minutesRemaining: battery.levelPercent * 8,
    );
  }

  bool enterSurvivalClaimsPercent(int claimedPercent) => false;

  LocationPowerPolicy locationPolicy(PowerMode mode) {
    if (mode == PowerMode.emergencyPower) {
      return LocationPowerPolicy.emergency;
    }
    if (mode == PowerMode.survival || mode == PowerMode.criticalPower) {
      return LocationPowerPolicy.lowPower;
    }
    return LocationPowerPolicy.balanced;
  }

  bool reserveIsSoftwarePolicy() => true;
}
