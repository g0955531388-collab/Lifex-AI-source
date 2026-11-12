/// =============================================================
/// Lifex-AI — عقد تخزين أسرار آمن (مفاتيح/اعتمادات)
/// لا يُخزَّن أي سر داخل المصدر أو ملفات JSON.
/// =============================================================
library lifex_ai.core.security.secure_secret_store;

/// تجريد Key Management / Secure Storage.
abstract class SecureSecretStore {
  static const storeId = 'SecureSecretStore';

  Future<void> writeSecret(String key, String value);
  Future<String?> readSecret(String key);
  Future<void> deleteSecret(String key);
}
