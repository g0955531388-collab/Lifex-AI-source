import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';
import 'package:lifex_ai/core/health_data/health_observation_application_service.dart';
import 'package:lifex_ai/core/health_data/in_memory_health_observation_repository.dart';
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
import 'package:lifex_ai/features/emergency/emergency_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_message_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_phone_contacts_registry.dart';
import 'package:lifex_ai/features/emergency/risk_level_engine.dart';
import 'package:lifex_ai/features/finance/billing_exemption_policy.dart';
import 'package:lifex_ai/features/finance/payment_controller.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/subscription_billing_manager.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';
import 'package:lifex_ai/features/finance/transaction_service.dart';
import 'package:lifex_ai/features/finance/wallet_manager.dart';
import 'package:lifex_ai/features/outreach/encyclopedia_share_bridge.dart';

class _FakeDb implements MedicalDatabaseManager {
  @override
  Future<Map<String, dynamic>> readBundleFile(String fileName) async =>
      {'medications': <Map<String, dynamic>>[]};

  @override
  Future<String?> checkForNewerVersion() async => null;

  @override
  Future<MedicalUpdateResult> downloadAndUpdateBundle() async =>
      const MedicalUpdateResult.failure('no remote in test');

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

  LioGatewayRequest req({
    required String id,
    required String action,
    String purpose = 'settings',
    String scope = 'settings_local',
    LioActionRisk risk = LioActionRisk.low,
    LioDataSensitivity sensitivity = LioDataSensitivity.operational,
    bool authorized = true,
    bool authenticated = true,
    bool consent = true,
    bool humanConfirmed = false,
    bool emergency = false,
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
      emergencyLimitedMode: emergency,
      minimumNecessarySatisfied: true,
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
    final ledger = TransactionLedger();
    final wallet = WalletManager(
      gatewayClient: SandboxPaymentGatewayClient(),
      ledger: ledger,
    );
    entry = bundle.sensitiveActionEntry.bindApplicationOps(
      walletManager: wallet,
      transactionService: TransactionService(ledger: ledger),
      paymentController: PaymentController(walletManager: wallet),
      subscriptionBillingManager: SubscriptionBillingManager(
        ledger: ledger,
        exemptionPolicy: const BillingExemptionPolicy(),
      ),
      medicalDatabaseManager: _FakeDb(),
      emergencyManager: EmergencyManager(
        riskLevelEngine: RiskLevelEngine(),
        messageManager: EmergencyMessageManager(
          emergencyContactsRegistry: EmergencyPhoneContactsRegistry(),
          sendFunction: (_, __) async => false,
        ),
      ),
      encyclopediaShareBridge: EncyclopediaShareBridge(copy: (_) async {}),
      healthObservationService: HealthObservationApplicationService(
        repository: InMemoryHealthObservationRepository(),
      ),
    );
  });

  test('1 READ_SENSITIVE — wallet balances', () async {
    final o = await entry.readWalletBalances(
      gatewayRequest: req(
        id: '1',
        action: 'read_wallet_balances',
        purpose: 'wallet_ops',
        scope: 'wallet_balance_view',
        sensitivity: LioDataSensitivity.personal,
      ),
      profileId: 'p1',
    );
    expect(o.executed, isTrue);
  });

  test('2 READ_HEALTH — real Application path', () async {
    final o = await entry.requestHealthRead(
      gatewayRequest: req(
        id: '2',
        action: 'read_health',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
      ),
      patientId: 'patient-1',
    );
    expect(o.executed, isTrue);
    expect(o.value!.success, isTrue);
  });

  test('3 READ_MEDICAL', () async {
    final o = await entry.readMedicalBundle(
      gatewayRequest: req(
        id: '3',
        action: 'read_medical_catalog',
        purpose: 'knowledge_lookup',
        scope: 'knowledge_public',
        sensitivity: LioDataSensitivity.public,
      ),
      fileName: MedicalBundleFiles.medications,
    );
    expect(o.executed, isTrue);
  });

