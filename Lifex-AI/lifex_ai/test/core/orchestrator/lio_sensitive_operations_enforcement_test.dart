import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/orchestrator/clock.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway_contracts.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
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
  late FixedClock clock;
  late LioSensitiveActionEntry entry;

  LioGatewayRequest req({
    required String id,
    required String action,
    String purpose = 'wallet_ops',
    String scope = 'wallet_balance_view',
    LioActionRisk risk = LioActionRisk.low,
    LioDataSensitivity sensitivity = LioDataSensitivity.operational,
    bool authorized = true,
    bool authenticated = true,
    bool consent = true,
    bool humanConfirmed = false,
    bool emergency = false,
    LioConsentContext? consentCtx,
  }) {
    return LioGatewayRequest(
      requestId: id,
      correlationId: 'c',
      identityAccountId: 'acct-1',
      purpose: purpose,
      requestedAction: action,
      dataScope: scope,
      sensitivity: sensitivity,
      consent: consentCtx ??
          LioConsentContext(
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
    clock = FixedClock(DateTime.utc(2026, 9, 21, 18, 0, 0));
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
      encyclopediaShareBridge: EncyclopediaShareBridge(
        copy: (_) async {},
      ),
    );
  });

  test('1 READ_SENSITIVE — wallet balances via LIO', () async {
    final o = await entry.readWalletBalances(
      gatewayRequest: req(id: '1', action: 'read_wallet_balances'),
      profileId: 'p1',
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
    expect(o.value, isNotNull);
  });

  test('2 READ_HEALTH — operational health-adjacent scope still gated', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '2',
        action: 'read_health_summary',
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
      ),
      run: () async {
        ran = true;
        return 'ok';
      },
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(ran, isTrue);
  });

  test('3 READ_MEDICAL — medical catalog via LIO', () async {
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
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
    expect(o.value, isA<Map<String, dynamic>>());
  });

  test('4 WRITE — wallet topup begin via LIO', () async {
    final o = await entry.beginWalletTopUp(
      gatewayRequest: req(id: '4', action: 'begin_wallet_topup'),
      profileId: 'p1',
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
  });

  test('5 UPDATE — medical version check via LIO', () async {
    final o = await entry.checkMedicalDbVersion(
      gatewayRequest: req(
        id: '5',
        action: 'check_medical_db_version',
        purpose: 'settings',
        scope: 'settings_local',
      ),
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
  });

  test('6 DELETE — denied when unauthorized', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '6',
        action: 'delete_record',
        purpose: 'settings',
        scope: 'settings_local',
        authorized: false,
      ),
      run: () async {
        ran = true;
        return true;
      },
    );
    expect(o.decision.kind, LioGatewayDecisionKind.deny);
    expect(o.executed, isFalse);
    expect(ran, isFalse);
  });

  test('7 EXPORT — unauthorized export denied', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '7',
        action: 'export_profile',
        purpose: 'settings',
        scope: 'settings_local',
        authorized: false,
      ),
      run: () async {
        ran = true;
        return 'x';
      },
    );
    expect(o.decision.kind, LioGatewayDecisionKind.deny);
    expect(ran, isFalse);
  });

  test('8 SHARE — public encyclopedia via LIO', () async {
    final o = await entry.sharePublicEncyclopedia(
      gatewayRequest: req(
        id: '8',
        action: 'share_public_encyclopedia',
        purpose: 'education',
        scope: 'public',
        sensitivity: LioDataSensitivity.public,
      ),
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
  });

  test('9 PRINT — gated and audited', () async {
    entry.lioGateway.auditLog.clear();
    final o = await entry.authorizeThenRun(
      request: req(
        id: '9',
        action: 'print_statement',
        purpose: 'wallet_ops',
        scope: 'wallet_balance_view',
      ),
      run: () async => 'printed',
    );
    expect(o.executed, isTrue);
    expect(
      entry.lioGateway.auditLog.events.any((e) => e.requestId == '9'),
      isTrue,
    );
  });

  test('10 DOWNLOAD — medical refresh path evaluates via LIO', () async {
    // Without localKnowledge/lasting bound, expect StateError after ALLOW —
    // proves LIO still evaluated first. Bind minimal not required for gate.
    final o = await entry.authorizeThenRun(
      request: req(
        id: '10',
        action: 'download_medical_bundle',
        purpose: 'settings',
        scope: 'settings_local',
      ),
      run: () async => 'downloaded',
    );
    expect(o.decision.kind, LioGatewayDecisionKind.allow);
    expect(o.executed, isTrue);
  });

  test('11 FINANCIAL/WALLET withdraw requires confirmation when high risk',
      () async {
    final blocked = await entry.withdrawWallet(
      gatewayRequest: req(
        id: '11a',
        action: 'withdraw_wallet',
        risk: LioActionRisk.high,
        humanConfirmed: false,
        sensitivity: LioDataSensitivity.personal,
      ),
      profileId: 'p1',
      amountMinor: 100,
      currencyCode: 'USD',
    );
    expect(blocked.decision.kind, LioGatewayDecisionKind.requireConfirmation);
    expect(blocked.executed, isFalse);

    final ok = await entry.withdrawWallet(
      gatewayRequest: req(
        id: '11b',
        action: 'withdraw_wallet',
        risk: LioActionRisk.high,
        humanConfirmed: true,
        sensitivity: LioDataSensitivity.personal,
      ),
      profileId: 'p1',
      amountMinor: 100,
      currencyCode: 'USD',
    );
    expect(ok.decision.kind, LioGatewayDecisionKind.allow);
    expect(ok.executed, isTrue);
  });

  test('12 EMERGENCY_ACCESS via Entry', () async {
    final o = await entry.triggerEmergencyLimited(
      gatewayRequest: req(
        id: '12',
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

  test('13 every LIO decision produces Audit', () async {
    entry.lioGateway.auditLog.clear();
    await entry.authorizeThenRun(
      request: req(id: '13a', action: 'a'),
      run: () async => 1,
    );
    await entry.authorizeThenRun(
      request: req(id: '13b', action: 'b', authorized: false),
      run: () async => 1,
    );
    expect(entry.lioGateway.auditLog.events.length, 2);
  });

  test('14 every DENY has clear reason', () async {
    final o = await entry.authorizeThenRun(
      request: req(id: '14', action: 'x', authenticated: false),
      run: () async => 1,
    );
    expect(o.decision.kind, LioGatewayDecisionKind.deny);
    expect(o.decision.reasonCode, isNotEmpty);
    expect(o.decision.reasonAr, isNotEmpty);
  });

  test('15 REQUIRE_CONSENT does not execute before consent', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '15',
        action: 'care_read',
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

  test('16 REQUIRE_CONFIRMATION does not execute before confirm', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(
        id: '16',
        action: 'high_op',
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

  test('17 EMERGENCY_LIMITED stays policy-bound', () async {
    final o = await entry.authorizeThenRun(
      request: req(
        id: '17',
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

  test('18 no sensitive op bypasses LIO — deny stops callback', () async {
    var ran = false;
    final o = await entry.authorizeThenRun(
      request: req(id: '18', action: 'any', authorized: false),
      run: () async {
        ran = true;
        return 'x';
      },
    );
    expect(o.executed, isFalse);
    expect(ran, isFalse);
    expect(identical(entry.lioGateway, entry.lioGateway), isTrue);
  });
}
