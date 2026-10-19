/// =============================================================
/// Lifex-AI — خزنة مفتاح تشفير HealthObservation (DEK)
/// تفويض إلى HealthObservationKeyLifecycle — SecureSecretStore فقط.
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_vault;

import 'dart:typed_data';

import '../security/secure_secret_store.dart';
import 'health_observation_key_lifecycle.dart';

/// واجهة توافقية فوق Key Lifecycle.
class HealthObservationKeyVault {
  HealthObservationKeyVault({
    required SecureSecretStore secretStore,
    HealthObservationKeyLifecycle? lifecycle,
  }) : lifecycle = lifecycle ??
            HealthObservationKeyLifecycle(secretStore: secretStore);

  static const vaultId = 'HealthObservationKeyVault';
  static const keyLengthBytes = HealthObservationKeyLifecycle.keyLengthBytes;

  /// معرّف سر التخزين القديم — للتوافق؛ القيم عبر Lifecycle.
  static const dataEncryptionKeySecretId =
      HealthObservationKeyLifecycle.legacyDekSecretId;

  final HealthObservationKeyLifecycle lifecycle;

  Future<Uint8List> getOrCreateDataEncryptionKey() async {
    final dek = await lifecycle.ensureCurrentKey();
    return dek.bytes;
  }

  /// دوران المفاتيح مدعوم عبر [HealthObservationKeyLifecycle].
  static const keyRotationSupported = true;
}
