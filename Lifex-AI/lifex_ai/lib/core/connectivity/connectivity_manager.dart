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
    Map<ConnectionType, DeviceTransport> transports = const {},
  })  : discovery = discovery ?? DeviceDiscovery(),
        permissions = permissions ?? PermissionManager(),
        security = security ?? const ConnectionSecurity(),
        virtualTransport = virtualTransport ?? VirtualLoopbackTransport(),
        transports = Map.unmodifiable(transports) {
    router = DeviceRouter(
      transport: this.virtualTransport,
      permissions: this.permissions,
      transportFor: transportFor,
    );
  }

  final DeviceDiscovery discovery;
  final PermissionManager permissions;
  final ConnectionSecurity security;
  final DeviceTransport virtualTransport;

  /// النقل الحقيقي المربوط لكل نوع. ما لم يُربط يبقى UnboundTransport.
  final Map<ConnectionType, DeviceTransport> transports;
  late final DeviceRouter router;
  final sessions = <String, ConnectionSession>{};

  DeviceTransport transportFor(ConnectionDevice device) {
    if (device.virtual) return virtualTransport;
    return transports[device.connectionType] ??
        UnboundTransport(device.connectionType);
  }

  Future<ConnectionState> connect(ConnectionDevice device) async {
    final transport = transportFor(device);
    final state = await transport.connect(device);
    if (state != ConnectionState.connected) return state;
    final auth = await security.authenticate(device, via: transport);
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
    await transportFor(device).disconnect(device);
  }

  Future<RouteResult> send(ConnectionDevice device, MessagePacket packet) {
    return router.send(device, packet);
  }

  bool transportBound(ConnectionType type) {
    if (type == ConnectionType.virtual) return true;
    return transports[type]?.hardwareBound ?? false;
  }
}
