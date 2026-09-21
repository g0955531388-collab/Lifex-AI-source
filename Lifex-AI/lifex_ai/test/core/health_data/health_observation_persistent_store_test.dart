import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/file_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
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

  EncryptedHealthObservationStore _encStore() {
    return EncryptedHealthObservationStore(
      inner: FileHealthObservationStore(rootDirectory: tempDir),
      keyVault: HealthObservationKeyVault(secretStore: secrets),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifex_health_obs_');
    secrets = MemorySecureSecretStore();
    final store = _encStore();
    final bundle = _assemble(store: store, secretStore: secrets);
    entry = bundle.sensitiveActionEntry;
    persistentRepo =
        bundle.healthObservationRepository as PersistentHealthObservationRepository;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create/write persists across repository reload', () async {
    final write = await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w', action: 'write_health_obs'),
      observation: obs(id: 'o1', provenanceId: ''),
      provenance: prov('prov-1'),
    );
    expect(write.value!.success, isTrue);

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

  test('read via Entry → Application → Persistent repo', () async {
    await persistentRepo.ensureProvenance(prov('prov-1'));
    await persistentRepo.saveObservation(obs(id: 'o2'));
    final read = await entry.requestHealthRead(
      gatewayRequest: req(id: 'r', action: 'read_health'),
      patientId: 'patient-1',
    );
    expect(read.value!.success, isTrue);
    expect(read.value!.observations.any((o) => o.observationId == 'o2'), isTrue);
  });

  test('update persists', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w2', action: 'write_health_obs'),
      observation: obs(id: 'o3', provenanceId: ''),
      provenance: prov('prov-3'),
    );
    final updated = await entry.requestSensitiveUpdate(
      gatewayRequest: req(id: 'u', action: 'update_health_obs'),
      observation: obs(id: 'o3', provenanceId: 'prov-3', value: 110),
      provenance: prov('prov-3'),
    );
    expect(updated.value!.success, isTrue);
    final got = await persistentRepo.getObservation('o3');
    expect(got!.value, 110);
  });

  test('archive soft ≠ delete hard', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w3', action: 'write_health_obs'),
      observation: obs(id: 'o4', provenanceId: ''),
      provenance: prov('prov-4'),
    );
    final archived = await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a', action: 'archive_health_obs'),
      observationId: 'o4',
    );
    expect(archived.value!.success, isTrue);
    expect(
      (await persistentRepo.getObservation('o4'))!.status,
      HealthRecordStatus.archived,
    );

    await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w4', action: 'write_health_obs'),
      observation: obs(id: 'o5', provenanceId: ''),
      provenance: prov('prov-5'),
    );
    final deleted = await entry.requestHealthObservationDelete(
      gatewayRequest: req(
        id: 'd',
        action: 'delete_health_obs',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      observationId: 'o5',
    );
    expect(deleted.value!.success, isTrue);
    expect(deleted.value!.deleted, isTrue);
    expect(await persistentRepo.getObservation('o5'), isNull);
    expect(await persistentRepo.getObservation('o4'), isNotNull);
  });

  test('authorization / consent / purpose / scope / audit', () async {
    entry.lioGateway.auditLog.clear();
    final deniedAuth = await entry.requestHealthRead(
      gatewayRequest: req(id: 'da', action: 'read_health', authorized: false),
      patientId: 'patient-1',
    );
    expect(deniedAuth.executed, isFalse);
    expect(deniedAuth.decision.reasonCode, 'UNAUTHORIZED');

    final deniedConsent = await entry.requestHealthRead(
      gatewayRequest: req(id: 'dc', action: 'read_health', consent: false),
      patientId: 'patient-1',
    );
    expect(deniedConsent.decision.kind, LioGatewayDecisionKind.requireConsent);

    final purpose = await entry.requestHealthRead(
      gatewayRequest: req(
        id: 'dp',
        action: 'read_health',
        purpose: 'illegal_purpose',
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

  test('canonical ownership + production composition uses Persistent', () {
    final bundle = _assemble(
      store: _encStore(),
      secretStore: secrets,
    );
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
    expect(
      identical(
        bundle.healthObservationService.repository,
        bundle.healthObservationRepository,
      ),
      isTrue,
    );
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
  });

  test('InMemory forbidden as production unified path marker', () {
    expect(
      InMemoryHealthObservationRepository.testOnlyMarker,
      contains('TEST_ONLY'),
    );
  });

  test('PHR export/share/print/control remain non-success', () async {
    final export = await entry.requestClinicalPhrExport(
      gatewayRequest: req(
        id: 'ex',
        action: 'export_phr',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    final share = await entry.requestClinicalOrPrivateShare(
      gatewayRequest: req(
        id: 'sh',
        action: 'share_clinical',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    final printOp = await entry.requestSensitivePrint(
      gatewayRequest: req(id: 'pr', action: 'print'),
    );
    final ctrl = await entry.requestDeviceControl(
      gatewayRequest: req(
        id: 'ct',
        action: 'device_control',
        purpose: 'device_status',
        scope: 'device_discovery',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(export.value!.reasonCode, 'NOT_IMPLEMENTED');
    expect(share.value!.reasonCode, 'NOT_IMPLEMENTED');
    expect(printOp.value!.reasonCode, 'UNSUPPORTED_OPERATION');
    expect(ctrl.value!.reasonCode, 'UNSUPPORTED_OPERATION');
  });
}
