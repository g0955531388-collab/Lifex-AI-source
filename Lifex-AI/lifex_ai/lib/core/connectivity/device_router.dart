/// =============================================================
/// Lifex-AI — اتصال
/// الملف: device_router.dart
/// التوجيه حسب القدرة الممنوحة فقط.
/// =============================================================
library lifex_ai.core.connectivity.device_router;

import 'connection_device.dart';
import 'connection_state.dart';
import 'device_capability.dart';
import 'message_packet.dart';
import 'permission_manager.dart';
import 'transport.dart';

class DeviceRouter {
  DeviceRouter({
    required this.transport,
    required this.permissions,
    this.transportFor,
  });

  final DeviceTransport transport;
  final PermissionManager permissions;

  /// اختيار النقل لكل جهاز؛ بدونه يبقى النقل الافتراضي كما كان.
  final DeviceTransport Function(ConnectionDevice device)? transportFor;
  final _sessions = <String, ConnectionDevice>{};

  void register(ConnectionDevice device) {
    _sessions[device.id] = device;
  }

  Future<RouteResult> send(
    ConnectionDevice device,
    MessagePacket packet, {
    DeviceCapability? requiredCapability,
  }) async {
    if (device.state != ConnectionState.connected) {
      return const RouteResult(ok: false, reason: 'not_connected');
    }
    if (requiredCapability != null &&
        !permissions.allows(device, requiredCapability)) {
      return const RouteResult(ok: false, reason: 'permission_denied');
    }
    final sent = await (transportFor?.call(device) ?? transport).send(
      device,
      packet.toJson().toString().codeUnits,
    );
    return RouteResult(ok: sent.accepted, reason: sent.reason);
  }

  Future<RouteResult> routeByCapability(
    DeviceCapability capability,
    MessagePacket packet,
  ) async {
    for (final d in _sessions.values) {
      if (d.capabilities.contains(capability) &&
          permissions.allows(d, capability) &&
          d.state == ConnectionState.connected) {
        return send(d, packet, requiredCapability: capability);
      }
    }
    return const RouteResult(ok: false, reason: 'no_capable_device');
  }
}

class RouteResult {
  const RouteResult({required this.ok, this.reason = ''});

  final bool ok;
  final String reason;
}
