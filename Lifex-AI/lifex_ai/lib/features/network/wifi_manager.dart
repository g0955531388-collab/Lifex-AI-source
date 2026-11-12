/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: wifi_manager.dart
/// المسار: lib/features/network/wifi_manager.dart
/// الوصف: عقد وإدارة الاتصال عبر واي فاي (بما فيه الاتصال المباشر
/// Wi-Fi Direct لنقل ملفات كبيرة كالصور الطبية أو الأشعة بين الأجهزة).
/// =============================================================
library;

class WifiConnectionInfo {
  final bool isConnected;
  final String? networkName;
  final bool isMetered;

  const WifiConnectionInfo({
    required this.isConnected,
    this.networkName,
    this.isMetered = false,
  });
}

/// عقد أي مزوّد واي فاي فعلي.
abstract class WifiProvider {
  Future<WifiConnectionInfo> currentConnectionInfo();
  Stream<WifiConnectionInfo> connectionChanges();
  Future<bool> startDirectConnectionHost();
  Future<bool> joinDirectConnection(String hostId);
}

/// مدير اتصال واي فاي.
class WifiManager {
  WifiManager({required this.provider});

  final WifiProvider provider;

  WifiConnectionInfo _lastKnownInfo =
      const WifiConnectionInfo(isConnected: false);

  WifiConnectionInfo get lastKnownInfo => _lastKnownInfo;

  Future<void> refreshStatus() async {
    _lastKnownInfo = await provider.currentConnectionInfo();
  }

  void startListening() {
    provider.connectionChanges().listen((info) {
      _lastKnownInfo = info;
    });
  }

  /// هل يُنصح بنقل ملفات كبيرة (مثل صور أشعة) حالياً؟ نتجنب الشبكات
  /// المحدودة الاستهلاك (metered) لتفادي تكاليف غير متوقعة على المستخدم.
  bool get isSuitableForLargeTransfer =>
      _lastKnownInfo.isConnected && !_lastKnownInfo.isMetered;

  Future<bool> startHostForDeviceHandoff() => provider.startDirectConnectionHost();
  Future<bool> joinHostForDeviceHandoff(String hostId) =>
      provider.joinDirectConnection(hostId);
}
