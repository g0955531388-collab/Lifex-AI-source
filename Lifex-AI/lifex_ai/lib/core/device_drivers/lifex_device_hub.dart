/// =============================================================
/// Lifex-AI — سواقات
/// الملف: lifex_device_hub.dart
/// محور توافق. لا يدّعي تشغيل كل أجهزة العالم.
/// =============================================================
library lifex_ai.core.device_drivers.lifex_device_hub;

import '../connectivity/connection_device.dart';
import '../connectivity/connection_state.dart';
import '../connectivity/connectivity_manager.dart';
import '../connectivity/device_capability.dart';
import '../connectivity/device_discovery.dart';
import '../connectivity/message_packet.dart';
import '../connectivity/permission_manager.dart';
import 'device_command.dart';
import 'device_event.dart';
import 'driver_registry.dart';
import 'universal_driver.dart';
import 'virtual_device.dart';

class LifexDeviceHub {
  LifexDeviceHub({
    DriverRegistry? registry,
    ConnectivityManager? connectivity,
  }) : this._build(registry ?? DriverRegistry.withSimulators(), connectivity);

  LifexDeviceHub._build(this.registry, ConnectivityManager? connectivity)
      : connectivity = connectivity ??
            ConnectivityManager(
              discovery: DeviceDiscovery(
                virtualCatalog: registry.drivers
                    .whereType<VirtualDevice>()
                    .map((d) => d.connection)
                    .toList(),
              ),
            );

  final DriverRegistry registry;
  final ConnectivityManager connectivity;

  PermissionManager get permissions => connectivity.permissions;

  Future<List<ConnectionDevice>> discover() => connectivity.discovery.scan();

  Future<CommandResult> connect(ConnectionDevice device) async {
    final driver = registry.findDriver(device);
    if (driver == null) {
      return const CommandResult(ok: false, reason: 'no_driver');
    }
    final link = await connectivity.connect(device);
    if (link != ConnectionState.connected) {
      return CommandResult(ok: false, reason: link.name);
    }
    return driver.connect(device);
  }

  Future<CommandResult> command(
    ConnectionDevice device,
    DeviceCommand command, {
    DeviceCapability? capability,
  }) async {
    if (capability != null && !permissions.allows(device, capability)) {
      return const CommandResult(ok: false, reason: 'permission_denied');
    }
    final driver = registry.findDriver(device);
    if (driver == null) {
      return const CommandResult(ok: false, reason: 'no_driver');
    }
    final result = await driver.sendCommand(command);
    if (result.ok) {
      await connectivity.send(
        device,
        MessagePacket(
          messageId: command.id,
          deviceId: device.id,
          command: command.action,
          timestamp: command.timestamp,
          payload: command.parameters,
        ),
      );
    }
    return result;
  }

  Stream<DeviceEvent>? eventsOf(ConnectionDevice device) {
    return registry.findDriver(device)?.events;
  }

  /// الهاتف يعرض على التلفزيون الوهمي إذا مُنحت القدرة.
  Future<CommandResult> showOnDisplay(
    ConnectionDevice display,
    String content,
  ) {
    return command(
      display,
      DeviceCommand(
        id: 'cmd_show',
        deviceId: display.id,
        action: 'show',
        timestamp: DateTime.now(),
        parameters: {'content': content},
      ),
      capability: DeviceCapability.display,
    );
  }
}
