/// =============================================================
/// Lifex-AI — دورة حياة مفاتيح HealthObservation
/// Rotation + Recovery + Retention/Revocation/Archival
/// المفاتيح فقط في SecureSecretStore — بلا تخمين، بلا plaintext fallback.
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_lifecycle;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../security/secure_secret_store.dart';
import 'health_observation_cipher.dart';
import 'health_observation_key_reference_index.dart';
import 'health_observation_key_retention_policy.dart';
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
  HealthObservationKeyLifecycle({
    required this.secretStore,
    this.retentionPolicy = const HealthObservationKeyRetentionPolicy(),
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const lifecycleId = 'HealthObservationKeyLifecycle';
  static const keyLengthBytes = 32;

  /// معرّفات أسرار — ليست قيم مفاتيح.
  static const currentKeyIdSecretId =
      'lifex.health_observation.current_key_id';
  static const dekSecretPrefix = 'lifex.health_observation.dek.';
  static const metaSecretPrefix = 'lifex.health_observation.meta.';
  static const registrySecretId = 'lifex.health_observation.key_registry';
  static const legacyDekSecretId = 'lifex.health_observation.dek.v1';
  static const legacyKeyId = 'k1';

  final SecureSecretStore secretStore;
  final HealthObservationKeyRetentionPolicy retentionPolicy;
  final DateTime Function() _clock;

  static String dekSecretIdFor(String keyId) => '$dekSecretPrefix$keyId';
  static String metaSecretIdFor(String keyId) => '$metaSecretPrefix$keyId';

  /// يضمن وجود مفتاح حالي؛ يرحّل dek.v1 → k1 إن وُجد بشكل موثوق.
  Future<HealthObservationDek> ensureCurrentKey() async {
    await _migrateLegacyDekIfNeeded();
    final currentId = await secretStore.readSecret(currentKeyIdSecretId);
    if (currentId != null && currentId.isNotEmpty) {
      return requireKeyForEncrypt(currentId);
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

  Future<HealthObservationDek> requireKeyForEncrypt(String keyId) async {
    final meta = await requireMetadata(keyId);
    final decision = retentionPolicy.evaluateEncrypt(meta);
    if (!decision.allowed) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: decision.reasonCode,
        message: decision.messageAr,
      );
    }
    return requireKey(keyId);
  }

  Future<HealthObservationDek> requireKeyForDecrypt(String keyId) async {
    final meta = await requireMetadata(keyId);
    final decision = retentionPolicy.evaluateDecrypt(meta);
    if (!decision.allowed) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: decision.reasonCode,
        message: decision.messageAr,
      );
    }
    return requireKey(keyId);
  }

  /// مفتاح legacy لـ LIFEXHOB1 فقط — لا تخمين مفاتيح أخرى.
  Future<HealthObservationDek> requireLegacyHob1Key() async {
    await _migrateLegacyDekIfNeeded();
    return requireKeyForDecrypt(legacyKeyId);
  }

  Future<HealthObservationDek> mintNewKey({String? preferredId}) async {
    final keyId = preferredId ?? await _nextKeyId();
    final existing = await secretStore.readSecret(dekSecretIdFor(keyId));
    if (existing != null && existing.isNotEmpty) {
      throw StateError('DEK slot already occupied for $keyId');
    }
    final now = _clock();
    final bytes = _generateKey();
    await secretStore.writeSecret(
      dekSecretIdFor(keyId),
      base64Url.encode(bytes),
    );
    final meta = HealthObservationKeyMetadata(
      keyId: keyId,
      version: _versionFromKeyId(keyId),
      status: HealthObservationKeyStatus.activeForDecryption,
      createdAt: now,
    );
    await _saveMetadata(meta);
    await _registerKeyId(keyId);
    return HealthObservationDek(keyId: keyId, bytes: bytes);
  }

  Future<void> promoteCurrent(String keyId) async {
    await requireKey(keyId);
    final previousId = await peekCurrentKeyId();
    final now = _clock();
    if (previousId != null &&
        previousId.isNotEmpty &&
        previousId != keyId) {
      final prevMeta = await loadMetadata(previousId);
      if (prevMeta != null &&
          prevMeta.status == HealthObservationKeyStatus.current) {
        await _saveMetadata(
          prevMeta.copyWith(
            status: HealthObservationKeyStatus.activeForDecryption,
          ),
        );
      }
    }
    final meta = await requireMetadata(keyId);
    await _saveMetadata(
      meta.copyWith(
        status: HealthObservationKeyStatus.current,
        activatedAt: meta.activatedAt ?? now,
      ),
    );
    await secretStore.writeSecret(currentKeyIdSecretId, keyId);
  }

  Future<String?> peekCurrentKeyId() =>
      secretStore.readSecret(currentKeyIdSecretId);

  Future<HealthObservationKeyMetadata?> loadMetadata(String keyId) async {
    final raw = await secretStore.readSecret(metaSecretIdFor(keyId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return HealthObservationKeyMetadata.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<HealthObservationKeyMetadata> requireMetadata(String keyId) async {
    final meta = await loadMetadata(keyId);
    if (meta != null) return meta;
    // توافق: مفتاح موجود بلا metadata → ACTIVE_FOR_DECRYPTION أو CURRENT.
    final dek = await secretStore.readSecret(dekSecretIdFor(keyId));
    if (dek == null || dek.isEmpty) {
      throw HealthObservationKeyMissingException(
        keyId,
        'Key metadata and DEK both missing.',
      );
    }
    final current = await peekCurrentKeyId();
    final status = current == keyId
        ? HealthObservationKeyStatus.current
        : HealthObservationKeyStatus.activeForDecryption;
    final synthesized = HealthObservationKeyMetadata(
      keyId: keyId,
      version: _versionFromKeyId(keyId),
      status: status,
      createdAt: _clock(),
      activatedAt:
          status == HealthObservationKeyStatus.current ? _clock() : null,
    );
    await _saveMetadata(synthesized);
    await _registerKeyId(keyId);
    return synthesized;
  }

  /// تقاعد: لا كتابة؛ فك مسموح.
  Future<HealthObservationKeyMetadata> retireKey(String keyId) async {
    final meta = await requireMetadata(keyId);
    if (meta.status == HealthObservationKeyStatus.current) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: HealthObservationKeyRetentionDecision.keyNotCurrent,
        message: 'لا يُتقاعد المفتاح الحالي قبل Rotation إلى مفتاح أحدث.',
      );
    }
    if (meta.status == HealthObservationKeyStatus.revoked ||
        meta.status == HealthObservationKeyStatus.archived) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: 'INVALID_TRANSITION',
        message: 'لا انتقال من ${meta.status.name} إلى RETIRED.',
      );
    }
    final updated = meta.copyWith(
      status: HealthObservationKeyStatus.retired,
      retiredAt: _clock(),
    );
    await _saveMetadata(updated);
    return updated;
  }

  /// إلغاء: يمنع التشفير والفك — يعتمد على Reference Index + اتساق.
  Future<HealthObservationKeyMetadata> revokeKey({
    required String keyId,
    required HealthObservationPersistentStore inner,
    required HealthObservationKeyReferenceIndex referenceIndex,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    final aes = cipher ?? AesGcmHealthObservationCipher();
    await referenceIndex.requireConsistent(
      cipherTextInner: inner,
      cipher: aes,
    );
    final meta = await requireMetadata(keyId);
    if (meta.status == HealthObservationKeyStatus.current) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: HealthObservationKeyRetentionDecision.keyNotCurrent,
        message: 'لا يُلغى المفتاح الحالي وهو CURRENT.',
      );
    }
    if (await referenceIndex.hasReferences(keyId)) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: HealthObservationKeyRetentionDecision.keyStillReferenced,
        message:
            'لا يُلغى المفتاح بينما Reference Index يثبت اعتماداً — '
            'أعد التشفير أولاً.',
      );
    }
    final updated = meta.copyWith(
      status: HealthObservationKeyStatus.revoked,
      revokedAt: _clock(),
    );
    await _saveMetadata(updated);
    return updated;
  }

  /// أرشفة مفتاح: غير متاح للعمليات (ليس حذفاً).
  Future<HealthObservationKeyMetadata> archiveKey({
    required String keyId,
    required HealthObservationPersistentStore inner,
    required HealthObservationKeyReferenceIndex referenceIndex,
    AesGcmHealthObservationCipher? cipher,
    String? note,
  }) async {
    final aes = cipher ?? AesGcmHealthObservationCipher();
    await referenceIndex.requireConsistent(
      cipherTextInner: inner,
      cipher: aes,
    );
    final meta = await requireMetadata(keyId);
    if (meta.status == HealthObservationKeyStatus.current) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: HealthObservationKeyRetentionDecision.keyNotCurrent,
        message: 'لا تُؤرشف المفتاح الحالي.',
      );
    }
    if (await referenceIndex.hasReferences(keyId)) {
      throw HealthObservationKeyPolicyException(
        keyId: keyId,
        reasonCode: HealthObservationKeyRetentionDecision.keyStillReferenced,
        message:
            'لا تُؤرشف المفتاح بينما Reference Index يثبت اعتماداً — '
            'أعد التشفير أولاً.',
      );
    }
    final updated = meta.copyWith(
      status: HealthObservationKeyStatus.archived,
      archivedAt: _clock(),
      archivalNote: note ?? 'archived-unavailable',
    );
    await _saveMetadata(updated);
    return updated;
  }

  /// محاولة إنهاء الاحتفاظ / حذف مادة المفتاح — بلا حذف تلقائي غير آمن.
  Future<HealthObservationKeyRetentionDecision> attemptPurgeKeyMaterial({
    required String keyId,
    required HealthObservationPersistentStore inner,
    required HealthObservationKeyReferenceIndex referenceIndex,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    final aes = cipher ?? AesGcmHealthObservationCipher();
    try {
      await referenceIndex.requireConsistent(
        cipherTextInner: inner,
        cipher: aes,
      );
    } on HealthObservationKeyIndexInconsistentException {
      return const HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode: HealthObservationKeyRetentionDecision.indexInconsistent,
        messageAr:
            'ممنوع PURGE: فهرس الاعتماد غير متسق (INDEX_INCONSISTENT).',
      );
    }
    final meta = await requireMetadata(keyId);
    final referenced = await referenceIndex.hasReferences(keyId);
    final decision = retentionPolicy.evaluatePurge(
      meta: meta,
      stillReferencedByCiphertext: referenced,
    );
    if (!decision.allowed) {
      return decision;
    }
    await secretStore.deleteSecret(dekSecretIdFor(keyId));
    // metadata تبقى كسجل حالة بلا DEK.
    return decision;
  }

  /// فحص اعتماد عبر الفهرس بعد التحقق من الاتساق (للاختبارات/التشخيص).
  Future<bool> isKeyReferencedByIndex({
    required HealthObservationKeyReferenceIndex referenceIndex,
    required HealthObservationPersistentStore inner,
    required String keyId,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    await referenceIndex.requireConsistent(
      cipherTextInner: inner,
      cipher: cipher ?? AesGcmHealthObservationCipher(),
    );
    return referenceIndex.hasReferences(keyId);
  }

  /// توافق خلفي: فحص مباشر للمغلف الحالي — يُفضّل Reference Index.
  Future<bool> isKeyReferencedByStore({
    required HealthObservationPersistentStore inner,
    required String keyId,
  }) async {
    final raw = await inner.readRaw();
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final parsed = AesGcmHealthObservationCipher().parse(raw);
      if (parsed.keyId != null && parsed.keyId!.isNotEmpty) {
        return parsed.keyId == keyId;
      }
      if (parsed.isLegacyHob1) {
        return keyId == legacyKeyId;
      }
    } on HealthObservationCipherException {
      // ciphertext تالف — لا نعتبر الاعتماد مثبتاً للحذف.
      return true;
    }
    return true;
  }

  /// Rotation: decrypt → validate → re-encrypt → persist → re-read → verify
  /// ثم نقل المراجع old→new ثم promote.
  Future<HealthObservationKeyRotationResult> rotateEncryptedStore({
    required HealthObservationPersistentStore inner,
    required AesGcmHealthObservationCipher cipher,
    required HealthObservationKeyReferenceIndex referenceIndex,
  }) async {
    final previous = await ensureCurrentKey();
    final next = await mintNewKey();

    final backupEnvelope = await inner.readRaw();
    if (backupEnvelope == null || backupEnvelope.trim().isEmpty) {
      await promoteCurrent(next.keyId);
      await referenceIndex.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
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
      // نقل المراجع فقط بعد نجاح verify الكامل.
      await referenceIndex.moveEnvelopeReference(
        envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
        fromKeyId: previous.keyId,
        toKeyId: next.keyId,
        formatVersion: parsed.format,
        contentFingerprint:
            HealthObservationKeyReferenceIndexSupport.fingerprintOf(reread),
      );
      await promoteCurrent(next.keyId);
      return HealthObservationKeyRotationResult(
        previousKeyId: previous.keyId,
        newKeyId: next.keyId,
        rewroteCiphertext: true,
      );
    } catch (e) {
      await inner.writeRaw(backupEnvelope);
      // لا نقل مراجع ولا promote — الفهرس يبقى على الحالة الفعلية السابقة.
      rethrow;
    }
  }

  /// Recovery: keyId من المغلف + فحص سياسة الحالة.
  Future<String> decryptWithRecovery({
    required String envelope,
    required AesGcmHealthObservationCipher cipher,
  }) async {
    final parsed = cipher.parse(envelope);
    final HealthObservationDek dek;
    if (parsed.keyId != null && parsed.keyId!.isNotEmpty) {
      dek = await requireKeyForDecrypt(parsed.keyId!);
    } else if (parsed.isLegacyHob1) {
      dek = await requireLegacyHob1Key();
    } else {
      throw HealthObservationCipherException(
        'Envelope missing key id and is not a trusted legacy format',
      );
    }
    return cipher.decryptEnvelope(envelope: parsed, keyBytes: dek.bytes);
  }

  Future<void> _saveMetadata(HealthObservationKeyMetadata meta) async {
    await secretStore.writeSecret(
      metaSecretIdFor(meta.keyId),
      jsonEncode(meta.toJson()),
    );
  }

  Future<void> _registerKeyId(String keyId) async {
    final raw = await secretStore.readSecret(registrySecretId);
    final ids = <String>{};
    if (raw != null && raw.isNotEmpty) {
      ids.addAll(raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    ids.add(keyId);
    await secretStore.writeSecret(registrySecretId, ids.join(','));
  }

  Future<void> _migrateLegacyDekIfNeeded() async {
    final currentId = await secretStore.readSecret(currentKeyIdSecretId);
    if (currentId != null && currentId.isNotEmpty) {
      // تأكد من metadata للمفتاح الحالي إن وُجد.
      await requireMetadata(currentId);
      return;
    }

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
    final now = _clock();
    await _saveMetadata(
      HealthObservationKeyMetadata(
        keyId: legacyKeyId,
        version: 1,
        status: HealthObservationKeyStatus.current,
        createdAt: now,
        activatedAt: now,
      ),
    );
    await _registerKeyId(legacyKeyId);
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

  int _versionFromKeyId(String keyId) {
    final m = RegExp(r'^k(\d+)$').firstMatch(keyId);
    if (m != null) return int.parse(m.group(1)!);
    return 0;
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
