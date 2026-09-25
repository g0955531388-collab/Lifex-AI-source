/// =============================================================
/// Lifex-AI — Encrypted HealthObservation Persistent Store
/// يلف FileHealthObservationStore بتشفير at-rest + key lifecycle + ref index.
/// =============================================================
library lifex_ai.core.health_data.encrypted_health_observation_store;

import 'health_observation_cipher.dart';
import 'health_observation_key_lifecycle.dart';
import 'health_observation_key_reference_index.dart';
import 'health_observation_key_retention_policy.dart';
import 'health_observation_key_vault.dart';
import 'file_health_observation_store.dart';
import 'health_observation_repository.dart';

/// مخزن دائم مشفّر — التنفيذ الإنتاجي لـ HealthObservation persistence.
class EncryptedHealthObservationStore
    implements HealthObservationPersistentStore {
  EncryptedHealthObservationStore({
    required this.inner,
    required HealthObservationKeyVault keyVault,
    AesGcmHealthObservationCipher? cipher,
    HealthObservationKeyLifecycle? lifecycle,
    HealthObservationKeyReferenceIndex? referenceIndex,
  })  : keyVault = keyVault,
        cipher = cipher ?? AesGcmHealthObservationCipher(),
        lifecycle = lifecycle ?? keyVault.lifecycle,
        referenceIndex = referenceIndex ??
            _defaultReferenceIndex(inner);

  static HealthObservationKeyReferenceIndex _defaultReferenceIndex(
    HealthObservationPersistentStore inner,
  ) {
    if (inner is FileHealthObservationStore) {
      return DeferredFileHealthObservationKeyReferenceIndex(fileStore: inner);
    }
    return InMemoryHealthObservationKeyReferenceIndex();
  }

  /// مصنع صريح لفهرس ملفّي بجانب FileHealthObservationStore.
  static Future<EncryptedHealthObservationStore> withFileReferenceIndex({
    required FileHealthObservationStore inner,
    required HealthObservationKeyVault keyVault,
    AesGcmHealthObservationCipher? cipher,
    HealthObservationKeyLifecycle? lifecycle,
  }) async {
    final indexFile = await inner.siblingFile(
      FileHealthObservationKeyReferenceIndex.fileName,
    );
    return EncryptedHealthObservationStore(
      inner: inner,
      keyVault: keyVault,
      cipher: cipher,
      lifecycle: lifecycle,
      referenceIndex: FileHealthObservationKeyReferenceIndex(
        indexFile: indexFile,
      ),
    );
  }

  static const storeName = 'EncryptedHealthObservationStore';

  /// الطبقة الداخلية (عادة FileHealthObservationStore) تخزّن ciphertext فقط.
  final HealthObservationPersistentStore inner;
  final HealthObservationKeyVault keyVault;
  final HealthObservationKeyLifecycle lifecycle;
  final AesGcmHealthObservationCipher cipher;
  final HealthObservationKeyReferenceIndex referenceIndex;

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
    // تحديث الفهرس بعد نجاح الكتابة فقط — معرفات سجلات بلا قيم صحية.
    final records =
        HealthObservationKeyReferenceIndexSupport.recordStatusesFromPlaintext(
      contents,
    );
    await referenceIndex.upsertAfterPersist(
      keyId: current.keyId,
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      formatVersion: AesGcmHealthObservationCipher.formatHob2,
      contentFingerprint:
          HealthObservationKeyReferenceIndexSupport.fingerprintOf(envelope),
      recordStatuses: records,
    );
  }

  /// دوران مفتاح آمن مع استعادة عند الفشل + نقل المراجع بعد verify.
  Future<HealthObservationKeyRotationResult> rotateKeys() {
    return lifecycle.rotateEncryptedStore(
      inner: inner,
      cipher: cipher,
      referenceIndex: referenceIndex,
    );
  }

  Future<HealthObservationKeyMetadata> retirePreviousKey(String keyId) {
    return lifecycle.retireKey(keyId);
  }

  Future<HealthObservationKeyMetadata> revokeKey(String keyId) {
    return lifecycle.revokeKey(
      keyId: keyId,
      inner: inner,
      referenceIndex: referenceIndex,
      cipher: cipher,
    );
  }

  Future<HealthObservationKeyMetadata> archiveKey(
    String keyId, {
    String? note,
  }) {
    return lifecycle.archiveKey(
      keyId: keyId,
      inner: inner,
      referenceIndex: referenceIndex,
      cipher: cipher,
      note: note,
    );
  }

  Future<HealthObservationKeyRetentionDecision> attemptPurgeKey(String keyId) {
    return lifecycle.attemptPurgeKeyMaterial(
      keyId: keyId,
      inner: inner,
      referenceIndex: referenceIndex,
      cipher: cipher,
    );
  }

  Future<HealthObservationKeyIndexConsistencyReport> verifyReferenceIndex() {
    return referenceIndex.verifyConsistency(
      cipherTextInner: inner,
      cipher: cipher,
    );
  }

  Future<HealthObservationKeyIndexRebuildResult> rebuildReferenceIndex() {
    return referenceIndex.rebuildFromStore(
      cipherTextInner: inner,
      lifecycle: lifecycle,
      cipher: cipher,
    );
  }

  /// بعد حذف سجل ناجح من المستودع — أزل مرجعه فقط (ARCHIVE لا يستدعي هذا).
  Future<void> notifyRecordDeleted(String observationId) {
    return referenceIndex.removeRecordReference(
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      recordId: observationId,
    );
  }
}

