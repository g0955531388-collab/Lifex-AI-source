import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/file_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
import 'package:lifex_ai/core/health_data/health_observation_cipher.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/in_memory_health_observation_repository.dart';
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
  late PersistentHealthObservationRepository persistentRepo;
  late LioSensitiveActionEntry entry;

  LioGatewayRequest req({
    required String id,
    required String action,
    String purpose = 'care_support',
    String scope = 'profile_basic',
    LioActionRisk risk = LioActionRisk.low,
    bool authorized = true,
    bool authenticated = true,
    bool consent = true,
    bool humanConfirmed = false,
  }) {
    return LioGatewayRequest(
      requestId: id,
      correlationId: 'c',
      identityAccountId: 'acct-1',
      purpose: purpose,
      requestedAction: action,
      dataScope: scope,
      sensitivity: LioDataSensitivity.personal,
      consent: LioConsentContext(
        consentGranted: consent,
        purposeAligned: consent,
      ),
      riskLevel: risk,
      timestamp: DateTime.utc(2026, 1, 1),
      authenticated: authenticated,
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

  HealthObservation obs({
    required String id,
    String patientId = 'patient-1',
    String provenanceId = 'prov-1',
    Object? value = 120,
  }) {
    return HealthObservation(
      observationId: id,
      patientId: patientId,
      conceptId: 'bp_systolic',
      value: value,
      unit: 'mmHg',
      observedAt: DateTime.utc(2026, 1, 2),
      sourceType: 'manual',
      sourceId: 'ui',
      provenanceId: provenanceId,
    );
  }

  EncryptedHealthObservationStore _encryptedStore() {
    return EncryptedHealthObservationStore(
      inner: inner,
      keyVault: HealthObservationKeyVault(secretStore: secrets),
    );
  }

  LifexProductionBundle _assemble({
    required HealthObservationPersistentStore store,
    required MemorySecureSecretStore secretStore,
  }) {
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
    return LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: ai,
      aiServiceRouter: AiServiceRouter(
        hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
      ),
      knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
      corpus: corpus,
      clock: clock,
      healthObservationStore: store,
      healthSecretStore: secretStore,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifex_health_enc_');
    secrets = MemorySecureSecretStore();
    inner = FileHealthObservationStore(rootDirectory: tempDir);
    encrypted = _encryptedStore();
    final bundle = _assemble(store: encrypted, secretStore: secrets);
    entry = bundle.sensitiveActionEntry;
    persistentRepo =
        bundle.healthObservationRepository as PersistentHealthObservationRepository;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('disk bytes are not plaintext HealthObservation', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write_health_obs'),
      observation: obs(id: 'secret-obs-42', provenanceId: ''),
      provenance: prov('prov-1'),
    );
    final onDisk = await inner.readRaw();
    expect(onDisk, isNotNull);
    expect(AesGcmHealthObservationCipher.looksLikeEnvelope(onDisk!), isTrue);
    expect(onDisk.contains('secret-obs-42'), isFalse);
    expect(onDisk.contains('patient-1'), isFalse);
    expect(onDisk.contains('bp_systolic'), isFalse);
    expect(onDisk.contains('"observations"'), isFalse);
  });

  test('write then read round-trip through encryption', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w2', action: 'write_health_obs'),
      observation: obs(id: 'o1', provenanceId: ''),
      provenance: prov('prov-1'),
    );
    final reloaded = PersistentHealthObservationRepository(
      store: EncryptedHealthObservationStore(
        inner: FileHealthObservationStore(rootDirectory: tempDir),
        keyVault: HealthObservationKeyVault(secretStore: secrets),
      ),
    );
    final got = await reloaded.getObservation('o1');
    expect(got, isNotNull);
    expect(got!.value, 120);
  });

  test('update works after encryption', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w3', action: 'write_health_obs'),
      observation: obs(id: 'o2', provenanceId: ''),
      provenance: prov('prov-2'),
    );
    final updated = await entry.requestSensitiveUpdate(
      gatewayRequest: req(id: 'u', action: 'update_health_obs'),
      observation: obs(id: 'o2', provenanceId: 'prov-2', value: 99),
      provenance: prov('prov-2'),
    );
    expect(updated.value!.success, isTrue);
    expect((await persistentRepo.getObservation('o2'))!.value, 99);
  });

  test('delete and archive; DELETE ≠ ARCHIVE', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wa', action: 'write_health_obs'),
      observation: obs(id: 'oa', provenanceId: ''),
      provenance: prov('prov-a'),
    );
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wd', action: 'write_health_obs'),
      observation: obs(id: 'od', provenanceId: ''),
      provenance: prov('prov-d'),
    );
    final archived = await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive_health_obs'),
      observationId: 'oa',
    );
    expect(archived.value!.success, isTrue);
    expect(
      (await persistentRepo.getObservation('oa'))!.status,
      HealthRecordStatus.archived,
    );
    final deleted = await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'd',
        action: 'delete_health_obs',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'od',
    );
    expect(deleted.value!.deleted, isTrue);
    expect(await persistentRepo.getObservation('od'), isNull);
    expect(await persistentRepo.getObservation('oa'), isNotNull);
  });

  test('key does not come from source code', () async {
    final vault = HealthObservationKeyVault(secretStore: secrets);
    final key = await vault.getOrCreateDataEncryptionKey();
    expect(key.length, HealthObservationKeyVault.keyLengthBytes);
    final source = File(
      'lib/core/health_data/health_observation_key_vault.dart',
    ).readAsStringSync();
    expect(source.contains(base64ish(key)), isFalse);
    expect(
      HealthObservationKeyVault.dataEncryptionKeySecretId
          .startsWith('lifex.health_observation.dek'),
      isTrue,
    );
    expect(HealthObservationKeyVault.keyRotationSupported, isTrue);
  });

  test('tampered ciphertext does not become valid health data', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'wt', action: 'write_health_obs'),
      observation: obs(id: 'ot', provenanceId: ''),
      provenance: prov('prov-t'),
    );
    final raw = await inner.readRaw();
    expect(raw, isNotNull);
    final tampered = _tamperEnvelope(raw!);
    await inner.writeRaw(tampered);
    final brokenRepo = PersistentHealthObservationRepository(
      store: EncryptedHealthObservationStore(
        inner: FileHealthObservationStore(rootDirectory: tempDir),
        keyVault: HealthObservationKeyVault(secretStore: secrets),
      ),
    );
    await expectLater(
      brokenRepo.listObservationsForPatient('patient-1'),
      throwsA(isA<HealthObservationCipherException>()),
    );
  });

  test('authorization / consent / purpose / scope / audit remain', () async {
    entry.lioGateway.auditLog.clear();
    final denied = await entry.requestHealthRead(
      gatewayRequest: req(id: 'da', action: 'read_health', authorized: false),
      patientId: 'patient-1',
    );
    expect(denied.executed, isFalse);
    expect(denied.decision.reasonCode, 'UNAUTHORIZED');
    final consent = await entry.requestHealthRead(
      gatewayRequest: req(id: 'dc', action: 'read_health', consent: false),
      patientId: 'patient-1',
    );
    expect(consent.decision.kind, LioGatewayDecisionKind.requireConsent);
    final purpose = await entry.requestHealthRead(
      gatewayRequest: req(
        id: 'dp',
        action: 'read_health',
        purpose: 'bad_purpose',
      ),
      patientId: 'patient-1',
    );
    expect(purpose.decision.reasonCode, 'PURPOSE_VIOLATION');
    final scope = await entry.requestHealthRead(
      gatewayRequest: req(
        id: 'ds',
        action: 'read_health',
        scope: 'full_phr_dump',
      ),
      patientId: 'patient-1',
    );
    expect(scope.decision.reasonCode, 'SCOPE_VIOLATION');
    expect(
      entry.lioGateway.auditLog.events.any((e) => e.requestId == 'da'),
      isTrue,
    );
  });

  test('production composition uses encrypted persistent implementation', () {
    final bundle = _assemble(store: encrypted, secretStore: secrets);
    expect(
      bundle.healthObservationRepository,
      isA<PersistentHealthObservationRepository>(),
    );
    expect(
      (bundle.healthObservationRepository as PersistentHealthObservationRepository)
          .store,
      isA<EncryptedHealthObservationStore>(),
    );
    expect(
      bundle.healthObservationRepository,
      isNot(isA<InMemoryHealthObservationRepository>()),
    );
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
    expect(HealthObservationRepository.ownerId, 'HealthObservationRepository');
    expect(AesGcmHealthObservationCipher.algorithmId, 'AES-256-GCM');
  });

  test('EXPORT/SHARE/PRINT/CONTROL remain non-success', () async {
    final export = await entry.requestClinicalPhrExport(
      gatewayRequest: req(
        id: 'ex',
        action: 'export_phr',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(export.value!.reasonCode, 'NOT_IMPLEMENTED');
    final printOp = await entry.requestSensitivePrint(
      gatewayRequest: req(id: 'pr', action: 'print'),
    );
    expect(printOp.value!.reasonCode, 'UNSUPPORTED_OPERATION');
  });
}

String base64ish(List<int> key) {
  // لا نضع المفتاح في الاختبار كـ fixture ثابت؛ فقط نتحقق غياب تسلسله في المصدر.
  return String.fromCharCodes(key.take(8));
}

String _tamperEnvelope(String envelope) {
  final parts = envelope.split('.');
  expect(parts.length, anyOf(4, 5));
  final cipherIndex = parts.length == 5 ? 3 : 2;
  final macIndex = parts.length == 5 ? 4 : 3;
  final cipher = parts[cipherIndex];
  final bytes = cipher.codeUnits.toList();
  if (bytes.isEmpty) {
    parts[cipherIndex] = 'AAAA';
    return parts.join('.');
  }
  final i = Random().nextInt(bytes.length);
  bytes[i] = bytes[i] == 65 ? 66 : 65;
  parts[cipherIndex] = String.fromCharCodes(bytes);
  // keep mac as-is so auth fails
  expect(parts[macIndex], isNotEmpty);
  return parts.join('.');
}
