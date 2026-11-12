import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network/bluetooth_manager.dart';

class _SeenOnly implements BluetoothProvider {
  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<List<DiscoveredBluetoothDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const [
      DiscoveredBluetoothDevice(
        deviceId: 'meter-1',
        name: 'Glucose meter',
        type: BluetoothDeviceType.glucoseMeter,
        signalStrengthRssi: -40,
      ),
    ];
  }

  @override
  Future<bool> connect(String deviceId) async => false;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Stream<List<int>> dataStream(String deviceId) => const Stream.empty();
}

void main() {
  test('جهاز ظهر في المسح يبقى غير متصل', () async {
    final manager = BluetoothManager(provider: _SeenOnly());
    final found = await manager.scan();
    expect(found.single.deviceId, 'meter-1');
    expect(manager.isConnected('meter-1'), isFalse);
    expect(manager.connectedDevices, isEmpty);
  });
}
