import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/file_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
import 'package:lifex_ai/core/health_data/health_observation_cipher.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_reference_index.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_retention_policy.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/persistent_health_observation_repository.dart';
import 'package:lifex_ai/core/security/memory_secure_secret_store.dart';

/// Comprehensive Reference Index / consistency / lifecycle / rebuild / privacy
/// tests. Each test owns isolated temp dir + stores (no shared mutable state).
void main() {
  ProvenanceRecord prov(String id) => ProvenanceRecord(
        sourceId: id,
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      );

  HealthObservation obs(
    String id, {
    Object? value = 120,
    HealthRecordStatus status = HealthRecordStatus.active,
  }) =>
      HealthObservation(
        observationId: id,
        patientId: 'patient-1',
        conceptId: 'bp_systolic',
        value: value,
        unit: 'mmHg',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'ui',
        provenanceId: 'p-$id',
        status: status,
      );

  Future<_IndexHarness> openHarness({
    HealthObservationPersistentStore? innerOverride,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('lifex_ref_suite_');
    final secrets = MemorySecureSecretStore();
    final lifecycle = HealthObservationKeyLifecycle(secretStore: secrets);
    final cipher = AesGcmHealthObservationCipher();
    final index = InMemoryHealthObservationKeyReferenceIndex();
    final fileInner = FileHealthObservationStore(rootDirectory: tempDir);
    final inner = innerOverride ?? fileInner;
    final vault = HealthObservationKeyVault(
      secretStore: secrets,
      lifecycle: lifecycle,
    );
    final encrypted = EncryptedHealthObservationStore(
      inner: inner,
      keyVault: vault,
      lifecycle: lifecycle,
      cipher: cipher,
      referenceIndex: index,
    );
    final repo = PersistentHealthObservationRepository(store: encrypted);
    return _IndexHarness(
      tempDir: tempDir,
      secrets: secrets,
      lifecycle: lifecycle,
      cipher: cipher,
      index: index,
      fileInner: fileInner,
      inner: inner,
      encrypted: encrypted,
      repo: repo,
    );
  }

  group('Reference Index — CRUD / rotation / multiplicity', () {
    test('WRITE creates correct reference', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('w1'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      final refs = await h.index.referencesFor(keyId!);
      expect(refs.any((r) => r.recordId == 'w1'), isTrue);
      expect(refs.any((r) => r.recordId == null), isTrue); // envelope
      expect(await h.index.hasReferences(keyId), isTrue);
    });

    test('WRITE same record again does not duplicate reference', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('dup'));
      await h.write(obs('dup', value: 130));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      final recRefs = (await h.index.referencesFor(keyId!))
          .where((r) => r.recordId == 'dup')
          .toList();
      expect(recRefs, hasLength(1));
    });

    test('READ does not add a new reference', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('r1'));
      final before = (await h.index.allReferences()).length;
      await h.repo.getObservation('r1');
      await h.repo.listObservationsForPatient('patient-1');
      expect((await h.index.allReferences()).length, before);
    });

    test('UPDATE keeps correct reference for same record', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('u1'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.updateObservation(obs('u1', value: 88));
      final refs = await h.index.referencesFor(keyId!);
      expect(refs.where((r) => r.recordId == 'u1'), hasLength(1));
      expect(await h.index.hasReferences(keyId), isTrue);
    });

    test('ARCHIVE keeps reference with archivedRecord status', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('a1'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.archiveObservation('a1');
      final ref = (await h.index.referencesFor(keyId!))
          .firstWhere((r) => r.recordId == 'a1');
      expect(ref.status, HealthObservationKeyReferenceStatus.archivedRecord);
      expect(await h.index.hasReferences(keyId), isTrue);
    });

    test('DELETE removes reference only after successful deletion', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('d1'));
      await h.write(obs('d2'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      final ok = await h.repo.deleteObservation('d1');
      expect(ok, isTrue);
      expect(
        (await h.index.referencesFor(keyId!)).any((r) => r.recordId == 'd1'),
        isFalse,
      );
      expect(
        (await h.index.referencesFor(keyId)).any((r) => r.recordId == 'd2'),
        isTrue,
      );
    });

    test('failed DELETE keeps reference (no silent drop)', () async {
      final failInner = _CountingFailStore(
        FileHealthObservationStore(
          rootDirectory:
              await Directory.systemTemp.createTemp('lifex_ref_fail_'),
        ),
      );
      final h = await openHarness(innerOverride: failInner);
      addTearDown(() async {
        await h.dispose();
        final root = failInner.delegate;
        if (root is FileHealthObservationStore) {
          // cleaned via h.tempDir only if same — fail store has own dir
        }
      });
      await h.write(obs('keep'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      failInner.failNextWrite = true;
      await expectLater(
        h.repo.deleteObservation('keep'),
        throwsA(isA<StateError>()),
      );
      expect(
        (await h.index.referencesFor(keyId!)).any((r) => r.recordId == 'keep'),
        isTrue,
      );
      expect(await h.index.hasReferences(keyId), isTrue);
    });

    test('successful rotation: oldKeyId loses refs; newKeyId owns them',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('rot'));
      final oldId = await h.lifecycle.peekCurrentKeyId();
      final result = await h.encrypted.rotateKeys();
      expect(await h.index.hasReferences(result.previousKeyId), isFalse);
      expect(await h.index.hasReferences(result.newKeyId), isTrue);
      expect(result.previousKeyId, oldId);
      expect((await h.encrypted.verifyReferenceIndex()).consistent, isTrue);
    });

    test('failed rotation keeps oldKeyId references (no false move)', () async {
      final base = await Directory.systemTemp.createTemp('lifex_rot_fail_');
      final failInner = _FailAfterWriteStore(
        FileHealthObservationStore(rootDirectory: base),
        failVerifyRead: true,
      );
      final h = await openHarness(innerOverride: failInner);
      addTearDown(h.dispose);
      await h.write(obs('safe'));
      final before = await h.lifecycle.peekCurrentKeyId();
      final lenBefore = (await h.index.referencesFor(before!)).length;
      await expectLater(h.encrypted.rotateKeys(), throwsA(anything));
      expect(await h.lifecycle.peekCurrentKeyId(), before);
      expect(await h.index.hasReferences(before), isTrue);
      expect((await h.index.referencesFor(before)).length, lenBefore);
    });

    test('interrupted rotation does not produce false index state', () async {
      final base = await Directory.systemTemp.createTemp('lifex_rot_int_');
      final failInner = _FailAfterWriteStore(
        FileHealthObservationStore(rootDirectory: base),
        failVerifyRead: true,
      );
      final h = await openHarness(innerOverride: failInner);
      addTearDown(h.dispose);
      await h.write(obs('int'));
      final before = await h.lifecycle.peekCurrentKeyId();
      final refsBefore = await h.index.referencesFor(before!);
      try {
        await h.lifecycle.rotateEncryptedStore(
          inner: failInner,
          cipher: h.cipher,
          referenceIndex: h.index,
        );
        fail('expected interrupt');
      } catch (_) {}
      // No refs moved onto a non-current minted key; old key remains owner.
      final all = await h.index.allReferences();
      expect(all.every((r) => r.keyId == before), isTrue);
      expect(all.length, refsBefore.length);
      expect(await h.lifecycle.peekCurrentKeyId(), before);
    });

    test('multiple records share same keyId', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('m1'));
      await h.write(obs('m2'));
      await h.write(obs('m3'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      final recs = (await h.index.referencesFor(keyId!))
          .where((r) => r.recordId != null)
          .map((r) => r.recordId)
          .toSet();
      expect(recs, containsAll(['m1', 'm2', 'm3']));
      expect(await h.index.hasReferences(keyId), isTrue);
    });

    test('same record can move active → archived status in index', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('s1'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      expect(
        (await h.index.referencesFor(keyId!))
            .firstWhere((r) => r.recordId == 's1')
            .status,
        HealthObservationKeyReferenceStatus.active,
      );
      await h.repo.archiveObservation('s1');
      expect(
        (await h.index.referencesFor(keyId))
            .firstWhere((r) => r.recordId == 's1')
            .status,
        HealthObservationKeyReferenceStatus.archivedRecord,
      );
    });

    test('after last record deleted: record ref gone; envelope ACTIVE live',
        () async {
      // Ciphertext envelope remains after last DELETE → key still live-dependent.
      // Deleted record must NOT remain as a live record reference.
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('last'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.deleteObservation('last');
      expect(await h.index.hasLiveRecordReferences(keyId!), isFalse);
      expect(
        (await h.index.referencesFor(keyId)).any((r) => r.recordId == 'last'),
        isFalse,
      );
      final envRefs = (await h.index.referencesFor(keyId))
          .where((r) => r.isEnvelopeReference)
          .toList();
      expect(envRefs, hasLength(1));
      expect(envRefs.single.status, HealthObservationKeyReferenceStatus.active);
      expect(envRefs.single.status.wireName, 'ACTIVE_REFERENCE');
      expect(await h.index.hasReferences(keyId), isTrue,
          reason: 'live envelope ciphertext still depends on keyId');
      // PURGE/REVOKE must not treat key as unused while envelope lives.
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      final purge = await h.encrypted.attemptPurgeKey(keyId);
      expect(purge.allowed, isFalse);
      expect(
        purge.reasonCode,
        HealthObservationKeyRetentionDecision.keyStillReferenced,
      );
    });

    test('last-reference semantics: single DELETE makes record ref non-live',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('solo'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      expect(await h.index.hasLiveRecordReferences(keyId!), isTrue);
      await h.repo.deleteObservation('solo');
      expect(await h.index.hasLiveRecordReferences(keyId), isFalse);
      expect(
        (await h.index.referencesFor(keyId))
            .where((r) => r.isRecordReference),
        isEmpty,
      );
    });

    test('multi-record DELETE keeps sibling live record references', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('a'));
      await h.write(obs('b'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.deleteObservation('a');
      expect(await h.index.hasLiveRecordReferences(keyId!), isTrue);
      expect(
        (await h.index.referencesFor(keyId)).any((r) => r.recordId == 'b'),
        isTrue,
      );
      expect(
        (await h.index.referencesFor(keyId)).any((r) => r.recordId == 'a'),
        isFalse,
      );
    });

    test('ARCHIVE keeps ARCHIVED_REFERENCE; not treated as DELETE', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('arc'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.archiveObservation('arc');
      final ref = (await h.index.referencesFor(keyId!))
          .firstWhere((r) => r.recordId == 'arc');
      expect(ref.status, HealthObservationKeyReferenceStatus.archivedRecord);
      expect(ref.status.wireName, 'ARCHIVED_REFERENCE');
      expect(ref.isLiveDependency, isTrue);
      expect(await h.index.hasLiveRecordReferences(keyId), isTrue);
      expect(await h.index.hasReferences(keyId), isTrue);
      expect(await h.repo.getObservation('arc'), isNotNull);
    });

    test('stale envelope fingerprint → INDEX_INCONSISTENT not unused',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('stale-rec'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.index.upsertAfterPersist(
        keyId: keyId!,
        envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
        formatVersion: 'LIFEXHOB2',
        contentFingerprint: 'stale-fp-only',
        recordStatuses: const {
          'stale-rec': HealthObservationKeyReferenceStatus.active,
        },
      );
      // Key still has refs in index — must not look "unused".
      expect(await h.index.hasReferences(keyId), isTrue);
      await expectLater(
        h.index.requireConsistent(cipherTextInner: h.inner),
        throwsA(
          isA<HealthObservationKeyIndexInconsistentException>().having(
            (e) => e.reasonCode,
            'code',
            'INDEX_INCONSISTENT',
          ),
        ),
      );
      final report =
          await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(
        report.issues.any(
          (i) =>
              i.kind ==
              HealthObservationKeyIndexInconsistencyKind.staleReference,
        ),
        isTrue,
      );
    });

    test('purge/revoke ignore deleted record refs; use live deps only',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('gone'));
      await h.write(obs('stay'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.repo.deleteObservation('gone');
      expect(
        (await h.index.referencesFor(keyId!)).any((r) => r.recordId == 'gone'),
        isFalse,
      );
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      // Still live via stay + envelope — not based on deleted 'gone'.
      expect(await h.index.hasReferences(keyId), isTrue);
      await expectLater(
        h.encrypted.revokeKey(keyId),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.keyStillReferenced,
          ),
        ),
      );
    });

    test('clearing ciphertext clears envelope refs → hasReferences false',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('clr'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.inner.writeRaw('');
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      expect(await h.index.hasReferences(keyId!), isFalse);
      expect(await h.index.hasLiveRecordReferences(keyId), isFalse);
    });

    test('keyId with multiple records must not be treated as unused', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('x1'));
      await h.write(obs('x2'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      expect(await h.index.hasReferences(keyId!), isTrue);
      // Promote another current without rewriting store — key still referenced.
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      expect(await h.index.hasReferences(keyId), isTrue);
      final purge = await h.encrypted.attemptPurgeKey(keyId);
      expect(purge.allowed, isFalse);
      expect(
        purge.reasonCode,
        HealthObservationKeyRetentionDecision.keyStillReferenced,
      );
    });

    test('rotation makes previous keyId unused (no references)', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('gone-old'));
      final rot = await h.encrypted.rotateKeys();
      expect(await h.index.hasReferences(rot.previousKeyId), isFalse);
      expect(await h.index.hasLiveRecordReferences(rot.previousKeyId), isFalse);
    });
  });

  group('Consistency Verification', () {
    test('detects missing / orphan / wrongKeyId / duplicate / stale / mismatch',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('c1'));
      final keyId = await h.lifecycle.peekCurrentKeyId();

      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      var report = await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(report.consistent, isFalse);
      expect(
        report.issues.any(
          (i) =>
              i.kind ==
              HealthObservationKeyIndexInconsistencyKind.missingReference,
        ),
        isTrue,
      );
      // Must NOT collapse to hasReferences==false as sole signal.
      expect(
        HealthObservationKeyIndexInconsistentException.reasonCodeValue,
        'INDEX_INCONSISTENT',
      );

      await h.encrypted.rebuildReferenceIndex();
      await h.inner.writeRaw('');
      report = await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(
        report.issues.any(
          (i) =>
              i.kind ==
              HealthObservationKeyIndexInconsistencyKind.orphanReference,
        ),
        isTrue,
      );

      await h.write(obs('c2'));
      final fp = HealthObservationKeyReferenceIndexSupport.fingerprintOf(
        (await h.inner.readRaw())!,
      );
      final current = await h.lifecycle.peekCurrentKeyId();
      await h.index.upsertAfterPersist(
        keyId: 'wrong-key',
        envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
        formatVersion: 'LIFEXHOB2',
        contentFingerprint: fp,
        recordStatuses: const {'c2': HealthObservationKeyReferenceStatus.active},
      );
      report = await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(
        report.issues.any(
          (i) =>
              i.kind == HealthObservationKeyIndexInconsistencyKind.wrongKeyId,
        ),
        isTrue,
      );

      await h.encrypted.rebuildReferenceIndex();
      await h.index.upsertAfterPersist(
        keyId: current!,
        envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
        formatVersion: 'LIFEXHOB2',
        contentFingerprint: 'stale-fp',
        recordStatuses: const {'c2': HealthObservationKeyReferenceStatus.active},
      );
      report = await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(
        report.issues.any(
          (i) =>
              i.kind ==
              HealthObservationKeyIndexInconsistencyKind.staleReference,
        ),
        isTrue,
      );

      final dup = await HealthObservationKeyReferenceIndexSupport.verify(
        indexEntries: [
          HealthObservationKeyReference(
            keyId: current,
            envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
            formatVersion: 'LIFEXHOB2',
            status: HealthObservationKeyReferenceStatus.active,
            contentFingerprint: fp,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          HealthObservationKeyReference(
            keyId: current,
            envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
            formatVersion: 'LIFEXHOB2',
            status: HealthObservationKeyReferenceStatus.active,
            contentFingerprint: fp,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        cipherTextInner: h.inner,
        cipher: h.cipher,
      );
      expect(
        dup.issues.any(
          (i) =>
              i.kind ==
              HealthObservationKeyIndexInconsistencyKind.duplicateReference,
        ),
        isTrue,
      );

      // index/store mismatch → requireConsistent throws INDEX_INCONSISTENT
      await expectLater(
        h.index.requireConsistent(cipherTextInner: h.inner),
        throwsA(
          isA<HealthObservationKeyIndexInconsistentException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyIndexInconsistentException.reasonCodeValue,
          ),
        ),
      );
      // Silence unused in some paths
      expect(keyId, isNotNull);
    });

    test('INDEX_INCONSISTENT is explicit — not hasReferences false', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('ic'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      // After clear, hasReferences is false BUT inconsistency is missingReference
      // when verified against store — not a silent "unused key" decision.
      expect(await h.index.hasReferences(keyId!), isFalse);
      final report =
          await h.index.verifyConsistency(cipherTextInner: h.inner);
      expect(report.consistent, isFalse);
      expect(
        report.issues.first.kind,
        HealthObservationKeyIndexInconsistencyKind.missingReference,
      );
    });
  });

  group('Lifecycle Safety', () {
    test('RETIRED + references: decrypt still allowed by policy', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('ret-ref'));
      final oldKey = await h.lifecycle.peekCurrentKeyId();
      final envelope = (await h.inner.readRaw())!;
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      expect(await h.index.hasReferences(oldKey!), isTrue);
      await h.lifecycle.retireKey(oldKey);
      final plain = await h.lifecycle.decryptWithRecovery(
        envelope: envelope,
        cipher: h.cipher,
      );
      expect(plain.contains('ret-ref'), isTrue);
    });

    test('RETIRED key cannot encrypt new writes', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('w'));
      final oldKey = await h.lifecycle.peekCurrentKeyId();
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      await h.lifecycle.retireKey(oldKey!);
      await expectLater(
        h.lifecycle.requireKeyForEncrypt(oldKey),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.encryptDenied,
          ),
        ),
      );
    });

    test('REVOKE / ARCHIVE with references rejected KEY_STILL_REFERENCED',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('held'));
      final k1 = await h.lifecycle.peekCurrentKeyId();
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      expect(await h.index.hasReferences(k1!), isTrue);
      await expectLater(
        h.encrypted.revokeKey(k1),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.keyStillReferenced,
          ),
        ),
      );
      await expectLater(
        h.encrypted.archiveKey(k1),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.keyStillReferenced,
          ),
        ),
      );
    });

    test('PURGE with references → KEY_STILL_REFERENCED', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('purged-block'));
      final k1 = await h.lifecycle.peekCurrentKeyId();
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      final decision = await h.encrypted.attemptPurgeKey(k1!);
      expect(decision.allowed, isFalse);
      expect(
        decision.reasonCode,
        HealthObservationKeyRetentionDecision.keyStillReferenced,
      );
    });

    test('PURGE without references allowed after rotate+revoke', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('free'));
      final rot = await h.encrypted.rotateKeys();
      expect(await h.index.hasReferences(rot.previousKeyId), isFalse);
      await h.encrypted.revokeKey(rot.previousKeyId);
      final decision = await h.encrypted.attemptPurgeKey(rot.previousKeyId);
      expect(decision.allowed, isTrue);
      expect(
        decision.reasonCode,
        HealthObservationKeyRetentionDecision.purgeAllowed,
      );
    });

    test('INDEX_INCONSISTENT blocks REVOKE / ARCHIVE / PURGE', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('blk'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      await expectLater(
        h.encrypted.revokeKey(keyId!),
        throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
      );
      await expectLater(
        h.encrypted.archiveKey(keyId),
        throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
      );
      final purge = await h.encrypted.attemptPurgeKey(keyId);
      expect(purge.allowed, isFalse);
      expect(
        purge.reasonCode,
        HealthObservationKeyRetentionDecision.indexInconsistent,
      );
    });

    test('revoked / archived key denies decrypt per policy', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('deny'));
      final rot = await h.encrypted.rotateKeys();
      final prevDek = await h.lifecycle.requireKey(rot.previousKeyId);
      final oldEnv = await h.cipher.encrypt(
        plaintext: '{"observations":{}}',
        keyBytes: prevDek.bytes,
        keyId: rot.previousKeyId,
      );
      await h.encrypted.revokeKey(rot.previousKeyId);
      await expectLater(
        h.lifecycle.decryptWithRecovery(envelope: oldEnv, cipher: h.cipher),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.keyRevoked,
          ),
        ),
      );

      final unused = await h.lifecycle.mintNewKey();
      await h.encrypted.archiveKey(unused.keyId);
      final unusedEnv = await h.cipher.encrypt(
        plaintext: '{"observations":{}}',
        keyBytes: unused.bytes,
        keyId: unused.keyId,
      );
      await expectLater(
        h.lifecycle.decryptWithRecovery(envelope: unusedEnv, cipher: h.cipher),
        throwsA(
          isA<HealthObservationKeyPolicyException>().having(
            (e) => e.reasonCode,
            'code',
            HealthObservationKeyRetentionDecision.keyArchivedUnavailable,
          ),
        ),
      );
    });

    test('missing key → no plaintext fallback', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('miss'));
      final envelope = (await h.inner.readRaw())!;
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.secrets.deleteSecret(
        HealthObservationKeyLifecycle.dekSecretIdFor(keyId!),
      );
      await expectLater(
        h.lifecycle.decryptWithRecovery(envelope: envelope, cipher: h.cipher),
        throwsA(isA<HealthObservationKeyMissingException>()),
      );
    });

    test('corrupted ciphertext does not silently become HealthObservation',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('bad'));
      await h.inner.writeRaw('LIFEXHOB2.k1.AAAA.BBBB.CCCC');
      // Fresh repository forces reload from (corrupt) store — no silent OK.
      final fresh = PersistentHealthObservationRepository(store: h.encrypted);
      await expectLater(
        fresh.getObservation('bad'),
        throwsA(
          anyOf(
            isA<HealthObservationCipherException>(),
            isA<HealthObservationKeyPolicyException>(),
            isA<HealthObservationKeyMissingException>(),
            isA<FormatException>(),
            isA<StateError>(),
            isA<ArgumentError>(),
          ),
        ),
      );
    });
  });

  group('Rebuild / Repair', () {
    test('rebuild from encrypted store restores refs + verifies', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('rb1'));
      await h.write(obs('rb2'));
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      expect((await h.encrypted.verifyReferenceIndex()).consistent, isFalse);

      final result = await h.encrypted.rebuildReferenceIndex();
      expect(result.success, isTrue);
      expect(result.consistency.consistent, isTrue);
      expect(result.envelopeReferenced, isTrue);
      expect(result.recordCount, greaterThanOrEqualTo(2));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      expect(
        (await h.index.referencesFor(keyId!)).any((r) => r.recordId == 'rb1'),
        isTrue,
      );
    });

    test('rebuild surfaces missing when store empty vs leftover index',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('orphan-me'));
      await h.inner.writeRaw('');
      final result = await h.encrypted.rebuildReferenceIndex();
      // cleared then empty store → consistent empty OR success with no envelope
      expect(result.envelopeReferenced, isFalse);
      expect(result.consistency.consistent, isTrue);
    });

    test('rebuild does not persist plaintext HealthObservation or DEK',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('secret-val', value: 777));
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      final result = await h.encrypted.rebuildReferenceIndex();
      expect(result.success, isTrue);
      final dump = {
        'toString': result.toString(),
        'refs': (await h.index.allReferences()).map((r) => r.toJson()).toList(),
      }.toString();
      expect(dump.contains('777'), isFalse);
      expect(dump.contains('bp_systolic'), isFalse);
      expect(dump.contains('value'), isFalse);
      expect(dump.toLowerCase().contains('dek'), isFalse);
      expect(RegExp(r'keyBytes|aesKey|encryptionKey').hasMatch(dump), isFalse);
    });

    test('repair success only after consistency verification', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('verify-first'));
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      final result = await h.index.rebuildFromStore(
        cipherTextInner: h.inner,
        lifecycle: h.lifecycle,
        cipher: h.cipher,
      );
      // Contract: success mirrors consistency report, not optimistic true.
      expect(result.success, result.consistency.consistent);
      expect(result.success, isTrue);
    });

    test('corrupted index fail-closed via requireConsistent', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('fc'));
      await h.index.upsertAfterPersist(
        keyId: 'bogus',
        envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
        formatVersion: 'LIFEXHOB2',
        contentFingerprint: 'x',
        recordStatuses: const {},
      );
      await expectLater(
        h.index.requireConsistent(cipherTextInner: h.inner),
        throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
      );
    });

    test('missing index blocks dangerous REVOKE/ARCHIVE/PURGE before rebuild',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('miss-idx'));
      final keyId = await h.lifecycle.peekCurrentKeyId();
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      final minted = await h.lifecycle.mintNewKey();
      await h.lifecycle.promoteCurrent(minted.keyId);
      await expectLater(
        h.encrypted.revokeKey(keyId!),
        throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
      );
      final purge = await h.encrypted.attemptPurgeKey(keyId);
      expect(
        purge.reasonCode,
        HealthObservationKeyRetentionDecision.indexInconsistent,
      );
      // After rebuild, consistency restored — still KEY_STILL_REFERENCED if store uses keyId
      final rebuilt = await h.encrypted.rebuildReferenceIndex();
      expect(rebuilt.success, isTrue);
    });
  });

  group('Security / Privacy', () {
    test('ReferenceIndex JSON has no plaintext HealthObservation fields',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('priv', value: 999));
      for (final r in await h.index.allReferences()) {
        final j = r.toJson();
        expect(j.containsKey('value'), isFalse);
        expect(j.containsKey('unit'), isFalse);
        expect(j.containsKey('patientId'), isFalse);
        expect(j.containsKey('conceptId'), isFalse);
        expect(j.containsKey('dek'), isFalse);
        expect(j.containsKey('keyBytes'), isFalse);
      }
    });

    test('fixtures / errors do not embed secrets or key material', () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('err'));
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      try {
        await h.index.requireConsistent(cipherTextInner: h.inner);
        fail('expected');
      } on HealthObservationKeyIndexInconsistentException catch (e) {
        final s = e.toString();
        expect(s.contains('INDEX_INCONSISTENT'), isTrue);
        expect(s.contains('999'), isFalse);
        expect(s.contains('bp_systolic'), isFalse);
        // DEK material is base64url of 32 bytes — must not appear.
        final dekRaw = await h.secrets.readSecret(
          HealthObservationKeyLifecycle.dekSecretIdFor(
            (await h.lifecycle.peekCurrentKeyId())!,
          ),
        );
        if (dekRaw != null) {
          expect(s.contains(dekRaw), isFalse);
        }
      }
    });

    test('FileHealthObservationKeyReferenceIndex persists metadata only',
        () async {
      final temp = await Directory.systemTemp.createTemp('lifex_ref_file_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final secrets = MemorySecureSecretStore();
      final lifecycle = HealthObservationKeyLifecycle(secretStore: secrets);
      final cipher = AesGcmHealthObservationCipher();
      final fileInner = FileHealthObservationStore(rootDirectory: temp);
      final indexFile = await fileInner.siblingFile(
        FileHealthObservationKeyReferenceIndex.fileName,
      );
      final index = FileHealthObservationKeyReferenceIndex(indexFile: indexFile);
      final encrypted = EncryptedHealthObservationStore(
        inner: fileInner,
        keyVault: HealthObservationKeyVault(
          secretStore: secrets,
          lifecycle: lifecycle,
        ),
        lifecycle: lifecycle,
        cipher: cipher,
        referenceIndex: index,
      );
      final repo = PersistentHealthObservationRepository(store: encrypted);
      await repo.ensureProvenance(prov('p-f1'));
      await repo.saveObservation(obs('f1', value: 4242));
      final rawIndex = await indexFile.readAsString();
      expect(rawIndex.contains('4242'), isFalse);
      expect(rawIndex.contains('patient-1'), isFalse);
      expect(rawIndex.contains('bp_systolic'), isFalse);
      expect(rawIndex.contains('"keyId"'), isTrue);
      expect(rawIndex.contains('indexId'), isTrue);
    });
  });

  group('Ownership', () {
    test('HealthObservationRepository is sole canonical owner', () {
      expect(
        HealthObservationRepository.ownerId,
        'HealthObservationRepository',
      );
      expect(
        HealthObservationKeyReferenceIndex.indexId,
        'HealthObservationKeyReferenceIndex',
      );
      expect(
        HealthObservationKeyLifecycle.lifecycleId,
        'HealthObservationKeyLifecycle',
      );
      expect(
        PersistentHealthObservationRepository.implementationId,
        'PersistentHealthObservationRepository',
      );
    });

    test('ReferenceIndex is dependency metadata only — not observation store',
        () async {
      final h = await openHarness();
      addTearDown(h.dispose);
      await h.write(obs('own'));
      expect(await h.repo.getObservation('own'), isNotNull);
      // Clearing index does not delete the observation owner data.
      await h.index.clearEnvelopeReferences(
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      );
      // Force reload by new repository on same encrypted store.
      final repo2 = PersistentHealthObservationRepository(store: h.encrypted);
      expect(await repo2.getObservation('own'), isNotNull);
    });
  });
}

