/// =============================================================
/// Lifex-AI — SecureSecretStore في الذاكرة (اختبارات فقط)
/// ممنوع كافتراضي في LifexProductionComposition.
/// =============================================================
library lifex_ai.core.security.memory_secure_secret_store;

import 'secure_secret_store.dart';

class MemorySecureSecretStore implements SecureSecretStore {
  MemorySecureSecretStore();

  static const implementationId = 'MemorySecureSecretStore';
  static const testOnlyMarker = 'TEST_ONLY_MEMORY_SECURE_SECRET_STORE';

  final Map<String, String> _secrets = {};

  @override
  Future<void> writeSecret(String key, String value) async {
    _secrets[key] = value;
  }

  @override
  Future<String?> readSecret(String key) async => _secrets[key];

  @override
  Future<void> deleteSecret(String key) async {
    _secrets.remove(key);
  }
}
