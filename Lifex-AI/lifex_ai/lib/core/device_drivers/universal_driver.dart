/// =============================================================
/// Lifex-AI — سواقات
/// الملف: universal_driver.dart
/// سواقة توافق. ليست بروتوكول مصنع.
/// =============================================================
library lifex_ai.core.device_drivers.universal_driver;

import '../connectivity/connection_device.dart';
import '../connectivity/device_capability.dart';
import 'device_command.dart';
import 'device_event.dart';
import 'device_state.dart';

abstract class UniversalDriver {
  String get driverId;
  String get name;

  Future<bool> detect(ConnectionDevice device);
  Future<CommandResult> connect(ConnectionDevice device);
  Future<void> disconnect();
  Future<DeviceState> readState();
  Future<CommandResult> sendCommand(DeviceCommand command);
  Stream<DeviceEvent> get events;
  bool supports(DeviceCapability capability);
}

class CommandResult {
  const CommandResult({
    required this.ok,
    this.reason = '',
    this.executedOnHardware = false,
  });

  final bool ok;
  final String reason;
  final bool executedOnHardware;
}
