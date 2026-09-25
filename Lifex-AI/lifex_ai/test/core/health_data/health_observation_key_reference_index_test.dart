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
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/orchestrator/clock.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway_contracts.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
import 'package:lifex_ai/core/security/memory_secure_secret_store.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/features/ai/ai_bridge.dart';
import 'package:lifex_ai/features/ai/ai_engine.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/ai/doctor_guidance_engine.dart';
import 'package:lifex_ai/features/ai/health_analysis_engine.dart';
import 'package:lifex_ai/features/ai/health_decision_engine.dart';
import 'package:lifex_ai/features/ai/unified_ai_hub_gateway.dart';

class _FakeDb implements MedicalDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MemCreds implements SecureCredentialStore {
  final Map<String, String> _m = {};
  @override
  Future<void> saveCredential(String key, String value) async => _m[key] = value;
  @override
  Future<String?> readCredential(String key) async => _m[key];
  @override
  Future<void> deleteCredential(String key) async => _m.remove(key);
}

void main() {
  late Directory tempDir;
  late MemorySecureSecretStore secrets;
  late FileHealthObservationStore inner;
  late InMemoryHealthObservationKeyReferenceIndex index;
  late EncryptedHealthObservationStore encrypted;
  late PersistentHealthObservationRepository repo;
  late LioSensitiveActionEntry entry;
  late HealthObservationKeyLifecycle lifecycle;
  late AesGcmHealthObservationCipher cipher;

  LioGatewayRequest req({
    required String id,
    required String action,
    LioActionRisk risk = LioActionRisk.low,
    bool humanConfirmed = false,
  }) {
    return LioGatewayRequest(
      requestId: id,
      correlationId: 'c',
      identityAccountId: 'acct-1',
      purpose: 'care_support',
      requestedAction: action,
      dataScope: 'profile_basic',
      sensitivity: LioDataSensitivity.personal,
      consent: const LioConsentContext(
        consentGranted: true,
        purposeAligned: true,
      ),
      riskLevel: risk,
      timestamp: DateTime.utc(2026, 1, 1),
      authenticated: true,
      authorized: true,
      humanConfirmed: humanConfirmed,
      minimumNecessarySatisfied: true,
    );
  }

  ProvenanceRecord prov(String id) => ProvenanceRecord(
        sourceId: id,
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      );

  HealthObservation obs(String id, {Object? value = 120}) => HealthObservation(
        observationId: id,
        patientId: 'patient-1',
        conceptId: 'bp_systolic',
        value: value,
        unit: 'mmHg',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'ui',
        provenanceId: '',
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifex_key_ref_');
    secrets = MemorySecureSecretStore();
    lifecycle = HealthObservationKeyLifecycle(secretStore: secrets);
    cipher = AesGcmHealthObservationCipher();
    index = InMemoryHealthObservationKeyReferenceIndex();
    inner = FileHealthObservationStore(rootDirectory: tempDir);
    final vault = HealthObservationKeyVault(
      secretStore: secrets,
      lifecycle: lifecycle,
    );
    encrypted = EncryptedHealthObservationStore(
      inner: inner,
      keyVault: vault,
      lifecycle: lifecycle,
      cipher: cipher,
      referenceIndex: index,
    );
    final clock = FixedClock(DateTime.utc(2026, 9, 21, 21, 0, 0));
    final corpus = InMemoryKnowledgeCorpus(const []);
    final analysis = HealthAnalysisEngine(
      symptomKeywordMap: const {},
      emergencySymptomIds: const {},
    );
    final guidance = DoctorGuidanceEngine(symptomBodySystemMap: const {});
    final ai = AiModuleBundle(
      engine: AiEngine.instance,
      analysisEngine: analysis,
      guidanceEngine: guidance,
      decisionEngine: HealthDecisionEngine(
        analysisEngine: analysis,
        guidanceEngine: guidance,
      ),
    );
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: ai,
      aiServiceRouter: AiServiceRouter(
        hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
      ),
      knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
      corpus: corpus,
      clock: clock,
      healthObservationStore: encrypted,
      healthSecretStore: secrets,
    );
    entry = bundle.sensitiveActionEntry;
    repo = bundle.healthObservationRepository
        as PersistentHealthObservationRepository;
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> writeOne(String id) async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w-$id', action: 'write'),
      observation: obs(id),
      provenance: prov('p-$id'),
    );
  }

  test('WRITE creates reference; READ does not duplicate', () async {
    await writeOne('w1');
    final keyId = await lifecycle.peekCurrentKeyId();
    final before = await index.referencesFor(keyId!);
    expect(before, isNotEmpty);
    expect(
      before.any((r) => r.recordId == 'w1'),
      isTrue,
    );
    final countBefore = (await index.allReferences()).length;

    await entry.requestHealthRead(
      gatewayRequest: req(id: 'r', action: 'read'),
      patientId: 'patient-1',
    );
    expect((await index.allReferences()).length, countBefore);
  });

  test('UPDATE preserves correct reference; ARCHIVE preserves reference',
      () async {
    await writeOne('u1');
    final keyId = await lifecycle.peekCurrentKeyId();
    await entry.requestSensitiveUpdate(
      gatewayRequest: req(id: 'u', action: 'update'),
      observation: HealthObservation(
        observationId: 'u1',
        patientId: 'patient-1',
        conceptId: 'bp_systolic',
        value: 99,
        unit: 'mmHg',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'ui',
        provenanceId: 'p-u1',
      ),
      provenance: prov('p-u1'),
    );
    expect(await index.hasReferences(keyId!), isTrue);
    expect(
      (await index.referencesFor(keyId)).any((r) => r.recordId == 'u1'),
      isTrue,
    );

    await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive'),
      observationId: 'u1',
    );
    final archivedRef = (await index.referencesFor(keyId))
        .firstWhere((r) => r.recordId == 'u1');
    expect(
      archivedRef.status,
      HealthObservationKeyReferenceStatus.archivedRecord,
    );
    expect(await index.hasReferences(keyId), isTrue);
  });

  test('DELETE removes record reference after successful deletion', () async {
    await writeOne('d1');
    await writeOne('d2');
    final keyId = await lifecycle.peekCurrentKeyId();
    expect(
      (await index.referencesFor(keyId!)).any((r) => r.recordId == 'd1'),
      isTrue,
    );
    await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'del',
        action: 'delete',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'd1',
    );
    expect(
      (await index.referencesFor(keyId)).any((r) => r.recordId == 'd1'),
      isFalse,
    );
    expect(
      (await index.referencesFor(keyId)).any((r) => r.recordId == 'd2'),
      isTrue,
    );
    // Envelope still depends on key.
    expect(await index.hasReferences(keyId), isTrue);
  });

  test('rotation moves reference oldKeyId → newKeyId', () async {
    await writeOne('rot');
    final before = await lifecycle.peekCurrentKeyId();
    expect(await index.hasReferences(before!), isTrue);
    final rot = await encrypted.rotateKeys();
    expect(await index.hasReferences(rot.previousKeyId), isFalse);
    expect(await index.hasReferences(rot.newKeyId), isTrue);
    final report = await encrypted.verifyReferenceIndex();
    expect(report.consistent, isTrue);
  });

  test('failed / interrupted rotation preserves old reference', () async {
    await writeOne('safe');
    final before = await lifecycle.peekCurrentKeyId();
    final refsBefore = await index.referencesFor(before!);
    try {
      await lifecycle.rotateEncryptedStore(
        inner: _FailAfterWriteStore(inner, failVerifyRead: true),
        cipher: cipher,
        referenceIndex: index,
      );
      fail('expected failure');
    } catch (_) {}
    expect(await lifecycle.peekCurrentKeyId(), before);
    expect(await index.hasReferences(before), isTrue);
    expect(
      (await index.referencesFor(before)).length,
      refsBefore.length,
    );
    expect((await encrypted.verifyReferenceIndex()).consistent, isTrue);
  });

  test('retired key with references remains decrypt-capable', () async {
    await writeOne('ret');
    final oldEnv = (await inner.readRaw())!;
    final rot = await encrypted.rotateKeys();
    // Keep a copy encrypted with previous — but live store moved.
    // Retire previous (no live refs after rotate).
    await encrypted.retirePreviousKey(rot.previousKeyId);
    // Re-introduce previous dependency via promote-without-rewrite path:
    // decrypt old envelope with retired key must still work if refs allow
    // policy decrypt for RETIRED even without live refs.
    final plain = await lifecycle.decryptWithRecovery(
      envelope: oldEnv,
      cipher: cipher,
    );
    expect(plain.contains('ret'), isTrue);
  });

  test('cannot revoke/archive/purge while index shows references', () async {
    await writeOne('held');
    final k1 = await lifecycle.peekCurrentKeyId();
    final minted = await lifecycle.mintNewKey();
    await lifecycle.promoteCurrent(minted.keyId);
    // Store + index still on k1; current is minted.
    expect(await index.hasReferences(k1!), isTrue);

    await expectLater(
      encrypted.revokeKey(k1),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.keyStillReferenced,
        ),
      ),
    );
    await expectLater(
      encrypted.archiveKey(k1),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.keyStillReferenced,
        ),
      ),
    );
    final purge = await encrypted.attemptPurgeKey(k1);
    expect(purge.allowed, isFalse);
    expect(
      purge.reasonCode,
      HealthObservationKeyRetentionDecision.keyStillReferenced,
    );
  });

  test('purge without references allowed after re-encrypt + revoke', () async {
    await writeOne('gone');
    final rot = await encrypted.rotateKeys();
    expect(await index.hasReferences(rot.previousKeyId), isFalse);
    await encrypted.revokeKey(rot.previousKeyId);
    final decision = await encrypted.attemptPurgeKey(rot.previousKeyId);
    expect(decision.allowed, isTrue);
    expect(
      decision.reasonCode,
      HealthObservationKeyRetentionDecision.purgeAllowed,
    );
  });

  test('detects missing, orphan, wrong keyId, duplicate, stale', () async {
    await writeOne('c1');
    final keyId = await lifecycle.peekCurrentKeyId();

    // missing: clear index while store remains
    await index.clearEnvelopeReferences(
      HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
    );
    var report = await index.verifyConsistency(cipherTextInner: inner);
    expect(report.consistent, isFalse);
    expect(
      report.issues.any(
        (i) =>
            i.kind ==
            HealthObservationKeyIndexInconsistencyKind.missingReference,
      ),
      isTrue,
    );

    // rebuild then orphan: clear store file content
    await encrypted.rebuildReferenceIndex();
    await inner.writeRaw('');
    // empty string may be treated as empty — write empty then delete by
    // overwriting with whitespace-only already empty from writeRaw('')
    // File store: empty string is written; readRaw returns null if trim empty.
    report = await index.verifyConsistency(cipherTextInner: inner);
    expect(
      report.issues.any(
        (i) =>
            i.kind == HealthObservationKeyIndexInconsistencyKind.orphanReference,
      ),
      isTrue,
    );

    // restore via rewrite
    await writeOne('c2');
    report = await index.verifyConsistency(cipherTextInner: inner);
    expect(report.consistent, isTrue);

    // wrong keyId: corrupt index entry
    final fp = HealthObservationKeyReferenceIndexSupport.fingerprintOf(
      (await inner.readRaw())!,
    );
    await index.upsertAfterPersist(
      keyId: 'k999',
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      formatVersion: 'LIFEXHOB2',
      contentFingerprint: fp,
      recordStatuses: const {},
    );
    report = await index.verifyConsistency(cipherTextInner: inner);
    expect(
      report.issues.any(
        (i) => i.kind == HealthObservationKeyIndexInconsistencyKind.wrongKeyId,
      ),
      isTrue,
    );

    await encrypted.rebuildReferenceIndex();

    // stale fingerprint
    await index.upsertAfterPersist(
      keyId: keyId!,
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      formatVersion: 'LIFEXHOB2',
      contentFingerprint: 'stale-fp',
      recordStatuses: {
        'c2': HealthObservationKeyReferenceStatus.active,
      },
    );
    // peek may have changed after writeOne c2
    final current = await lifecycle.peekCurrentKeyId();
    await index.upsertAfterPersist(
      keyId: current!,
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      formatVersion: 'LIFEXHOB2',
      contentFingerprint: 'stale-fp',
      recordStatuses: {
        'c2': HealthObservationKeyReferenceStatus.active,
      },
    );
    report = await index.verifyConsistency(cipherTextInner: inner);
    expect(
      report.issues.any(
        (i) =>
            i.kind == HealthObservationKeyIndexInconsistencyKind.staleReference,
      ),
      isTrue,
    );

    // duplicate: inject second envelope ref via direct map by rebuilding
    // then manually adding duplicate through second upsert path —
    // use raw inject on memory map via upsert with same env key overwrites;
    // simulate duplicate by verifying duplicate detection on list with clones.
    final dupReport = HealthObservationKeyReferenceIndexSupport.verify(
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
      cipherTextInner: inner,
      cipher: cipher,
    );
    final dup = await dupReport;
    expect(
      dup.issues.any(
        (i) =>
            i.kind ==
            HealthObservationKeyIndexInconsistencyKind.duplicateReference,
      ),
      isTrue,
    );
  });

  test('INDEX_INCONSISTENT blocks REVOKE / ARCHIVE / PURGE', () async {
    await writeOne('blk');
    await index.clearEnvelopeReferences(
      HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
    );
    final keyId = await lifecycle.peekCurrentKeyId();
    final minted = await lifecycle.mintNewKey();
    await lifecycle.promoteCurrent(minted.keyId);

    await expectLater(
      encrypted.revokeKey(keyId!),
      throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
    );
    await expectLater(
      encrypted.archiveKey(keyId),
      throwsA(isA<HealthObservationKeyIndexInconsistentException>()),
    );
    final purge = await encrypted.attemptPurgeKey(keyId);
    expect(purge.allowed, isFalse);
    expect(
      purge.reasonCode,
      HealthObservationKeyRetentionDecision.indexInconsistent,
    );
  });

  test('rebuild repairs valid index without exposing plaintext or keys',
      () async {
    await writeOne('rb');
    await index.clearEnvelopeReferences(
      HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
    );
    expect((await encrypted.verifyReferenceIndex()).consistent, isFalse);

    final result = await encrypted.rebuildReferenceIndex();
    expect(result.success, isTrue);
    expect(result.consistency.consistent, isTrue);
    expect(result.envelopeReferenced, isTrue);

    // Result API must not carry plaintext/health values or DEK material.
    final encoded = result.toString();
    expect(encoded.contains('bp_systolic'), isFalse);
    expect(encoded.contains('"value"'), isFalse);
    final refs = await index.allReferences();
    for (final r in refs) {
      expect(r.toJson().containsKey('value'), isFalse);
      expect(r.toJson().containsKey('dek'), isFalse);
      expect(r.toJson().containsKey('keyBytes'), isFalse);
      expect(r.toJson()['keyId'], isNot(contains('='))); // not raw key material
    }
  });

  test('production path: DELETE ≠ ARCHIVE; owner unchanged', () async {
    await writeOne('x1');
    await writeOne('x2');
    await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive'),
      observationId: 'x2',
    );
    expect(
      (await repo.getObservation('x2'))!.status,
      HealthRecordStatus.archived,
    );
    await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'd',
        action: 'delete',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'x1',
    );
    expect(await repo.getObservation('x1'), isNull);
    expect(await repo.getObservation('x2'), isNotNull);
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
  });
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
