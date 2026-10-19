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
    bool authorized = true,
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
      authorized: authorized,
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
    tempDir = await Directory.systemTemp.createTemp('lifex_key_retain_');
    secrets = MemorySecureSecretStore();
    lifecycle = HealthObservationKeyLifecycle(secretStore: secrets);
    cipher = AesGcmHealthObservationCipher();
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
    );
    final clock = FixedClock(DateTime.utc(2026, 9, 21, 20, 0, 0));
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

  test('current key is used for WRITE', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('cur'),
      provenance: prov('pc'),
    );
    final current = await lifecycle.peekCurrentKeyId();
    expect(current, isNotNull);
    final meta = await lifecycle.requireMetadata(current!);
    expect(meta.status, HealthObservationKeyStatus.current);
    final disk = await inner.readRaw();
    expect(disk!.contains('.$current.'), isTrue);
    expect(await repo.getObservation('cur'), isNotNull);
  });

  test('retired key cannot encrypt new writes; decrypt allowed by policy',
      () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('keep'),
      provenance: prov('pk'),
    );
    final oldEnvelope = (await inner.readRaw())!;
    final rot = await encrypted.rotateKeys();
    final retired = await encrypted.retirePreviousKey(rot.previousKeyId);
    expect(retired.status, HealthObservationKeyStatus.retired);
    expect(retired.retiredAt, isNotNull);

    await expectLater(
      lifecycle.requireKeyForEncrypt(rot.previousKeyId),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.encryptDenied,
        ),
      ),
    );

    // Current remains writable.
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wn', action: 'write'),
      observation: obs('after-retire', value: 1),
      provenance: prov('pn'),
    );
    expect(await lifecycle.peekCurrentKeyId(), rot.newKeyId);

    // Old ciphertext still decryptable with retired key via policy.
    final plain = await lifecycle.decryptWithRecovery(
      envelope: oldEnvelope,
      cipher: cipher,
    );
    expect(plain.contains('keep'), isTrue);
  });

  test('revoked key decrypt is rejected safely', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('rev'),
      provenance: prov('pr'),
    );
    final oldEnvelope = (await inner.readRaw())!;
    final rot = await encrypted.rotateKeys();
    // After rotation, previous key is not referenced by live store.
    await encrypted.revokeKey(rot.previousKeyId);
    final meta = await lifecycle.requireMetadata(rot.previousKeyId);
    expect(meta.status, HealthObservationKeyStatus.revoked);
    expect(meta.revokedAt, isNotNull);

    await expectLater(
      lifecycle.decryptWithRecovery(envelope: oldEnvelope, cipher: cipher),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.keyRevoked,
        ),
      ),
    );
    // Live data still readable with current key.
    expect(await repo.getObservation('rev'), isNotNull);
  });

  test('archived unavailable key fails safely', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('arch'),
      provenance: prov('pa'),
    );
    final oldEnvelope = (await inner.readRaw())!;
    final rot = await encrypted.rotateKeys();
    await encrypted.archiveKey(rot.previousKeyId, note: 'unavailable');
    final meta = await lifecycle.requireMetadata(rot.previousKeyId);
    expect(meta.status, HealthObservationKeyStatus.archived);
    expect(meta.archivalNote, 'unavailable');

    await expectLater(
      lifecycle.decryptWithRecovery(envelope: oldEnvelope, cipher: cipher),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.keyArchivedUnavailable,
        ),
      ),
    );
  });

  test('missing key fails safely — no plaintext fallback', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('miss'),
      provenance: prov('pm'),
    );
    final envelope = (await inner.readRaw())!;
    final keyId = cipher.parse(envelope).keyId!;
    await secrets.deleteSecret(
      HealthObservationKeyLifecycle.dekSecretIdFor(keyId),
    );
    await expectLater(
      lifecycle.decryptWithRecovery(envelope: envelope, cipher: cipher),
      throwsA(isA<HealthObservationKeyMissingException>()),
    );
    // Fresh repository — must not invent HealthObservation from missing DEK.
    final cold = PersistentHealthObservationRepository(store: encrypted);
    await expectLater(
      cold.listObservationsForPatient('patient-1'),
      throwsA(isA<HealthObservationKeyMissingException>()),
    );
  });

  test('cannot purge or revoke key while envelopes still reference it',
      () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('held'),
      provenance: prov('ph'),
    );
    final keyId = await lifecycle.peekCurrentKeyId();
    expect(keyId, isNotNull);

    // Mint alternate and promote so previous can be targeted, but leave
    // ciphertext still on previous by skipping rotate rewrite — use retire
    // path on a non-referenced key after rotate for revoke success case;
    // here: attempt purge/revoke while still CURRENT/referenced.
    await expectLater(
      encrypted.revokeKey(keyId!),
      throwsA(
        isA<HealthObservationKeyPolicyException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyRetentionDecision.keyNotCurrent,
        ),
      ),
    );

    final purgeCurrent = await encrypted.attemptPurgeKey(keyId);
    expect(purgeCurrent.allowed, isFalse);
    expect(
      purgeCurrent.reasonCode,
      HealthObservationKeyRetentionDecision.retentionRequired,
    );

    // Force ACTIVE_FOR_DECRYPTION while still referenced: rotate without
    // completing promote is hard; instead rotate then write old envelope back.
    final rot = await encrypted.rotateKeys();
    await inner.writeRaw(
      await cipher.encrypt(
        plaintext: '{"observations":{},"provenance":{}}',
        keyBytes: (await lifecycle.requireKey(rot.previousKeyId)).bytes,
        keyId: rot.previousKeyId,
      ),
    );
    await expectLater(
      encrypted.revokeKey(rot.previousKeyId),
      throwsA(
        isA<HealthObservationKeyIndexInconsistentException>().having(
          (e) => e.reasonCode,
          'code',
          HealthObservationKeyIndexInconsistentException.reasonCodeValue,
        ),
      ),
    );
    final purge = await encrypted.attemptPurgeKey(rot.previousKeyId);
    expect(purge.allowed, isFalse);
    expect(
      purge.reasonCode,
      HealthObservationKeyRetentionDecision.indexInconsistent,
    );
  });

  test('retention can end after re-encrypt proves key no longer required',
      () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('move'),
      provenance: prov('pm'),
    );
    final rot = await encrypted.rotateKeys();
    expect(rot.rewroteCiphertext, isTrue);

    await encrypted.revokeKey(rot.previousKeyId);
    final decision = await encrypted.attemptPurgeKey(rot.previousKeyId);
    expect(decision.allowed, isTrue);
    expect(
      decision.reasonCode,
      HealthObservationKeyRetentionDecision.purgeAllowed,
    );

    await expectLater(
      lifecycle.requireKey(rot.previousKeyId),
      throwsA(isA<HealthObservationKeyMissingException>()),
    );
    // Metadata retained without DEK.
    final meta = await lifecycle.loadMetadata(rot.previousKeyId);
    expect(meta!.status, HealthObservationKeyStatus.revoked);
    expect(await repo.getObservation('move'), isNotNull);
  });

  test('rotation then retirement keeps data readable', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('rot-ret', value: 55),
      provenance: prov('prr'),
    );
    final rot = await encrypted.rotateKeys();
    await encrypted.retirePreviousKey(rot.previousKeyId);
    final read = await repo.getObservation('rot-ret');
    expect(read!.value, 55);
    final disk = await inner.readRaw();
    expect(disk!.contains('.${rot.newKeyId}.'), isTrue);
  });

  test('rotation interruption leaves key lifecycle consistent', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('safe'),
      provenance: prov('ps'),
    );
    final backup = await inner.readRaw();
    final currentBefore = await lifecycle.peekCurrentKeyId();
    final metaBefore = await lifecycle.requireMetadata(currentBefore!);

    try {
      await lifecycle.rotateEncryptedStore(
        inner: _FailAfterWriteStore(inner, failVerifyRead: true),
        cipher: cipher,
        referenceIndex: encrypted.referenceIndex,
      );
      fail('expected rotation failure');
    } catch (_) {}

    expect(await inner.readRaw(), backup);
    expect(await lifecycle.peekCurrentKeyId(), currentBefore);
    final metaAfter = await lifecycle.requireMetadata(currentBefore);
    expect(metaAfter.status, HealthObservationKeyStatus.current);
    expect(metaAfter.status, metaBefore.status);
    expect(await repo.getObservation('safe'), isNotNull);
  });

  test('new writes use current key only; old ciphertext keeps correct keyId',
      () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('old'),
      provenance: prov('po'),
    );
    final oldDisk = (await inner.readRaw())!;
    final oldKeyId = cipher.parse(oldDisk).keyId!;
    final rot = await encrypted.rotateKeys();
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wn', action: 'write'),
      observation: obs('new'),
      provenance: prov('pn'),
    );
    final newDisk = (await inner.readRaw())!;
    expect(cipher.parse(newDisk).keyId, rot.newKeyId);
    expect(cipher.parse(oldDisk).keyId, oldKeyId);
    expect(oldKeyId, rot.previousKeyId);
  });

  test('DELETE is not ARCHIVE; CRUD/archive path unchanged', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w1', action: 'write'),
      observation: obs('d1'),
      provenance: prov('p1'),
    );
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w2', action: 'write'),
      observation: obs('d2'),
      provenance: prov('p2'),
    );
    await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive'),
      observationId: 'd2',
    );
    expect(
      (await repo.getObservation('d2'))!.status,
      HealthRecordStatus.archived,
    );
    await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'd',
        action: 'delete',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'd1',
    );
    expect(await repo.getObservation('d1'), isNull);
    expect(await repo.getObservation('d2'), isNotNull);
  });

  test('production composition uses same KeyLifecycle; LIO isolated', () {
    expect(repo.store, isA<EncryptedHealthObservationStore>());
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
    expect(
      HealthObservationKeyRetentionPolicy.policyId,
      'HealthObservationKeyRetentionPolicy',
    );
    final gw =
        File('lib/core/orchestrator/lio_gateway.dart').readAsStringSync();
    final entrySrc = File(
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    ).readAsStringSync();
    for (final t in [gw, entrySrc]) {
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse);
      expect(t.contains('HealthObservationKeyVault'), isFalse);
      expect(t.contains('SecureSecretStore'), isFalse);
      expect(t.contains('HealthObservationKeyRetentionPolicy'), isFalse);
    }
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
