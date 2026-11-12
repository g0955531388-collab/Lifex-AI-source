/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: network_manager.dart
/// المسار: lib/features/network/network_manager.dart
/// الوصف: المدير المركزي لحالة الاتصال العامة — يجمع حالة كل قنوات
/// الاتصال (بلوتوث/واي فاي/USB) ويقرر القناة الأنسب حالياً للاستخدام.
/// =============================================================
library;

enum ConnectivityChannel { bluetooth, wifi, usb, none }

class NetworkManager {
  NetworkManager();

  final Map<ConnectivityChannel, bool> _channelAvailability = {
    ConnectivityChannel.bluetooth: false,
    ConnectivityChannel.wifi: false,
    ConnectivityChannel.usb: false,
  };

  void updateChannelAvailability(ConnectivityChannel channel, bool available) {
    if (channel == ConnectivityChannel.none) return;
    _channelAvailability[channel] = available;
  }

  bool isAvailable(ConnectivityChannel channel) =>
      _channelAvailability[channel] ?? false;

  /// اختيار أفضل قناة متاحة حسب أولوية ثابتة: واي فاي > بلوتوث > USB،
  /// لأن واي فاي عادة أسرع وأكثر استقراراً لنقل بيانات طبية أكبر حجماً.
  ConnectivityChannel bestAvailableChannel() {
    if (isAvailable(ConnectivityChannel.wifi)) return ConnectivityChannel.wifi;
    if (isAvailable(ConnectivityChannel.bluetooth)) {
      return ConnectivityChannel.bluetooth;
    }
    if (isAvailable(ConnectivityChannel.usb)) return ConnectivityChannel.usb;
    return ConnectivityChannel.none;
  }

  bool get hasAnyConnection =>
      bestAvailableChannel() != ConnectivityChannel.none;
}
