/// =============================================================
/// Lifex-AI — اتصال
/// الملف: permission_manager.dart
/// الجهاز المعروف بالاسم لا يحصل على كل الصلاحيات.
/// =============================================================
library lifex_ai.core.connectivity.permission_manager;

import 'connection_device.dart';
import 'device_capability.dart';

class PermissionManager {
  final _granted = <String, Set<DeviceCapability>>{};

  void grant(ConnectionDevice device, DeviceCapability capability) {
    _granted.putIfAbsent(device.id, () => {}).add(capability);
  }

  void revoke(ConnectionDevice device, DeviceCapability capability) {
    _granted[device.id]?.remove(capability);
  }

  bool allows(ConnectionDevice device, DeviceCapability capability) {
    if (!device.capabilities.contains(capability)) return false;
    return _granted[device.id]?.contains(capability) ?? false;
  }

  /// الساعة لا تتحكم بالكاميرا لمجرد الاقتران.
  bool watchMayControlPhoneCamera(ConnectionDevice watch) {
    return false;
  }
}