/// فهرس ملفّي مؤجّل — يُنشأ بجانب FileHealthObservationStore دون Composition.
class DeferredFileHealthObservationKeyReferenceIndex
    implements HealthObservationKeyReferenceIndex {
  DeferredFileHealthObservationKeyReferenceIndex({required this.fileStore});

  final FileHealthObservationStore fileStore;
  FileHealthObservationKeyReferenceIndex? _delegate;

  Future<FileHealthObservationKeyReferenceIndex> _ensure() async {
    if (_delegate != null) return _delegate!;
    final file = await fileStore.siblingFile(
      FileHealthObservationKeyReferenceIndex.fileName,
    );
    _delegate = FileHealthObservationKeyReferenceIndex(indexFile: file);
    return _delegate!;
  }

  @override
  Future<List<HealthObservationKeyReference>> allReferences() async =>
      (await _ensure()).allReferences();

  @override
  Future<List<HealthObservationKeyReference>> referencesFor(
    String keyId,
  ) async =>
      (await _ensure()).referencesFor(keyId);

  @override
  Future<bool> hasReferences(String keyId) async =>
      (await _ensure()).hasReferences(keyId);

  @override
  Future<bool> hasLiveRecordReferences(String keyId) async =>
      (await _ensure()).hasLiveRecordReferences(keyId);

  @override
  Future<void> upsertAfterPersist({
    required String keyId,
    required String envelopeId,
    required String formatVersion,
    required String contentFingerprint,
    required Map<String, HealthObservationKeyReferenceStatus> recordStatuses,
  }) async =>
      (await _ensure()).upsertAfterPersist(
        keyId: keyId,
        envelopeId: envelopeId,
        formatVersion: formatVersion,
        contentFingerprint: contentFingerprint,
        recordStatuses: recordStatuses,
      );

  @override
  Future<void> moveEnvelopeReference({
    required String envelopeId,
    required String fromKeyId,
    required String toKeyId,
    required String formatVersion,
    required String contentFingerprint,
  }) async =>
      (await _ensure()).moveEnvelopeReference(
        envelopeId: envelopeId,
        fromKeyId: fromKeyId,
        toKeyId: toKeyId,
        formatVersion: formatVersion,
        contentFingerprint: contentFingerprint,
      );

  @override
  Future<void> removeRecordReference({
    required String envelopeId,
    required String recordId,
  }) async =>
      (await _ensure()).removeRecordReference(
        envelopeId: envelopeId,
        recordId: recordId,
      );

  @override
  Future<void> clearEnvelopeReferences(String envelopeId) async =>
      (await _ensure()).clearEnvelopeReferences(envelopeId);

  @override
  Future<HealthObservationKeyIndexConsistencyReport> verifyConsistency({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) async =>
      (await _ensure()).verifyConsistency(
        cipherTextInner: cipherTextInner,
        cipher: cipher,
      );

  @override
  Future<void> requireConsistent({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) async =>
      (await _ensure()).requireConsistent(
        cipherTextInner: cipherTextInner,
        cipher: cipher,
      );

  @override
  Future<HealthObservationKeyIndexRebuildResult> rebuildFromStore({
    required HealthObservationPersistentStore cipherTextInner,
    required HealthObservationKeyLifecycle lifecycle,
    required AesGcmHealthObservationCipher cipher,
  }) async =>
      (await _ensure()).rebuildFromStore(
        cipherTextInner: cipherTextInner,
        lifecycle: lifecycle,
        cipher: cipher,
      );
}
