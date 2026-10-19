/// =============================================================
/// Lifex-AI — إدارة الطاقة 81
/// التوفير ≠ إيقاف الطوارئ. الاحتياطي سياسة برمجية ≠ بطارية مستقلة.
/// =============================================================
library lifex_ai.core.power_management.power_types;

enum PowerMode {
  normal,
  balanced,
  powerSaving,
  lowPower,
  criticalPower,
  emergencyPower,
  survival,
  charging,
  thermalProtection,
  powerFailure,
}

enum PowerPriority {
  emergency,
  criticalMedical,
  safety,
  monitoring,
  communication,
  location,
  health,
  security,
  userActive,
  background,
  analytics,
  nonCritical,
}

enum LocationPowerPolicy { off, lowPower, balanced, highAccuracy, emergency }

enum ThermalState { normal, warm, hot, thermalLimit, thermalCritical }

class PowerThresholdPolicy {
  const PowerThresholdPolicy({
    this.balancedBelow = 40,
    this.powerSavingBelow = 20,
    this.lowPowerBelow = 10,
    this.criticalBelow = 5,
  });

  final int balancedBelow;
  final int powerSavingBelow;
  final int lowPowerBelow;
  final int criticalBelow;
}

class BatteryReading {
  const BatteryReading({
    required this.levelPercent,
    this.health,
    this.charging = false,
    this.temperatureC,
    this.osProvided = true,
  });

  final int levelPercent;
  final String? health;
  final bool charging;
  final double? temperatureC;
  final bool osProvided;
}

class PowerPrediction {
  const PowerPrediction({
    required this.estimated,
    required this.guaranteed,
    this.minutesRemaining,
  });

  final bool estimated;
  final bool guaranteed;
  final int? minutesRemaining;
}

class ServicePowerPolicy {
  const ServicePowerPolicy({
    required this.serviceId,
    required this.priority,
    this.allowedDuringEmergency = false,
    this.allowedDuringSurvival = false,
  });

  final String serviceId;
  final PowerPriority priority;
  final bool allowedDuringEmergency;
  final bool allowedDuringSurvival;
}
