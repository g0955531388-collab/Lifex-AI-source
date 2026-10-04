/// =============================================================
/// Lifex-AI — تنسيق الطاقة (Universal Power Management bridge)
/// الملف: lifex_power_coordinator.dart
/// يربط features/energy مع core/power_management الأصلي.
/// ممنوع ادعاء توفير نسبة ثابتة (انظر survivalClaimsFixedPercentSavings=false).
/// =============================================================
library lifex_ai.features.energy.lifex_power_coordinator;

import '../../core/power_management/power_engine.dart';
import '../../core/power_management/power_types.dart';
import 'battery_monitor.dart';
import 'survival_energy_mode.dart';

/// قياس توفير — لا يُرجع نسبة تسويقية بلا قياسين فعليين.
class BatterySavingMeasurement {
  const BatterySavingMeasurement();

  /// الأصل في power_engine + encyclopedia يمنع ادعاء نسب ثابتة.
  bool get survivalClaimsFixedPercentSavings => false;

  /// أي رقم مثل «6%» لا يُقبل كتوفير مُقاس دون baseline + optimized.
  bool acceptFixedMarketingPercent(int claimedPercent) => false;

  MeasuredSavingReport? compare({
    required double? baselineMahPerHour,
    required double? optimizedMahPerHour,
    required Duration sampleDuration,
    required String deviceModel,
    required String androidVersion,
    required String workloadId,
  }) {
    if (baselineMahPerHour == null ||
        optimizedMahPerHour == null ||
        baselineMahPerHour <= 0 ||
        sampleDuration.inSeconds < 60) {
      return MeasuredSavingReport(
        measured: false,
        estimated: true,
        reasonAr:
            'لا يوجد قياس مزدوج (baseline/optimized) لمدة كافية. '
            'لا يُعلن توفير نسبة مئوية.',
        deviceModel: deviceModel,
        androidVersion: androidVersion,
        workloadId: workloadId,
      );
    }
    final delta = baselineMahPerHour - optimizedMahPerHour;
    final ratio = delta / baselineMahPerHour;
    return MeasuredSavingReport(
      measured: true,
      estimated: false,
      baselineMahPerHour: baselineMahPerHour,
      optimizedMahPerHour: optimizedMahPerHour,
      savingRatio: ratio,
      sampleDuration: sampleDuration,
      deviceModel: deviceModel,
      androidVersion: androidVersion,
      workloadId: workloadId,
      reasonAr: 'قياس نسبي على هذا الجهاز والحمولة فقط — ليس ضماناً عاماً.',
    );
  }
}

class MeasuredSavingReport {
  const MeasuredSavingReport({
    required this.measured,
    required this.estimated,
    required this.reasonAr,
    required this.deviceModel,
    required this.androidVersion,
    required this.workloadId,
    this.baselineMahPerHour,
    this.optimizedMahPerHour,
    this.savingRatio,
    this.sampleDuration,
  });

  final bool measured;
  final bool estimated;
  final String reasonAr;
  final String deviceModel;
  final String androidVersion;
  final String workloadId;
  final double? baselineMahPerHour;
  final double? optimizedMahPerHour;
  final double? savingRatio;
  final Duration? sampleDuration;

  String spokenAr() {
    if (!measured || savingRatio == null) {
      return reasonAr;
    }
    final pct = (savingRatio! * 100).toStringAsFixed(1);
    return 'قياس نسبي على $deviceModel: فرق استهلاك يقارب $pct٪ '
        'تحت الحمولة $workloadId — تقدير غير مضمون.';
  }
}

class PowerDecisionRecord {
  PowerDecisionRecord({
    required this.at,
    required this.fromMode,
    required this.toMode,
    required this.reasonAr,
    required this.spokenAr,
    required this.preservedCritical,
    required this.reducedNonCritical,
  });

  final DateTime at;
  final PowerMode fromMode;
  final PowerMode toMode;
  final String reasonAr;
  final String spokenAr;
  final List<String> preservedCritical;
  final List<String> reducedNonCritical;
}

/// منسّق الطاقة — Source of truth للوضع: LifexPowerManagementEngine.
class LifexPowerCoordinator {
  LifexPowerCoordinator({
    required this.batteryMonitor,
    required this.survivalMode,
    LifexPowerManagementEngine? engine,
    BatterySavingMeasurement? measurement,
  })  : engine = engine ?? LifexPowerManagementEngine(),
        measurement = measurement ?? const BatterySavingMeasurement();

  final BatteryMonitor batteryMonitor;
  final SurvivalEnergyMode survivalMode;
  final LifexPowerManagementEngine engine;
  final BatterySavingMeasurement measurement;

  PowerMode _mode = PowerMode.normal;
  PowerMode? _modeBeforeEmergency;
  final decisions = <PowerDecisionRecord>[];
  ThermalState thermal = ThermalState.normal;

  PowerMode get currentMode => _mode;
  bool get survivalActive =>
      engine.survivalActive || survivalMode.isActive;
  bool get emergencyActive => engine.emergencyActive;

  static const criticalPreserved = [
    'voice_accessibility',
    'emergency_communication',
    'emergency_location',
    'critical_alerts',
    'required_monitoring',
    'sos_channels',
  ];

  static const nonCriticalReduced = [
    'background_analytics',
    'background_indexing',
    'noncritical_ai_workload',
    'excessive_network_polling',
    'noncritical_sensor_sampling',
    'unnecessary_media_processing',
    'background_sync',
  ];

  BatteryReading _reading() {
    final s = batteryMonitor.lastKnownStatus;
    return BatteryReading(
      levelPercent: s.level.clamp(0, 100),
      charging: s.isCharging,
      osProvided: true,
    );
  }

