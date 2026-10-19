/// =============================================================
/// Lifex-AI — اتصال سلكي
/// الملف: usb_connection.dart
/// USB غير مربوط لا يخترع جهازاً متصلاً.
/// =============================================================
library lifex_ai.core.connectivity.wired.usb_connection;

import '../connection_device.dart';
import '../connection_state.dart';
import '../connection_type.dart';
import '../transport.dart';

abstract class UsbConnection {
  Future<ConnectionState> connect(ConnectionDevice device);
  Future<void> disconnect();
  Future<TransportSendResult> send(List<int> data);
  Stream<List<int>> get incomingData;
  bool get isConnected;
  bool get hardwareBound;
}

class UnboundUsbConnection implements UsbConnection {
  UnboundUsbConnection({ConnectionDevice? device})
      : _transport = UnboundTransport(ConnectionType.usb),
        _device = device;

  final UnboundTransport _transport;
  ConnectionDevice? _device;

  @override
  bool get hardwareBound => false;

  @override
  bool get isConnected =>
      _device?.state == ConnectionState.connected;

  @override
  Stream<List<int>> get incomingData => _transport.incomingBytes;

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    _device = device;
    return _transport.connect(device);
  }

  @override
  Future<void> disconnect() async {
    final d = _device;
    if (d != null) await _transport.disconnect(d);
  }

  @override
  Future<TransportSendResult> send(List<int> data) async {
    final d = _device;
    if (d == null) {
      return const TransportSendResult(
        accepted: false,
        reason: 'no_device',
      );
    }
    return _transport.send(d, data);
  }
}

class UsbDevice {
  const UsbDevice({required this.connection});
  final ConnectionDevice connection;
}
