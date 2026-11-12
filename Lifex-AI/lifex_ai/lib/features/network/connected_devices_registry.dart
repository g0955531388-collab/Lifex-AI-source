/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: connected_devices_registry.dart
/// المسار: lib/features/network/connected_devices_registry.dart
/// الوصف: سجل مركزي لكل الأجهزة المتصلة حالياً أو سابقاً، بغض النظر
/// عن القناة (بلوتوث/واي فاي/USB)، لعرضها في شاشة واحدة للمستخدم.
/// =============================================================
library;

import 'network_manager.dart';

enum DeviceConnectionState { connected, disconnected }

class RegisteredDeviceEntry {
  final String deviceId;
  ConnectivityChannel lastChannel;
  DeviceConnectionState state;
  DateTime lastActivityAt;

  RegisteredDeviceEntry({
    required this.deviceId,
    required this.lastChannel,
    required this.state,
    DateTime? lastActivityAt,
  }) : lastActivityAt = lastActivityAt ?? DateTime.now();
}

/// سجل الأجهزة المتصلة الموحّد.
class ConnectedDevicesRegistry {
  ConnectedDevicesRegistry();

  final Map<String, RegisteredDeviceEntry> _entries = {};

  void markConnected(String deviceId, ConnectivityChannel channel) {
    _entries[deviceId] = RegisteredDeviceEntry(
      deviceId: deviceId,
      lastChannel: channel,
      state: DeviceConnectionState.connected,
    );
  }

  void markDisconnected(String deviceId) {
    final entry = _entries[deviceId];
    if (entry != null) {
      entry.state = DeviceConnectionState.disconnected;
      entry.lastActivityAt = DateTime.now();
    }
  }

  List<RegisteredDeviceEntry> get allEntries =>
      List.unmodifiable(_entries.values);

  List<RegisteredDeviceEntry> get currentlyConnected => _entries.values
      .where((e) => e.state == DeviceConnectionState.connected)
      .toList();
}
