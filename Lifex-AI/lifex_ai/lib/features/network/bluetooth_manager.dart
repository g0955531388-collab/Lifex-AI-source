/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: bluetooth_manager.dart
/// المسار: lib/features/network/bluetooth_manager.dart
/// الوصف: عقد وإدارة اتصال البلوتوث بأجهزة طبية خارجية (مثل ميزان
/// ضغط أو سكر ذكي). التنفيذ الفعلي عبر حزمة بلوتوث حقيقية يُربط لاحقاً.
///
/// ⚠️ يتطلب أذونات بلوتوث/موقع صريحة من المستخدم مع شرح واضح للسبب،
/// خصوصاً على أندرويد حيث يرتبط مسح البلوتوث بإذن الموقع في بعض الإصدارات.
/// =============================================================
library;

enum BluetoothDeviceType { bloodPressureMonitor, glucoseMeter, pulseOximeter, other }

class DiscoveredBluetoothDevice {
  final String deviceId;
  final String name;
  final BluetoothDeviceType type;
  final int signalStrengthRssi;

  const DiscoveredBluetoothDevice({
    required this.deviceId,
    required this.name,
    required this.type,
    required this.signalStrengthRssi,
  });
}

/// عقد أي مزوّد بلوتوث فعلي.
abstract class BluetoothProvider {
  Future<bool> requestPermissions();
  Future<List<DiscoveredBluetoothDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  });
  Future<bool> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Stream<List<int>> dataStream(String deviceId);
}

/// مدير اتصال البلوتوث.
class BluetoothManager {
  BluetoothManager({required this.provider});

  final BluetoothProvider provider;
  final Set<String> _connectedDeviceIds = {};

  Future<List<DiscoveredBluetoothDevice>> scan() async {
    final hasPermission = await provider.requestPermissions();
    if (!hasPermission) return [];
    return provider.scanForDevices();
  }

  Future<bool> connectToDevice(String deviceId) async {
    final connected = await provider.connect(deviceId);
    if (connected) _connectedDeviceIds.add(deviceId);
    return connected;
  }

  Future<void> disconnectFromDevice(String deviceId) async {
    await provider.disconnect(deviceId);
    _connectedDeviceIds.remove(deviceId);
  }

  bool isConnected(String deviceId) => _connectedDeviceIds.contains(deviceId);

  Set<String> get connectedDevices => Set.unmodifiable(_connectedDeviceIds);
}