  PowerMode evaluate({bool emergency = false}) {
    return engine.modeFor(
      battery: _reading(),
      emergency: emergency || engine.emergencyActive,
      thermal: thermal,
    );
  }

  PowerDecisionRecord applyMode(
    PowerMode next, {
    required String reasonAr,
  }) {
    final from = _mode;
    _mode = next;
    engine.survivalActive =
        next == PowerMode.survival || next == PowerMode.criticalPower;
    if (engine.survivalActive && !survivalMode.isActive) {
      survivalMode.activate();
    } else if (!engine.survivalActive &&
        survivalMode.isActive &&
        !engine.emergencyActive) {
      survivalMode.deactivate();
    }

    final spoken = _spokenFor(next);
    final record = PowerDecisionRecord(
      at: DateTime.now(),
      fromMode: from,
      toMode: next,
      reasonAr: reasonAr,
      spokenAr: spoken,
      preservedCritical: List.of(criticalPreserved),
      reducedNonCritical: engine.freezeNonCritical(next)
          ? List.of(nonCriticalReduced)
          : const [],
    );
    decisions.add(record);
    return record;
  }

  String _spokenFor(PowerMode mode) {
    switch (mode) {
      case PowerMode.emergencyPower:
        return 'تم تفعيل وضع الطاقة الطارئ للحفاظ على البطارية. '
            'الصوت والطوارئ والتواصل الحرج تبقى فعّالة.';
      case PowerMode.survival:
      case PowerMode.criticalPower:
        return 'تم تفعيل وضع البقاء. خُفّضت الأعمال غير الحرجة. '
            'إمكانية الوصول الصوتية تبقى فعّالة.';
      case PowerMode.lowPower:
      case PowerMode.powerSaving:
        return 'تم تفعيل وضع التوفير الذكي. خُفّضت المهام غير الضرورية.';
      case PowerMode.balanced:
        return 'تم الانتقال إلى الوضع المتوازن.';
      case PowerMode.charging:
        return 'الجهاز قيد الشحن. سياسة الطاقة العادية متاحة.';
      case PowerMode.normal:
        return 'تم استعادة وضع الطاقة العادي.';
      case PowerMode.thermalProtection:
        return 'حماية حرارية مفعّلة. خُفّض الحمل.';
      case PowerMode.powerFailure:
        return 'تعذّر قراءة البطارية من النظام. لا ادعاءات توفير.';
    }
  }

  /// طوارئ: يحفظ الوضع السابق، يفعّل emergencyPower، لا يوقف الصوت.
  PowerDecisionRecord activateEmergencyPower() {
    _modeBeforeEmergency ??= _mode;
    engine.emergencyActive = true;
    return applyMode(
      PowerMode.emergencyPower,
      reasonAr: 'emergency_activated',
    );
  }

  /// إنهاء الطوارئ: يستعيد الوضع المناسب حسب البطارية الحالية.
  PowerDecisionRecord restoreAfterEmergency() {
    engine.emergencyActive = false;
    final restored = _modeBeforeEmergency;
    _modeBeforeEmergency = null;
    final next = restored ?? evaluate(emergency: false);
    // لا نرجع NORMAL إن كانت البطارية تستوجب LOW_POWER/SURVIVAL
    final byBattery = evaluate(emergency: false);
    final chosen = _stricter(next, byBattery);
    return applyMode(chosen, reasonAr: 'emergency_resolved_restore');
  }

  PowerMode _stricter(PowerMode a, PowerMode b) {
    int rank(PowerMode m) {
      switch (m) {
        case PowerMode.emergencyPower:
          return 0;
        case PowerMode.survival:
        case PowerMode.criticalPower:
          return 1;
        case PowerMode.lowPower:
          return 2;
        case PowerMode.powerSaving:
          return 3;
        case PowerMode.balanced:
          return 4;
        case PowerMode.normal:
        case PowerMode.charging:
          return 5;
        case PowerMode.thermalProtection:
          return 1;
        case PowerMode.powerFailure:
          return 0;
      }
    }

    return rank(a) <= rank(b) ? a : b;
  }

  void syncFromBattery() {
    if (engine.emergencyActive) {
      applyMode(PowerMode.emergencyPower, reasonAr: 'battery_tick_emergency');
      return;
    }
    applyMode(evaluate(emergency: false), reasonAr: 'battery_tick');
  }

  Map<String, dynamic> dashboard() {
    final bat = _reading();
    final pred = engine.predictRemaining(bat);
    return {
      'batteryPercent': bat.levelPercent,
      'charging': bat.charging,
      'mode': _mode.name,
      'survivalActive': survivalActive,
      'emergencyActive': emergencyActive,
      'estimatedMinutesRemaining': pred.minutesRemaining,
      'estimateGuaranteed': pred.guaranteed,
      'criticalPreserved': criticalPreserved,
      'nonCriticalReduced':
          engine.freezeNonCritical(_mode) ? nonCriticalReduced : const [],
      'lastDecision': decisions.isEmpty ? null : decisions.last.spokenAr,
      'fixedPercentClaimAllowed':
          measurement.survivalClaimsFixedPercentSavings,
    };
  }

  bool mayRunService(String serviceId, PowerPriority priority) {
    return engine.mayRun(
      ServicePowerPolicy(
        serviceId: serviceId,
        priority: priority,
        allowedDuringEmergency: criticalPreserved.contains(serviceId) ||
            priority == PowerPriority.emergency ||
            priority == PowerPriority.safety ||
            serviceId == 'voice_accessibility',
        allowedDuringSurvival: criticalPreserved.contains(serviceId) ||
            priority == PowerPriority.emergency ||
            priority == PowerPriority.safety ||
            serviceId == 'voice_accessibility',
      ),
      _mode,
    );
  }
}
