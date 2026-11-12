/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connection_security.dart
/// الاقتران ليس تشفيراً. التشفير غير مربوط لا يُعلَن ناجحاً.
/// =============================================================
library lifex_ai.core.connectivity.connection_security;

import 'connection_device.dart';

/// نقل يثبت هوية الطرف الآخر بنفسه (مصافحة بمفتاح اقتران) ويشفّر الجلسة.
abstract class SelfAuthenticatingTransport {
  bool authenticatedSession(String deviceId);
}

class ConnectionSecurity {
  const ConnectionSecurity({this.encryptionBound = false});

  final bool encryptionBound;

  Future<AuthResult> authenticate(
    ConnectionDevice device, {
    Object? via,
  }) async {
    if (device.virtual) {
      return const AuthResult(ok: true, encrypted: false);
    }
    if (via is SelfAuthenticatingTransport &&
        via.authenticatedSession(device.id)) {
      return const AuthResult(ok: true, encrypted: true);
    }
    return const AuthResult(
      ok: false,
      encrypted: false,
      reason: 'hardware_auth_unbound',
      messageAr:
          'مصادقة هذا الجهاز غير مربوطة. الظهور ليس اتصالاً ولا جلسة مشفّرة.',
    );
  }

  bool get claimsEncryptedLink => encryptionBound;
}

class AuthResult {
  const AuthResult({
    required this.ok,
    required this.encrypted,
    this.reason = '',
    this.messageAr = '',
  });

  final bool ok;
  final bool encrypted;
  final String reason;
  final String messageAr;
}
