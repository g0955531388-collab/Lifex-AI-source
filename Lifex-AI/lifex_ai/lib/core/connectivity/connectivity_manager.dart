/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connectivity_manager.dart
/// مدخل موحّد. ليس مركزاً يتحكم بكل أجهزة العالم.
/// =============================================================
library lifex_ai.core.connectivity.connectivity_manager;

import 'connection_device.dart';
import 'connection_security.dart';
import 'connection_session.dart';
import 'connection_state.dart';
import 'connection_type.dart';
import 'device_discovery.dart';
import 'device_router.dart';
import 'message_packet.dart';
import 'permission_manager.dart';
import 'transport.dart';

class ConnectivityManager {
  ConnectivityManager({
    DeviceDiscovery? discovery,
    PermissionManager? permissions,
    ConnectionSecurity? security,
    DeviceTransport? virtualTransport,
  })  : discovery = discovery ?? DeviceDiscovery(),
        permissions = permissions ?? PermissionManager(),
        security = security ?? const ConnectionSecurity(),
        virtualTransport = virtualTransport ?? VirtualLoopbackTransport() {
    router = DeviceRouter(
      transport: this.virtualTransport,
      permissions: this.permissions,
    );
  }

  final DeviceDiscovery discovery;
  final PermissionManager permissions;
  final ConnectionSecurity security;
  final DeviceTransport virtualTransport;
  late final DeviceRouter router;
  final sessions = <String, ConnectionSession>{};

  Future<ConnectionState> connect(ConnectionDevice device) async {
    final transport = device.virtual
        ? virtualTransport
        : UnboundTransport(device.connectionType);
    final state = await transport.connect(device);
    if (state != ConnectionState.connected) return state;
    final auth = await security.authenticate(device);
    if (!auth.ok) {
      await transport.disconnect(device);
      device.state = ConnectionState.error;
      return ConnectionState.error;
    }
    final session = ConnectionSession(device)..markOpen();
    sessions[device.id] = session;
    router.register(device);
    return ConnectionState.connected;
  }

  Future<void> disconnect(ConnectionDevice device) async {
    await sessions[device.id]?.close();
    sessions.remove(device.id);
    final transport = device.virtual
        ? virtualTransport
        : UnboundTransport(device.connectionType);
    await transport.disconnect(device);
  }

  Future<RouteResult> send(ConnectionDevice device, MessagePacket packet) {
    return router.send(device, packet);
  }

  bool transportBound(ConnectionType type) {
    if (type == ConnectionType.virtual) return true;
    return false;
  }
}
