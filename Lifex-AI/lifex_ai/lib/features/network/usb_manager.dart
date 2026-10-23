/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: usb_manager.dart
/// المسار: lib/features/network/usb_manager.dart
/// الوصف: عقد وإدارة اتصال USB — يُستخدم غالباً لنقل بيانات موثوق منها
/// بشكل أعلى (مثل استيراد أرشيف طبي كامل) أو شحن مع نقل بيانات محدود.
/// =============================================================
library;

class UsbConnectionInfo {
  final bool isConnected;
  final String? connectedDeviceLabel;

  const UsbConnectionInfo({
    required this.isConnected,
    this.connectedDeviceLabel,
  });
}

abstract class UsbProvider {
  Future<UsbConnectionInfo> currentConnectionInfo();
  Stream<UsbConnectionInfo> connectionChanges();
  Future<bool> requestPermission();
  Future<List<int>> readData();
  Future<bool> writeData(List<int> data);
}

/// مدير اتصال USB.
class UsbManager {
  UsbManager({required this.provider});

  final UsbProvider provider;
  UsbConnectionInfo _lastKnownInfo =
      const UsbConnectionInfo(isConnected: false);

  UsbConnectionInfo get lastKnownInfo => _lastKnownInfo;

  void startListening() {
    provider.connectionChanges().listen((info) {
      _lastKnownInfo = info;
    });
  }

  Future<bool> requestAccess() => provider.requestPermission();

  Future<List<int>> readIncomingData() => provider.readData();

  Future<bool> sendData(List<int> data) => provider.writeData(data);
}
