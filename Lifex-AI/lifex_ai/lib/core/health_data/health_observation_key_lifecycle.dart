/// =============================================================
/// Lifex-AI — دورة حياة مفاتيح HealthObservation (Rotation + Recovery)
/// المفاتيح فقط في SecureSecretStore — بلا تخمين، بلا plaintext fallback.
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_lifecycle;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../security/secure_secret_store.dart';
import 'health_observation_cipher.dart';
import 'health_observation_repository.dart';

/// مفتاح بيانات مع معرّف إصدار — ليست قيمة المفتاح في المصدر.
class HealthObservationDek {
  const HealthObservationDek({
    required this.keyId,
    required this.bytes,
  });

  final String keyId;
  final Uint8List bytes;
}

/// نتيجة دوران مكتمل بعد verify.
class HealthObservationKeyRotationResult {
  const HealthObservationKeyRotationResult({
    required this.previousKeyId,
    required this.newKeyId,
    required this.rewroteCiphertext,
  });

  final String previousKeyId;
  final String newKeyId;
  final bool rewroteCiphertext;
}

/// مفتاح مطلوب مفقود — خطأ واضح بلا كشف بيانات.
class HealthObservationKeyMissingException implements Exception {
  HealthObservationKeyMissingException(this.keyId, this.message);
  final String keyId;
  final String message;

  @override
  String toString() =>
      'HealthObservationKeyMissingException($keyId): $message';
}

/// إدارة دورة حياة DEK عبر SecureSecretStore الحالي فقط.
class HealthObservationKeyLifecycle {
  HealthObservationKeyLifecycle({required this.secretStore});

  static const lifecycleId = 'HealthObservationKeyLifecycle';
  static const keyLengthBytes = 32;

  /// معرّفات أسرار — ليست قيم مفاتيح.
  static const currentKeyIdSecretId =
      'lifex.health_observation.current_key_id';
  static const dekSecretPrefix = 'lifex.health_observation.dek.';
  static const legacyDekSecretId = 'lifex.health_observation.dek.v1';
  static const legacyKeyId = 'k1';

  final SecureSecretStore secretStore;

  static String dekSecretIdFor(String keyId) => '$dekSecretPrefix$keyId';

  /// يضمن وجود مفتاح حالي؛ يرحّل dek.v1 → k1 إن وُجد بشكل موثوق.
  Future<HealthObservationDek> ensureCurrentKey() async {
    await _migrateLegacyDekIfNeeded();
    final currentId = await secretStore.readSecret(currentKeyIdSecretId);
    if (currentId != null && currentId.isNotEmpty) {
      return requireKey(currentId);
    }
    final minted = await mintNewKey(preferredId: legacyKeyId);
    await promoteCurrent(minted.keyId);
    return minted;
  }

  Future<HealthObservationDek> requireKey(String keyId) async {
    final raw = await secretStore.readSecret(dekSecretIdFor(keyId));
    if (raw == null || raw.isEmpty) {
      throw HealthObservationKeyMissingException(
        keyId,
        'Required DEK is missing from SecureSecretStore — '
        'no plaintext fallback and no auto-mint for recovery.',
      );
    }
    final bytes = base64Url.decode(raw);
    if (bytes.length != keyLengthBytes) {
      throw StateError('HealthObservation DEK length invalid for $keyId');
    }
    return HealthObservationDek(
      keyId: keyId,
      bytes: Uint8List.fromList(bytes),
    );
  }

  /// مفتاح legacy لـ LIFEXHOB1 فقط — لا تخمين مفاتيح أخرى.
  Future<HealthObservationDek> requireLegacyHob1Key() async {
    await _migrateLegacyDekIfNeeded();
    return requireKey(legacyKeyId);
  }

  Future<HealthObservationDek> mintNewKey({String? preferredId}) async {
    final keyId = preferredId ?? await _nextKeyId();
    final existing = await secretStore.readSecret(dekSecretIdFor(keyId));
    if (existing != null && existing.isNotEmpty) {
      throw StateError('DEK slot already occupied for $keyId');
    }
    final bytes = _generateKey();
    await secretStore.writeSecret(
      dekSecretIdFor(keyId),
      base64Url.encode(bytes),
    );
    return HealthObservationDek(keyId: keyId, bytes: bytes);
  }

  Future<void> promoteCurrent(String keyId) async {
    await requireKey(keyId);
    await secretStore.writeSecret(currentKeyIdSecretId, keyId);
  }

