import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/file_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
import 'package:lifex_ai/core/health_data/health_observation_cipher.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
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
    tempDir = await Directory.systemTemp.createTemp('lifex_key_rot_');
    secrets = MemorySecureSecretStore();
    lifecycle = HealthObservationKeyLifecycle(secretStore: secrets);
    inner = FileHealthObservationStore(rootDirectory: tempDir);
    final vault = HealthObservationKeyVault(
      secretStore: secrets,
      lifecycle: lifecycle,
    );
    encrypted = EncryptedHealthObservationStore(
      inner: inner,
      keyVault: vault,
      lifecycle: lifecycle,
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

  test('write/read/update/delete/archive with current key', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('o1'),
      provenance: prov('p1'),
    );
    final read = await entry.requestHealthRead(
      gatewayRequest: req(id: 'r', action: 'read'),
      patientId: 'patient-1',
    );
    expect(read.value!.observations, hasLength(1));

    await entry.requestSensitiveUpdate(
      gatewayRequest: req(id: 'u', action: 'update'),
      observation: HealthObservation(
        observationId: 'o1',
        patientId: 'patient-1',
        conceptId: 'bp_systolic',
        value: 111,
        unit: 'mmHg',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'ui',
        provenanceId: 'p1',
      ),
      provenance: prov('p1'),
    );
    expect((await repo.getObservation('o1'))!.value, 111);

    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w2', action: 'write'),
      observation: obs('o2'),
      provenance: prov('p2'),
    );
    await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive'),
      observationId: 'o2',
    );
    expect(
      (await repo.getObservation('o2'))!.status,
      HealthRecordStatus.archived,
    );
    await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'd',
        action: 'delete',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'o1',
    );
    expect(await repo.getObservation('o1'), isNull);
    expect(await repo.getObservation('o2'), isNotNull);
  });

  test('rotate succeeds; data identical; new writes use new key', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('keep-me', value: 77),
      provenance: prov('pk'),
    );
    final before = await repo.listObservationsForPatient('patient-1');
    final beforeId = await lifecycle.peekCurrentKeyId();
    final diskBefore = await inner.readRaw();
    expect(diskBefore, isNotNull);
    expect(diskBefore!.startsWith('LIFEXHOB2.'), isTrue);

    final result = await encrypted.rotateKeys();
    expect(result.previousKeyId, beforeId);
    expect(result.newKeyId, isNot(beforeId));
    expect(result.rewroteCiphertext, isTrue);
    expect(await lifecycle.peekCurrentKeyId(), result.newKeyId);

    final after = await repo.listObservationsForPatient('patient-1');
    expect(after.length, before.length);
    expect(after.first.observationId, before.first.observationId);
    expect(after.first.value, before.first.value);

    final diskAfter = await inner.readRaw();
    expect(diskAfter!.contains('.${result.newKeyId}.'), isTrue);
    expect(diskAfter.contains('.${result.previousKeyId}.'), isFalse);

    // old ciphertext still decryptable with previous key during recovery path
    final oldPlain = await AesGcmHealthObservationCipher().decrypt(
      envelope: diskBefore,
      keyBytes: (await lifecycle.requireKey(result.previousKeyId)).bytes,
    );
    expect(oldPlain.contains('keep-me'), isTrue);

    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wn', action: 'write'),
      observation: obs('new-after-rot', value: 9),
      provenance: prov('pn'),
    );
    final latestDisk = await inner.readRaw();
    expect(latestDisk!.contains('.${result.newKeyId}.'), isTrue);
  });

  test('recovery with correct key version; missing key fails safely', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('rec'),
      provenance: prov('pr'),
    );
    final envelope = await inner.readRaw();
    final parsed = AesGcmHealthObservationCipher().parse(envelope!);
    expect(parsed.keyId, isNotNull);

    final recovered = await lifecycle.decryptWithRecovery(
      envelope: envelope,
      cipher: AesGcmHealthObservationCipher(),
    );
    expect(recovered.contains('rec'), isTrue);

    await secrets.deleteSecret(
      HealthObservationKeyLifecycle.dekSecretIdFor(parsed.keyId!),
    );
    await expectLater(
      lifecycle.decryptWithRecovery(
        envelope: envelope,
        cipher: AesGcmHealthObservationCipher(),
      ),
      throwsA(isA<HealthObservationKeyMissingException>()),
    );
  });

  test('legacy HOB1 migrates only via trusted k1 mapping', () async {
    final cipher = AesGcmHealthObservationCipher();
    final legacySecrets = MemorySecureSecretStore();
    // Simulate pre-lifecycle vault: only dek.v1
    final vault = HealthObservationKeyVault(secretStore: legacySecrets);
    final key = await vault.getOrCreateDataEncryptionKey();
    // Force legacy secret id path already done by vault/lifecycle.

    final hob1 = await cipher.encrypt(
      plaintext: '{"observations":{},"provenance":{}}',
      keyBytes: key,
      keyId: 'ignored-for-manual',
    );
    // Build true HOB1 envelope manually from encrypt internals is hard;
    // use parse-compatible HOB1 by re-encrypting style:
    // Create HOB1 using low-level: encrypt HOB2 then strip — instead write via
    // cipher after we add a test helper... Use rotate path with raw HOB1:
    final parts = hob1.split('.');
    // LIFEXHOB2.keyId.nonce.ct.mac → LIFEXHOB1.nonce.ct.mac
    final hob1Envelope =
        'LIFEXHOB1.${parts[2]}.${parts[3]}.${parts[4]}';

    final life = HealthObservationKeyLifecycle(secretStore: legacySecrets);
    final plain = await life.decryptWithRecovery(
      envelope: hob1Envelope,
      cipher: cipher,
    );
    expect(plain.contains('observations'), isTrue);

    // Without k1/legacy mapping, missing → failure (fresh store)
    final empty = MemorySecureSecretStore();
    final emptyLife = HealthObservationKeyLifecycle(secretStore: empty);
    await expectLater(
      emptyLife.decryptWithRecovery(
        envelope: hob1Envelope,
        cipher: cipher,
      ),
      throwsA(isA<HealthObservationKeyMissingException>()),
    );
  });

  test('corrupted / tampered tag fails; no silent health data', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('tamper'),
      provenance: prov('pt'),
    );
    final raw = (await inner.readRaw())!;
    final parts = raw.split('.');
    parts[4] = parts[4].substring(0, parts[4].length - 2) + 'aa';
    await inner.writeRaw(parts.join('.'));
    final broken = PersistentHealthObservationRepository(store: encrypted);
    await expectLater(
      broken.listObservationsForPatient('patient-1'),
      throwsA(isA<HealthObservationCipherException>()),
    );
  });

  test('rotation interruption restores previous ciphertext', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write'),
      observation: obs('safe'),
      provenance: prov('ps'),
    );
    final backup = await inner.readRaw();
    final currentBefore = await lifecycle.peekCurrentKeyId();

    // Interruption simulation: rotate with a cipher that fails verify by
    // wrapping inner to reject second write path — instead call lifecycle
    // with a broken cipher decrypt on verify by using wrong key mid-flight
    // is hard; simulate restore path explicitly:
    try {
      await lifecycle.rotateEncryptedStore(
        inner: _FailAfterWriteStore(inner, failVerifyRead: true),
        cipher: AesGcmHealthObservationCipher(),
      );
      fail('expected rotation failure');
    } catch (_) {
      // expected
    }
    final restored = await inner.readRaw();
    expect(restored, backup);
    expect(await lifecycle.peekCurrentKeyId(), currentBefore);
    final still = await repo.getObservation('safe');
    expect(still, isNotNull);
  });

  test('production composition still encrypted + LIO not touching keys', () {
    expect(repo.store, isA<EncryptedHealthObservationStore>());
    expect(HealthObservationKeyVault.keyRotationSupported, isTrue);
    final gw = File('lib/core/orchestrator/lio_gateway.dart').readAsStringSync();
    expect(gw.contains('HealthObservationKeyLifecycle'), isFalse);
    expect(gw.contains('SecureSecretStore'), isFalse);
  });
}

/// Inner store that corrupts re-read after write to force rotation rollback.
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
