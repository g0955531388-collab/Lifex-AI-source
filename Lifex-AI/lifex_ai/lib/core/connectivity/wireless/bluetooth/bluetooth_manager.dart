/// =============================================================
/// Lifex-AI — اتصال لاسلكي
/// الملف: bluetooth_manager.dart
/// المسح الفارغ ليس قائمة سامسونج.
/// =============================================================
library lifex_ai.core.connectivity.wireless.bluetooth_manager;

import '../../connection_device.dart';
import '../../connection_state.dart';
import '../../connection_type.dart';
import '../../transport.dart';

abstract class BluetoothManager {
  Future<List<ConnectionDevice>> discover();
  Future<ConnectionState> connect(ConnectionDevice device);
  Future<void> disconnect(ConnectionDevice device);
  Future<ConnectionState> pair(ConnectionDevice device);
  Stream<ConnectionDevice> get discoveredDevices;
}

class UnboundBluetoothManager implements BluetoothManager {
  UnboundBluetoothManager()
      : _transport = UnboundTransport(ConnectionType.bluetooth);

  final UnboundTransport _transport;

  @override
  Stream<ConnectionDevice> get discoveredDevices => const Stream.empty();

  @override
  Future<List<ConnectionDevice>> discover() => _transport.scan();

  @override
  Future<ConnectionState> connect(ConnectionDevice device) =>
      _transport.connect(device);

  @override
  Future<void> disconnect(ConnectionDevice device) =>
      _transport.disconnect(device);

  @override
  Future<ConnectionState> pair(ConnectionDevice device) async {
    device.state = ConnectionState.pairing;
    return _transport.connect(device);
  }
}

class BluetoothDevice {
  const BluetoothDevice({required this.connection});
  final ConnectionDevice connection;
}

class BluetoothConnection {
  BluetoothConnection(this.manager);
  final BluetoothManager manager;
}
