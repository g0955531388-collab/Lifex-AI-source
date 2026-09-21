import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
import 'package:lifex_ai/core/health_data/health_observation_application_service.dart';
import 'package:lifex_ai/core/health_data/health_repository.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/orchestrator/clock.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway_contracts.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_lifecycle_contracts.dart';
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
  late LioSensitiveActionEntry entry;
  late InMemoryHealthRepository repo;

  LioGatewayRequest req({
    required String id,
    required String action,
    String purpose = 'care_support',
    String scope = 'profile_basic',
    LioActionRisk risk = LioActionRisk.low,
    LioDataSensitivity sensitivity = LioDataSensitivity.personal,
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
      sensitivity: sensitivity,
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
    HealthRecordStatus status = HealthRecordStatus.active,
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
      status: status,
    );
  }

  setUp(() {
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
    final router = AiServiceRouter(
      hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
    );
    final bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: ai,
      aiServiceRouter: router,
      knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
      corpus: corpus,
      clock: clock,
    );
    repo = InMemoryHealthRepository();
    entry = bundle.sensitiveActionEntry.bindApplicationOps(
      healthObservationService: HealthObservationApplicationService(
        repository: repo,
      ),
    );
  });

  test('READ_HEALTH via Entry → Application → Repository', () async {
    await repo.ensureProvenance(prov('prov-1'));
    await repo.saveObservation(obs(id: 'o1'));
    final o = await entry.requestHealthRead(
      gatewayRequest: req(id: 'r1', action: 'read_health'),
      patientId: 'patient-1',
    );
    expect(o.executed, isTrue);
    expect(o.value!.success, isTrue);
    expect(o.value!.observations, hasLength(1));
  });

  test('WRITE HealthObservation real execution', () async {
    final o = await entry.requestSensitiveWrite(
      gatewayRequest: req(id: 'w1', action: 'write_health_obs'),
      observation: obs(id: 'o2', provenanceId: ''),
      provenance: prov('prov-w'),
    );
    expect(o.executed, isTrue);
    expect(o.value!.success, isTrue);
    expect(repo.store.observations.containsKey('o2'), isTrue);
  });

  test('UPDATE HealthObservation real execution', () async {
    await repo.ensureProvenance(prov('prov-1'));
    await repo.saveObservation(obs(id: 'o3'));
    final o = await entry.requestSensitiveUpdate(
      gatewayRequest: req(id: 'u1', action: 'update_health_obs'),
      observation: obs(id: 'o3', value: 118),
      provenance: prov('prov-1'),
    );
    expect(o.value!.success, isTrue);
    expect(repo.store.observations['o3']!.value, 118);
  });

  test('ARCHIVE observation soft status ≠ DELETE PHR', () async {
    await repo.ensureProvenance(prov('prov-1'));
    await repo.saveObservation(obs(id: 'o4'));
    final archived = await entry.requestHealthObservationArchive(
      gatewayRequest: req(id: 'a1', action: 'archive_health_obs'),
      observationId: 'o4',
    );
    expect(archived.value!.success, isTrue);
    expect(
      repo.store.observations['o4']!.status,
      HealthRecordStatus.archived,
    );
    final phrDelete = await entry.requestSensitiveDelete(
      gatewayRequest: req(
        id: 'a2',
        action: 'delete_phr',
        purpose: 'settings',
        scope: 'settings_local',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(phrDelete.value!.reasonCode, 'NOT_IMPLEMENTED');
    expect(phrDelete.value!.opKind, LioLifecycleOpKind.delete);
  });

  test('EXPORT / SHARE clinical / PRINT / CONTROL stay non-success', () async {
    final export = await entry.requestClinicalPhrExport(
      gatewayRequest: req(
        id: 'e1',
        action: 'export_phr',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    final share = await entry.requestClinicalOrPrivateShare(
      gatewayRequest: req(
        id: 's1',
        action: 'share_clinical',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    final printOp = await entry.requestSensitivePrint(
      gatewayRequest: req(id: 'p1', action: 'print'),
    );
    final ctrl = await entry.requestDeviceControl(
      gatewayRequest: req(
        id: 'c1',
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

  test('Consent denial blocks Application', () async {
    var ran = false;
    final o = await entry.requestHealthRead(
      gatewayRequest: req(id: 'cd', action: 'read_health', consent: false),
      patientId: 'patient-1',
    );
    expect(o.executed, isFalse);
    expect(o.decision.kind, LioGatewayDecisionKind.requireConsent);
    expect(ran, isFalse);
  });

  test('Authorization denial', () async {
    final o = await entry.requestHealthRead(
      gatewayRequest: req(id: 'ad', action: 'read_health', authorized: false),
      patientId: 'patient-1',
    );
    expect(o.executed, isFalse);
    expect(o.decision.kind, LioGatewayDecisionKind.deny);
    expect(o.decision.reasonCode, 'UNAUTHORIZED');
  });

  test('Purpose mismatch', () async {
    final o = await entry.requestHealthRead(
      gatewayRequest: req(
        id: 'pm',
        action: 'read_health',
        purpose: 'not_a_real_purpose',
      ),
      patientId: 'patient-1',
    );
    expect(o.executed, isFalse);
    expect(o.decision.reasonCode, 'PURPOSE_VIOLATION');
  });

  test('Data-scope violation', () async {
    final o = await entry.requestHealthRead(
      gatewayRequest: req(
        id: 'ds',
        action: 'read_health',
        scope: 'full_phr_dump',
      ),
      patientId: 'patient-1',
    );
    expect(o.executed, isFalse);
    expect(o.decision.reasonCode, 'SCOPE_VIOLATION');
  });

  test('Risk requiring confirmation blocks', () async {
    final o = await entry.requestSensitiveDelete(
      gatewayRequest: req(
        id: 'rk',
        action: 'delete_phr',
        purpose: 'settings',
        scope: 'settings_local',
        risk: LioActionRisk.high,
        humanConfirmed: false,
      ),
    );
    expect(o.executed, isFalse);
    expect(o.decision.kind, LioGatewayDecisionKind.requireConfirmation);
  });

  test('Risk requiring review for critical', () async {
    final o = await entry.requestDeviceControl(
      gatewayRequest: req(
        id: 'rr',
        action: 'device_control',
        purpose: 'device_status',
        scope: 'device_discovery',
        risk: LioActionRisk.critical,
        humanConfirmed: true,
      ),
    );
    expect(o.executed, isFalse);
    expect(o.decision.kind, LioGatewayDecisionKind.requireReview);
  });

  test('Audit reason recorded on deny', () async {
    entry.lioGateway.auditLog.clear();
    await entry.requestHealthRead(
      gatewayRequest: req(id: 'au', action: 'read_health', authenticated: false),
      patientId: 'patient-1',
    );
    expect(
      entry.lioGateway.auditLog.events.any((e) => e.requestId == 'au'),
      isTrue,
    );
  });

  test('unbound service fails explicitly after LIO allow', () async {
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
    final unbound = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: ai,
      aiServiceRouter: AiServiceRouter(
        hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
      ),
      knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
      corpus: corpus,
      clock: clock,
    ).sensitiveActionEntry;
    final o = await unbound.requestHealthRead(
      gatewayRequest: req(id: 'ub', action: 'read_health'),
      patientId: 'patient-1',
    );
    expect(o.executed, isTrue);
    expect(o.value!.success, isFalse);
    expect(o.value!.messageAr, contains('unbound'));
  });

  group('architecture bypasses', () {
    List<File> dartFiles(Directory dir) {
      if (!dir.existsSync()) return const [];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    String norm(String p) => p.replaceAll('\\', '/');

    test('no direct UI→Repository / UI→DB', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(r'HealthDataRepository|InMemoryHealthRepository|sqflite')
            .hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no Agent→Repository/DB and no LIO→driver', () {
      for (final path in [
        'lib/core/agent',
        'lib/core/orchestrator/lio_gateway.dart',
      ]) {
        final files = path.endsWith('.dart')
            ? [File(path)]
            : dartFiles(Directory(path));
        for (final f in files) {
          final t = f.readAsStringSync();
          expect(t.contains('InMemoryHealthRepository('), isFalse,
              reason: f.path);
          expect(RegExp(r'\.executeControl\s*\(').hasMatch(t), isFalse,
              reason: f.path);
        }
      }
    });

    test('all remaining UI delete paths gated', () {
      for (final path in [
        'lib/screens/medication_alarm_screen.dart',
        'lib/screens/emergency_contacts_screen.dart',
        'lib/screens/personal_shelf_screen.dart',
        'lib/screens/thumbnail_manage_screen.dart',
        'lib/screens/booking_workspace_screen.dart',
        'lib/screens/unit_branch_records_screen.dart',
      ]) {
        final t = File(path).readAsStringSync();
        expect(t.contains('LioSensitiveActionEntry'), isTrue, reason: path);
        expect(t.contains('authorizeThenRun'), isTrue, reason: path);
      }
    });
  });
}