  test('4 WRITE — HealthObservation real execution', () async {
    final o = await entry.requestSensitiveWrite(
      gatewayRequest: req(
        id: '4',
        action: 'write_health_obs',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
      ),
      observation: HealthObservation(
        observationId: 'obs-4',
        patientId: 'patient-1',
        conceptId: 'hr',
        value: 72,
        unit: 'bpm',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'test',
        provenanceId: '',
      ),
      provenance: ProvenanceRecord(
        sourceId: 'prov-4',
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(o.executed, isTrue);
    expect(o.value!.success, isTrue);
  });

  test('5 UPDATE — HealthObservation real execution', () async {
    await entry.requestSensitiveWrite(
      gatewayRequest: req(
        id: '5w',
        action: 'write_health_obs',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
      ),
      observation: HealthObservation(
        observationId: 'obs-5',
        patientId: 'patient-1',
        conceptId: 'hr',
        value: 70,
        unit: 'bpm',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'test',
        provenanceId: '',
      ),
      provenance: ProvenanceRecord(
        sourceId: 'prov-5',
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final o = await entry.requestSensitiveUpdate(
      gatewayRequest: req(
        id: '5',
        action: 'update_health_obs',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
      ),
      observation: HealthObservation(
        observationId: 'obs-5',
        patientId: 'patient-1',
        conceptId: 'hr',
        value: 74,
        unit: 'bpm',
        observedAt: DateTime.utc(2026, 1, 2),
        sourceType: 'manual',
        sourceId: 'test',
        provenanceId: 'prov-5',
      ),
      provenance: ProvenanceRecord(
        sourceId: 'prov-5',
        sourceName: 'test',
        sourceType: 'manual',
        version: '1',
        retrievedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(o.value!.success, isTrue);
  });

  test('6 DELETE — NOT_IMPLEMENTED and ≠ ARCHIVE', () async {
    final o = await entry.requestSensitiveDelete(
      gatewayRequest: req(
        id: '6',
        action: 'delete_phr',
        purpose: 'settings',
        scope: 'settings_local',
        sensitivity: LioDataSensitivity.personal,
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(o.executed, isTrue);
    expect(o.value!.succeeded, isFalse);
    expect(o.value!.reasonCode, 'NOT_IMPLEMENTED');
    expect(o.value!.opKind, LioLifecycleOpKind.delete);
    expect(o.value!.opKind != LioLifecycleOpKind.archive, isTrue);
  });

  test('7 ARCHIVE — NOT_IMPLEMENTED and ≠ DELETE', () async {
    final o = await entry.requestSensitiveArchive(
      gatewayRequest: req(
        id: '7',
        action: 'archive_phr',
        purpose: 'settings',
        scope: 'settings_local',
        sensitivity: LioDataSensitivity.personal,
      ),
    );
    expect(o.value!.succeeded, isFalse);
    expect(o.value!.opKind, LioLifecycleOpKind.archive);
    expect(o.value!.opKind != LioLifecycleOpKind.delete, isTrue);
  });

  test('8 EXPORT clinical/PHR — NOT_IMPLEMENTED ≠ SHARE', () async {
    final o = await entry.requestClinicalPhrExport(
      gatewayRequest: req(
        id: '8',
        action: 'export_phr',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(o.value!.succeeded, isFalse);
    expect(o.value!.reasonCode, 'NOT_IMPLEMENTED');
    expect(o.value!.opKind, LioLifecycleOpKind.export);
    expect(o.value!.opKind != LioLifecycleOpKind.share, isTrue);
  });

  test('9 SHARE public encyclopedia implemented', () async {
    final o = await entry.sharePublicEncyclopedia(
      gatewayRequest: req(
        id: '9',
        action: 'share_public_encyclopedia',
        purpose: 'education',
        scope: 'public',
        sensitivity: LioDataSensitivity.public,
      ),
    );
    expect(o.executed, isTrue);
  });

  test('10 PRINT — UNSUPPORTED_OPERATION', () async {
    final o = await entry.requestSensitivePrint(
      gatewayRequest: req(id: '10', action: 'print_sensitive'),
    );
    expect(o.value!.succeeded, isFalse);
    expect(o.value!.reasonCode, 'UNSUPPORTED_OPERATION');
  });

  test('11 DOWNLOAD medical via LIO', () async {
    final o = await entry.authorizeThenRun(
      request: req(
        id: '11',
        action: 'download_medical_bundle',
        purpose: 'settings',
        scope: 'settings_local',
      ),
      run: () async => 'ok',
    );
    expect(o.executed, isTrue);
  });

  test('12 FINANCIAL withdraw gated', () async {
    final o = await entry.withdrawWallet(
      gatewayRequest: req(
        id: '12',
        action: 'withdraw_wallet',
        purpose: 'wallet_ops',
        scope: 'wallet_balance_view',
        sensitivity: LioDataSensitivity.personal,
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      profileId: 'p1',
      amountMinor: 100,
      currencyCode: 'USD',
    );
    expect(o.executed, isTrue);
  });

  test('13 EMERGENCY_ACCESS limited', () async {
    final o = await entry.triggerEmergencyLimited(
      gatewayRequest: req(
        id: '13',
        action: 'signal_trusted_contacts',
        purpose: 'emergency_signal',
        scope: 'emergency_contacts_min',
        risk: LioActionRisk.high,
        emergency: true,
        humanConfirmed: true,
        sensitivity: LioDataSensitivity.personal,
      ),
      profileId: 'p1',
      reasonAr: 'test',
    );
    expect(o.decision.kind, LioGatewayDecisionKind.emergencyLimited);
    expect(o.executed, isTrue);
  });

  test('14 CONTROL — UNSUPPORTED no driver', () async {
    final o = await entry.requestDeviceControl(
      gatewayRequest: req(
        id: '14',
        action: 'device_control',
        purpose: 'device_status',
        scope: 'device_discovery',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(o.value!.succeeded, isFalse);
    expect(o.value!.reasonCode, 'UNSUPPORTED_OPERATION');
    expect(o.value!.opKind, LioLifecycleOpKind.control);
  });

  test('15 DENY with audit reason', () async {
    entry.lioGateway.auditLog.clear();
    final o = await entry.requestSensitiveDelete(
      gatewayRequest: req(id: '15', action: 'x', authenticated: false),
    );
    expect(o.executed, isFalse);
    expect(o.decision.kind, LioGatewayDecisionKind.deny);
    expect(o.decision.reasonCode, isNotEmpty);
    expect(
      entry.lioGateway.auditLog.events.any((e) => e.requestId == '15'),
      isTrue,
    );
  });

  test('16 REQUIRE_CONSENT blocks execution', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '16',
        action: 'care',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
        consent: false,
      ),
      run: () async {
        ran = true;
        return 1;
      },
    );
    expect(o.decision.kind, LioGatewayDecisionKind.requireConsent);
    expect(ran, isFalse);
  });

  test('17 REQUIRE_CONFIRMATION blocks execution', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '17',
        action: 'high',
        risk: LioActionRisk.high,
        humanConfirmed: false,
      ),
      run: () async {
        ran = true;
        return 1;
      },
    );
    expect(o.decision.kind, LioGatewayDecisionKind.requireConfirmation);
    expect(ran, isFalse);
  });

  test('18 EMERGENCY_LIMITED remains policy constrained', () async {
    final o = await entry.authorizeThenRun(
      request: req(
        id: '18',
        action: 'signal_trusted_contacts',
        purpose: 'emergency_signal',
        scope: 'emergency_contacts_min',
        risk: LioActionRisk.high,
        emergency: true,
      ),
      run: () async => 'limited',
    );
    expect(o.decision.kind, LioGatewayDecisionKind.emergencyLimited);
    expect(o.executed, isTrue);
  });

  test('19 unsupported execution returns explicit non-success', () async {
    final printR = await entry.requestSensitivePrint(
      gatewayRequest: req(id: '19a', action: 'print'),
    );
    final ctrl = await entry.requestDeviceControl(
      gatewayRequest: req(
        id: '19b',
        action: 'ctrl',
        purpose: 'device_status',
        scope: 'device_discovery',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    final export = await entry.requestClinicalPhrExport(
      gatewayRequest: req(
        id: '19c',
        action: 'export',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
    );
    expect(printR.value!.succeeded, isFalse);
    expect(ctrl.value!.succeeded, isFalse);
    expect(export.value!.succeeded, isFalse);
    expect(printR.value!.reasonCode, 'UNSUPPORTED_OPERATION');
    expect(ctrl.value!.reasonCode, 'UNSUPPORTED_OPERATION');
    expect(export.value!.reasonCode, 'NOT_IMPLEMENTED');
  });

  test('20 no sensitive operation bypasses LIO', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(id: '20', action: 'any', authorized: false),
      run: () async {
        ran = true;
        return 'x';
      },
    );
    expect(o.executed, isFalse);
    expect(ran, isFalse);
  });
}
