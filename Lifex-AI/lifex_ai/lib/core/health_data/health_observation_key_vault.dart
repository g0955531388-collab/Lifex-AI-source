/// =============================================================
/// Lifex-AI — خزنة مفتاح تشفير HealthObservation (DEK)
/// المفتاح يُولَّد عشوائياً ويُحفظ في SecureSecretStore فقط.
/// لا دوران مفاتيح (key rotation) في هذه المرحلة.
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_vault;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../security/secure_secret_store.dart';

/// Key Management لـ HealthObservation at-rest encryption.
class HealthObservationKeyVault {
  HealthObservationKeyVault({required this.secretStore});

  static const vaultId = 'HealthObservationKeyVault';

  /// معرّف سر التخزين — ليس قيمة المفتاح.
  static const dataEncryptionKeySecretId =
      'lifex.health_observation.dek.v1';

  /// طول مفتاح AES-256 بالبايت.
  static const keyLengthBytes = 32;

  final SecureSecretStore secretStore;

  /// يجلب DEK أو يولّد واحداً جديداً ويحفظه في Secure Storage.
  Future<Uint8List> getOrCreateDataEncryptionKey() async {
    final existing =
        await secretStore.readSecret(dataEncryptionKeySecretId);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Url.decode(existing);
      if (bytes.length != keyLengthBytes) {
        throw StateError(
          'HealthObservation DEK length invalid — refusing to use.',
        );
      }
      return Uint8List.fromList(bytes);
    }
    final generated = _generateKey();
    await secretStore.writeSecret(
      dataEncryptionKeySecretId,
      base64Url.encode(generated),
    );
    return generated;
  }

  /// دوران المفاتيح خارج نطاق هذه المرحلة.
  static const keyRotationSupported = false;

  Uint8List _generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyLengthBytes, (_) => random.nextInt(256)),
    );
  }
}
