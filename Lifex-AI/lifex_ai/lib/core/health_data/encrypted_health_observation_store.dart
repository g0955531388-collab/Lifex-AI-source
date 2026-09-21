/// =============================================================
/// Lifex-AI — Encrypted HealthObservation Persistent Store
/// يلف FileHealthObservationStore (أو أي store داخلي) بتشفير at-rest.
/// =============================================================
library lifex_ai.core.health_data.encrypted_health_observation_store;

import 'health_observation_cipher.dart';
import 'health_observation_key_vault.dart';
import 'health_observation_repository.dart';

/// مخزن دائم مشفّر — التنفيذ الإنتاجي لـ HealthObservation persistence.
class EncryptedHealthObservationStore
    implements HealthObservationPersistentStore {
  EncryptedHealthObservationStore({
    required this.inner,
    required this.keyVault,
    AesGcmHealthObservationCipher? cipher,
  }) : cipher = cipher ?? AesGcmHealthObservationCipher();

  static const storeName = 'EncryptedHealthObservationStore';

  /// الطبقة الداخلية (عادة FileHealthObservationStore) تخزّن ciphertext فقط.
  final HealthObservationPersistentStore inner;
  final HealthObservationKeyVault keyVault;
  final AesGcmHealthObservationCipher cipher;

  @override
  Future<String?> readRaw() async {
    final envelope = await inner.readRaw();
    if (envelope == null || envelope.trim().isEmpty) return null;
    final key = await keyVault.getOrCreateDataEncryptionKey();
    return cipher.decrypt(envelope: envelope, keyBytes: key);
  }

  @override
  Future<void> writeRaw(String contents) async {
    final key = await keyVault.getOrCreateDataEncryptionKey();
    final envelope = await cipher.encrypt(plaintext: contents, keyBytes: key);
    await inner.writeRaw(envelope);
  }
}
