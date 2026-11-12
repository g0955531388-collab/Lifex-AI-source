/// =============================================================
/// Lifex-AI — اتصال
/// الملف: transport.dart
/// نقل غير مربوط لا يخترع بايتات ولا جلسة حية.
/// =============================================================
library lifex_ai.core.connectivity.transport;

import 'connection_device.dart';
import 'connection_state.dart';
import 'connection_type.dart';
import 'message_packet.dart';

abstract class DeviceTransport {
  ConnectionType get type;
  bool get hardwareBound;
  Stream<List<int>> get incomingBytes;
  Future<List<ConnectionDevice>> scan();
  Future<ConnectionState> connect(ConnectionDevice device);
  Future<void> disconnect(ConnectionDevice device);
  Future<TransportSendResult> send(ConnectionDevice device, List<int> data);
}

class TransportSendResult {
  const TransportSendResult({
    required this.accepted,
    this.reason = '',
  });

  final bool accepted;
  final String reason;
}

/// USB/Serial/BLE/Wi-Fi الحقيقية غير مربوطة في هذا البناء.
class UnboundTransport implements DeviceTransport {
  UnboundTransport(this.type);

  @override
  final ConnectionType type;

  @override
  bool get hardwareBound => false;

  @override
  Stream<List<int>> get incomingBytes => const Stream.empty();

  @override
  Future<List<ConnectionDevice>> scan() async => const [];

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    device.state = ConnectionState.unbound;
    return ConnectionState.unbound;
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {
    device.state = ConnectionState.disconnected;
  }

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    return const TransportSendResult(
      accepted: false,
      reason: 'transport_unbound',
    );
  }
}

class VirtualLoopbackTransport implements DeviceTransport {
  VirtualLoopbackTransport();

  final _inbox = <List<int>>[];

  @override
  ConnectionType get type => ConnectionType.virtual;

  @override
  bool get hardwareBound => true;

  @override
  Stream<List<int>> get incomingBytes => Stream.fromIterable(_inbox);

  @override
  Future<List<ConnectionDevice>> scan() async => const [];

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    if (!device.virtual) {
      device.state = ConnectionState.error;
      return ConnectionState.error;
    }
    device.state = ConnectionState.connected;
    return ConnectionState.connected;
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {
    device.state = ConnectionState.disconnected;
  }

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    if (device.state != ConnectionState.connected) {
      return const TransportSendResult(
        accepted: false,
        reason: 'not_connected',
      );
    }
    _inbox.add(data);
    return const TransportSendResult(accepted: true);
  }

  List<int> encodePacket(MessagePacket packet) {
    return packet.toJson().toString().codeUnits;
  }
}