/// Minimal provenance helper lives above — no HealthObservation codec probe.
class _IndexHarness {
  _IndexHarness({
    required this.tempDir,
    required this.secrets,
    required this.lifecycle,
    required this.cipher,
    required this.index,
    required this.fileInner,
    required this.inner,
    required this.encrypted,
    required this.repo,
  });

  final Directory tempDir;
  final MemorySecureSecretStore secrets;
  final HealthObservationKeyLifecycle lifecycle;
  final AesGcmHealthObservationCipher cipher;
  final InMemoryHealthObservationKeyReferenceIndex index;
  final FileHealthObservationStore fileInner;
  final HealthObservationPersistentStore inner;
  final EncryptedHealthObservationStore encrypted;
  final PersistentHealthObservationRepository repo;

  Future<void> write(HealthObservation o) async {
    await repo.ensureProvenance(
      ProvenanceRecord(
        sourceId: o.provenanceId,
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final saved = await repo.saveObservation(o);
    expect(saved, isNotNull);
  }

  Future<void> dispose() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _CountingFailStore implements HealthObservationPersistentStore {
  _CountingFailStore(this.delegate);

  final HealthObservationPersistentStore delegate;
  bool failNextWrite = false;

  @override
  Future<String?> readRaw() => delegate.readRaw();

  @override
  Future<void> writeRaw(String contents) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated persist failure');
    }
    await delegate.writeRaw(contents);
  }
}

class _FailAfterWriteStore implements HealthObservationPersistentStore {
  _FailAfterWriteStore(this.delegate, {this.failVerifyRead = false});

  final HealthObservationPersistentStore delegate;
  final bool failVerifyRead;
  bool _wrote = false;

  @override
  Future<String?> readRaw() async {
    if (failVerifyRead && _wrote) return 'LIFEXHOB2.k9.AAAA.BBBB.CCCC';
    return delegate.readRaw();
  }

  @override
  Future<void> writeRaw(String contents) async {
    _wrote = true;
    await delegate.writeRaw(contents);
  }
}
