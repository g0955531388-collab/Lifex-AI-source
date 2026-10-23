/// =============================================================
/// Lifex-AI — حماية الجهاز واستعادة الحساب
/// الملف: trusted_devices_manager.dart
/// المسار: lib/features/device_guardian/trusted_devices_manager.dart
/// الوصف: إدارة قائمة الأجهزة الموثوقة المرتبطة بحساب واحد، وإلغاء ثقة
/// أي جهاز مفقود أو مسروق فوراً.
/// =============================================================
library;

class TrustedDevice {
  final String deviceId;
  final String deviceLabel;
  final DateTime firstSeenAt;
  DateTime lastSeenAt;

  TrustedDevice({
    required this.deviceId,
    required this.deviceLabel,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  })  : firstSeenAt = firstSeenAt ?? DateTime.now(),
        lastSeenAt = lastSeenAt ?? DateTime.now();
}

/// مدير الأجهزة الموثوقة لحساب واحد.
class TrustedDevicesManager {
  TrustedDevicesManager();

  final Map<String, TrustedDevice> _devices = {};
  final Set<String> _revokedDeviceIds = {};

  void registerDevice(TrustedDevice device) {
    _devices[device.deviceId] = device;
    _revokedDeviceIds.remove(device.deviceId);
  }

  bool isKnownDevice(String deviceId) => _devices.containsKey(deviceId);

  bool isRevoked(String deviceId) => _revokedDeviceIds.contains(deviceId);

  /// إلغاء ثقة جهاز فوراً — يُستدعى عند الإبلاغ عن فقدان/سرقة.
  void revokeDevice(String deviceId) {
    _revokedDeviceIds.add(deviceId);
    _devices.remove(deviceId);
  }

  void updateLastSeen(String deviceId) {
    _devices[deviceId]?.lastSeenAt = DateTime.now();
  }

  List<TrustedDevice> get allDevices => List.unmodifiable(_devices.values);
}
