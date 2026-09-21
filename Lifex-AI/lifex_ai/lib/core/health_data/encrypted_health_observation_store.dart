/// =============================================================
/// Lifex-AI — Encrypted HealthObservation Persistent Store
/// يلف FileHealthObservationStore بتشفير at-rest + key lifecycle.
/// =============================================================
library lifex_ai.core.health_data.encrypted_health_observation_store;

import 'health_observation_cipher.dart';
import 'health_observation_key_lifecycle.dart';
import 'health_observation_key_vault.dart';
import 'health_observation_repository.dart';

/// مخزن دائم مشفّر — التنفيذ الإنتاجي لـ HealthObservation persistence.
class EncryptedHealthObservationStore
    implements HealthObservationPersistentStore {
  EncryptedHealthObservationStore({
    required this.inner,
    required HealthObservationKeyVault keyVault,
    AesGcmHealthObservationCipher? cipher,
    HealthObservationKeyLifecycle? lifecycle,
  })  : keyVault = keyVault,
        cipher = cipher ?? AesGcmHealthObservationCipher(),
        lifecycle = lifecycle ?? keyVault.lifecycle;

  static const storeName = 'EncryptedHealthObservationStore';

  /// الطبقة الداخلية (عادة FileHealthObservationStore) تخزّن ciphertext فقط.
  final HealthObservationPersistentStore inner;
  final HealthObservationKeyVault keyVault;
  final HealthObservationKeyLifecycle lifecycle;
  final AesGcmHealthObservationCipher cipher;

  @override
  Future<String?> readRaw() async {
    final envelope = await inner.readRaw();
    if (envelope == null || envelope.trim().isEmpty) return null;
    return lifecycle.decryptWithRecovery(
      envelope: envelope,
      cipher: cipher,
    );
  }

  @override
  Future<void> writeRaw(String contents) async {
    final current = await lifecycle.ensureCurrentKey();
    final envelope = await cipher.encrypt(
      plaintext: contents,
      keyBytes: current.bytes,
      keyId: current.keyId,
    );
    await inner.writeRaw(envelope);
  }

  /// دوران مفتاح آمن مع استعادة عند الفشل.
  Future<HealthObservationKeyRotationResult> rotateKeys() {
    return lifecycle.rotateEncryptedStore(inner: inner, cipher: cipher);
  }
}
