/// تنفيذ SecureCredentialStore عبر flutter_secure_storage.
/// الخزنة هي Keystore على أندرويد وKeychain على iOS، وتبقى بعد إغلاق التطبيق.
library lifex_ai.core.security.secure_credential_store;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/ai/unified_ai_hub_gateway.dart';

class SecureStorageCredentialStore implements SecureCredentialStore {
  SecureStorageCredentialStore({
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
    bool isBiometricRequired = false,
  })  : _storage = FlutterSecureStorage(
          aOptions: androidOptions ?? const AndroidOptions(resetOnError: true),
          iOptions: iosOptions ??
              const IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
                synchronizable: false,
              ),
        ),
        _isBiometricRequired = isBiometricRequired;

  final FlutterSecureStorage _storage;

  /// لا يفتح حوار بصمة. عند true يبقى عنصر iOS على هذا الجهاز بعد أول فتح.
  final bool _isBiometricRequired;

  @override
  Future<void> saveCredential(String key, String value) async {
    await _storage.write(
      key: key,
      value: value,
      iOptions: _isBiometricRequired
          ? const IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            )
          : null,
    );
  }

  @override
  Future<String?> readCredential(String key) => _storage.read(key: key);

  @override
  Future<void> deleteCredential(String key) => _storage.delete(key: key);

  /// يمسح خزنة flutter_secure_storage الافتراضية كلها، لا مفاتيح الذكاء فقط.
  /// غير موصول بحذف الملف الصحي ولا بتسجيل الخروج.
  Future<void> wipeAll() => _storage.deleteAll();
}
