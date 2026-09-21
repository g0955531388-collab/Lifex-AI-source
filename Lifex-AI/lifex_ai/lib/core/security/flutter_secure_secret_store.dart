/// =============================================================
/// Lifex-AI — SecureSecretStore عبر flutter_secure_storage
/// مفاتيح نظام التشغيل (Keychain / Keystore) — ليس SharedPreferences.
/// =============================================================
library lifex_ai.core.security.flutter_secure_secret_store;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_secret_store.dart';

/// التنفيذ الإنتاجي لتخزين مفاتيح التشفير.
class FlutterSecureSecretStore implements SecureSecretStore {
  FlutterSecureSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const implementationId = 'FlutterSecureSecretStore';

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeSecret(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> readSecret(String key) => _storage.read(key: key);

  @override
  Future<void> deleteSecret(String key) => _storage.delete(key: key);
}
