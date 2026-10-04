/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connection_session.dart
/// إعادة الاتصال بلا نهاية ممنوعة.
/// =============================================================
library lifex_ai.core.connectivity.connection_session;

import 'connection_device.dart';
import 'connection_state.dart';
import 'transport.dart';

class ConnectionSession {
  ConnectionSession(this.device, {this.maxReconnects = 3});

  final ConnectionDevice device;
  final int maxReconnects;
  DateTime? openedAt;
  int reconnectAttempts = 0;
  DateTime? lastHeartbeat;

  bool get isAlive =>
      device.state == ConnectionState.connected && openedAt != null;

  Duration get connectionDuration =>
      openedAt == null ? Duration.zero : DateTime.now().difference(openedAt!);

  bool get heartbeatStale {
    if (lastHeartbeat == null) return false;
    return DateTime.now().difference(lastHeartbeat!) >
        const Duration(seconds: 12);
  }

  bool canReconnect() => reconnectAttempts < maxReconnects;

  Duration backoff() =>
      Duration(milliseconds: 200 * (reconnectAttempts + 1));

  Future<ConnectionState> reconnect({DeviceTransport? transport}) async {
    if (!canReconnect()) {
      device.state = ConnectionState.disconnected;
      return ConnectionState.disconnected;
    }
    reconnectAttempts += 1;
    device.state = ConnectionState.reconnecting;
    await Future<void>.delayed(backoff());
    if (transport == null || !transport.hardwareBound) {
      device.state = ConnectionState.unbound;
      return ConnectionState.unbound;
    }
    return transport.connect(device);
  }

  Future<void> close() async {
    device.state = ConnectionState.disconnected;
    openedAt = null;
  }

  void markOpen() {
    openedAt = DateTime.now();
    lastHeartbeat = DateTime.now();
    reconnectAttempts = 0;
  }

  void markHeartbeat() {
    lastHeartbeat = DateTime.now();
  }
}