  Future<String?> peekCurrentKeyId() =>
      secretStore.readSecret(currentKeyIdSecretId);

  /// Rotation: decrypt → validate → re-encrypt → persist → re-read → verify
  /// ثم فقط promote. المفتاح القديم يبقى للاسترداد.
  Future<HealthObservationKeyRotationResult> rotateEncryptedStore({
    required HealthObservationPersistentStore inner,
    required AesGcmHealthObservationCipher cipher,
  }) async {
    final previous = await ensureCurrentKey();
    final next = await mintNewKey();

    final backupEnvelope = await inner.readRaw();
    if (backupEnvelope == null || backupEnvelope.trim().isEmpty) {
      await promoteCurrent(next.keyId);
      return HealthObservationKeyRotationResult(
        previousKeyId: previous.keyId,
        newKeyId: next.keyId,
        rewroteCiphertext: false,
      );
    }

    final plaintext = await decryptWithRecovery(
      envelope: backupEnvelope,
      cipher: cipher,
    );
    _validatePayload(plaintext);

    final newEnvelope = await cipher.encrypt(
      plaintext: plaintext,
      keyBytes: next.bytes,
      keyId: next.keyId,
    );

    try {
      await inner.writeRaw(newEnvelope);
      final reread = await inner.readRaw();
      if (reread == null) {
        throw StateError('Rotation verify failed: empty re-read');
      }
      final verified = await cipher.decrypt(
        envelope: reread,
        keyBytes: next.bytes,
      );
      if (verified != plaintext) {
        throw StateError('Rotation verify failed: plaintext mismatch');
      }
      final parsed = cipher.parse(reread);
      if (parsed.keyId != next.keyId) {
        throw StateError('Rotation verify failed: keyId not updated');
      }
      await promoteCurrent(next.keyId);
      return HealthObservationKeyRotationResult(
        previousKeyId: previous.keyId,
        newKeyId: next.keyId,
        rewroteCiphertext: true,
      );
    } catch (e) {
      // استعادة المغلف السابق — لا فقدان بيانات.
      await inner.writeRaw(backupEnvelope);
      rethrow;
    }
  }

  /// Recovery: استخدم keyId من المغلف؛ HOB1 → k1 فقط إن وُجد.
  Future<String> decryptWithRecovery({
    required String envelope,
    required AesGcmHealthObservationCipher cipher,
  }) async {
    final parsed = cipher.parse(envelope);
    final HealthObservationDek dek;
    if (parsed.keyId != null && parsed.keyId!.isNotEmpty) {
      dek = await requireKey(parsed.keyId!);
    } else if (parsed.isLegacyHob1) {
      dek = await requireLegacyHob1Key();
    } else {
      throw HealthObservationCipherException(
        'Envelope missing key id and is not a trusted legacy format',
      );
    }
    return cipher.decryptEnvelope(envelope: parsed, keyBytes: dek.bytes);
  }

  Future<void> _migrateLegacyDekIfNeeded() async {
    final currentId = await secretStore.readSecret(currentKeyIdSecretId);
    if (currentId != null && currentId.isNotEmpty) return;

    final legacy = await secretStore.readSecret(legacyDekSecretId);
    if (legacy == null || legacy.isEmpty) return;

    final bytes = base64Url.decode(legacy);
    if (bytes.length != keyLengthBytes) {
      throw StateError(
        'Legacy DEK length invalid — refusing unreliable migration',
      );
    }
    final k1Slot = await secretStore.readSecret(dekSecretIdFor(legacyKeyId));
    if (k1Slot == null || k1Slot.isEmpty) {
      await secretStore.writeSecret(dekSecretIdFor(legacyKeyId), legacy);
    }
    await secretStore.writeSecret(currentKeyIdSecretId, legacyKeyId);
  }

  Future<String> _nextKeyId() async {
    var n = 1;
    while (true) {
      final id = 'k$n';
      final existing = await secretStore.readSecret(dekSecretIdFor(id));
      if (existing == null || existing.isEmpty) return id;
      n++;
      if (n > 10000) {
        throw StateError('Unable to allocate new HealthObservation key id');
      }
    }
  }

  void _validatePayload(String plaintext) {
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map) {
      throw StateError(
        'Rotation aborted: decrypted payload is not a valid map',
      );
    }
  }

  Uint8List _generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyLengthBytes, (_) => random.nextInt(256)),
    );
  }
}
