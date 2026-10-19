/// =============================================================
/// Lifex-AI — أمن
/// الملف: device_authentication.dart
/// الاسم الظاهر ليس مصادقة.
/// =============================================================
library lifex_ai.core.connectivity.security.device_authentication;

import '../connection_device.dart';
import '../connection_security.dart';

class DeviceAuthentication {
  DeviceAuthentication({ConnectionSecurity? security})
      : security = security ?? const ConnectionSecurity();

  final ConnectionSecurity security;
  final _ok = <String>{};

  Future<bool> authenticate(ConnectionDevice device) async {
    final r = await security.authenticate(device);
    if (r.ok) _ok.add(device.id);
    return r.ok;
  }

  Future<void> revoke(ConnectionDevice device) async {
    _ok.remove(device.id);
  }

  bool isAuthenticated(ConnectionDevice device) => _ok.contains(device.id);
}

class DevicePairing {
  const DevicePairing();

  Future<bool> pair(ConnectionDevice device) async {
    if (!device.virtual) return false;
    return true;
  }
}

class EncryptionManager {
  const EncryptionManager({this.bound = false});

  final bool bound;

  bool get claimsEncryptedLink => bound;
}

class DevicePermission {
  const DevicePermission({
    this.read = false,
    this.write = false,
    this.stream = false,
    this.sendCommands = false,
    this.receiveCommands = false,
    this.emergency = false,
  });

  final bool read;
  final bool write;
  final bool stream;
  final bool sendCommands;
  final bool receiveCommands;
  final bool emergency;
}
