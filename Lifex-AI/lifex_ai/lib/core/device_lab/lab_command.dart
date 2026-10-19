/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: lab_command.dart
/// =============================================================
library lifex_ai.core.device_lab.lab_command;

import 'control_stage.dart';

class LabCommand {
  const LabCommand({
    required this.id,
    required this.deviceId,
    required this.action,
    required this.timestamp,
    this.parameters = const {},
  });

  final String id;
  final String deviceId;
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;
}

class LabEvent {
  const LabEvent({
    required this.deviceId,
    required this.kind,
    required this.timestamp,
    this.payload = const {},
    this.simulated = true,
    this.clinicalInterpretation = false,
  });

  final String deviceId;
  final String kind;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final bool simulated;
  final bool clinicalInterpretation;
}

class LabResponse {
  const LabResponse({
    required this.ok,
    this.reason = '',
    this.values = const {},
    this.executedOnHardware = false,
    this.simulated = true,
  });

  final bool ok;
  final String reason;
  final Map<String, dynamic> values;
  final bool executedOnHardware;
  final bool simulated;
}

class LabDeviceState {
  const LabDeviceState({
    required this.deviceId,
    required this.powered,
    required this.connected,
    required this.stage,
    this.values = const {},
    this.batteryPercent = 100,
    this.displayContent = '',
  });

  final String deviceId;
  final bool powered;
  final bool connected;
  final DeviceControlStage stage;
  final Map<String, dynamic> values;
  final int batteryPercent;
  final String displayContent;
}
