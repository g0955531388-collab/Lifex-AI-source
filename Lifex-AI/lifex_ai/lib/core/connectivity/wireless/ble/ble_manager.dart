/// =============================================================
/// Lifex-AI — اتصال لاسلكي
/// الملف: ble_manager.dart
/// حساس BLE غير مربوط لا يبث نبضاً.
/// =============================================================
library lifex_ai.core.connectivity.wireless.ble_manager;

import '../../connection_device.dart';
import '../../connection_state.dart';
import '../../connection_type.dart';
import '../../transport.dart';

class BleCharacteristic {
  const BleCharacteristic({
    required this.uuid,
    this.writable = false,
    this.notifiable = false,
  });

  final String uuid;
  final bool writable;
  final bool notifiable;
}

class BleService {
  const BleService({required this.uuid, this.characteristics = const []});

  final String uuid;
  final List<BleCharacteristic> characteristics;
}

class BleDevice {
  const BleDevice({required this.connection, this.services = const []});

  final ConnectionDevice connection;
  final List<BleService> services;
}

class BleManager {
  BleManager({UnboundTransport? transport})
      : _transport = transport ?? UnboundTransport(ConnectionType.ble);

  final UnboundTransport _transport;

  bool get hardwareBound => false;

  Future<List<BleDevice>> scan() async {
    final found = await _transport.scan();
    return found.map((d) => BleDevice(connection: d)).toList();
  }

  Future<ConnectionState> connect(BleDevice device) {
    return _transport.connect(device.connection);
  }

  Future<void> disconnect(BleDevice device) {
    return _transport.disconnect(device.connection);
  }

  Future<List<BleService>> discoverServices(BleDevice device) async {
    if (!_transport.hardwareBound) return const [];
    return device.services;
  }

  Future<TransportSendResult> subscribe(BleCharacteristic characteristic) async {
    return const TransportSendResult(
      accepted: false,
      reason: 'ble_unbound',
    );
  }

  Future<TransportSendResult> write(
    BleCharacteristic characteristic,
    List<int> data,
  ) async {
    if (!characteristic.writable) {
      return const TransportSendResult(
        accepted: false,
        reason: 'not_writable',
      );
    }
    return const TransportSendResult(accepted: false, reason: 'ble_unbound');
  }
}
