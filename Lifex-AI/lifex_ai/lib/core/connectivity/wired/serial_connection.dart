/// =============================================================
/// Lifex-AI — اتصال سلكي
/// الملف: serial_connection.dart
/// معدل البود يحدده الجهاز. ليست 115200 افتراضياً.
/// =============================================================
library lifex_ai.core.connectivity.wired.serial_connection;

import '../connection_device.dart';
import '../connection_state.dart';
import '../connection_type.dart';
import '../transport.dart';
import 'usb_connection.dart';

const serialBaudCandidates = [9600, 19200, 38400, 57600, 115200];

abstract class SerialConnection {
  Future<ConnectionState> connect(
    ConnectionDevice device, {
    required int baudRate,
  });
  Future<void> disconnect();
  Future<TransportSendResult> write(List<int> data);
  Stream<List<int>> get dataStream;
}

class UnboundSerialConnection implements SerialConnection {
  UnboundSerialConnection() : _transport = UnboundTransport(ConnectionType.serial);

  final UnboundTransport _transport;
  ConnectionDevice? _device;
  int? baudRate;

  @override
  Stream<List<int>> get dataStream => _transport.incomingBytes;

  @override
  Future<ConnectionState> connect(
    ConnectionDevice device, {
    required int baudRate,
  }) async {
    if (!serialBaudCandidates.contains(baudRate)) {
      device.state = ConnectionState.error;
      return ConnectionState.error;
    }
    this.baudRate = baudRate;
    _device = device;
    return _transport.connect(device);
  }

  @override
  Future<void> disconnect() async {
    final d = _device;
    if (d != null) await _transport.disconnect(d);
  }

  @override
  Future<TransportSendResult> write(List<int> data) async {
    final d = _device;
    if (d == null) {
      return const TransportSendResult(accepted: false, reason: 'no_device');
    }
    return _transport.send(d, data);
  }
}

class SerialDevice {
  const SerialDevice({required this.connection});
  final ConnectionDevice connection;
}

class WiredProtocol {
  const WiredProtocol();
  String get name => 'lifex.wired.v1';
}

class WiredConnectionManager {
  WiredConnectionManager({
    UsbConnection? usb,
    SerialConnection? serial,
  })  : usb = usb ?? UnboundUsbConnection(),
        serial = serial ?? UnboundSerialConnection();

  final UsbConnection usb;
  final SerialConnection serial;

  bool get hardwareBound => false;
}
