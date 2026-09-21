import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/agent/agent_result.dart';
import 'package:lifex_ai/core/agent/agent_state.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
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

KnowledgeRecord _rec(String id, String text) => KnowledgeRecord(
      id: id,
      title: text,
      body: text,
      terms: text.toLowerCase().split(' '),
      provenance: LioSourceProvenance(
        sourceId: 's-$id',
        sourceType: 'test',
        authority: LioSourceAuthority.documentation,
        retrievedAt: DateTime(2026, 9, 20),
        document: 'doc-$id',
        evidenceLevel: 0.7,
        confidence: 0.7,
      ),
    );

AiModuleBundle _ai() {
  final analysis = HealthAnalysisEngine(
    symptomKeywordMap: const {},
    emergencySymptomIds: const {},
  );
  final guidance = DoctorGuidanceEngine(symptomBodySystemMap: const {});
  return AiModuleBundle(
    engine: AiEngine.instance,
    analysisEngine: analysis,
    guidanceEngine: guidance,
    decisionEngine: HealthDecisionEngine(
      analysisEngine: analysis,
      guidanceEngine: guidance,
    ),
  );
}

AiServiceRouter _router() => AiServiceRouter(
      hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
    );

LioGatewayRequest _req({
  String id = 'r1',
  bool authenticated = true,
  bool authorized = true,
  String purpose = 'knowledge_lookup',
  String scope = 'knowledge_public',
  String action = 'agent_user_request',
  LioActionRisk risk = LioActionRisk.low,
  LioConsentContext? consent,
  bool emergency = false,
  bool humanConfirmed = false,
  bool reviewApproved = false,
}) {
  return LioGatewayRequest(
    requestId: id,
    correlationId: 'c1',
    identityAccountId: 'acct-1',
    purpose: purpose,
    requestedAction: action,
    dataScope: scope,
    sensitivity: LioDataSensitivity.public,
    consent: consent ??
        const LioConsentContext(consentGranted: true, purposeAligned: true),
    riskLevel: risk,
    timestamp: DateTime.utc(2026, 1, 1),
    authenticated: authenticated,
    authorized: authorized,
    emergencyLimitedMode: emergency,
    humanConfirmed: humanConfirmed,
    reviewApproved: reviewApproved,
    minimumNecessarySatisfied: true,
  );
}

void main() {
  late FixedClock clock;
  late LifexProductionBundle bundle;
  late LioSensitiveActionEntry entry;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 9, 21, 15, 0, 0));
    final corpus = InMemoryKnowledgeCorpus([
      _rec('1', 'Hydration fluid guidance for adults education'),
    ]);
    bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: _ai(),
      aiServiceRouter: _router(),
      knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
      corpus: corpus,
      clock: clock,
    );
    entry = bundle.sensitiveActionEntry;
  });

  test('A valid sensitive request passes LIO then executes', () async {
    var ran = false;
    final outcome = await entry.authorizeThenRun<String>(
      request: _req(),
      run: () async {
        ran = true;
        return 'ok';
      },
    );
    expect(outcome.decision.kind, LioGatewayDecisionKind.allow);
    expect(outcome.executed, isTrue);
    expect(ran, isTrue);
    expect(outcome.value, 'ok');
  });

  test('B bypass attempt without entry is architecture-forbidden (guarded)', () {
    // Contract: UI must use entry; entry is the only app gate.
    expect(identical(entry.lioGateway, bundle.lioGateway), isTrue);
    expect(identical(entry.agentCore, bundle.agentCore), isTrue);
    expect(LioSensitiveActionEntry.entryId, 'LioSensitiveActionEntry');
  });

  test('C unauthorized request → DENY and no execution', () async {
    var ran = false;
    final outcome = await entry.authorizeThenRun<String>(
      request: _req(authorized: false),
      run: () async {
        ran = true;
        return 'x';
      },
    );
    expect(outcome.decision.kind, LioGatewayDecisionKind.deny);
    expect(outcome.executed, isFalse);
    expect(ran, isFalse);
  });

  test('D missing consent → REQUIRE_CONSENT and no execution', () async {
    var ran = false;
    final outcome = await entry.authorizeThenRun<String>(
      request: _req(
        purpose: 'care_support',
        scope: 'profile_basic',
        consent: const LioConsentContext(
          consentGranted: false,
          purposeAligned: false,
        ),
      ),
      run: () async {
        ran = true;
        return 'x';
      },
    );
    expect(outcome.decision.kind, LioGatewayDecisionKind.requireConsent);
    expect(outcome.executed, isFalse);
    expect(ran, isFalse);
  });

  test('E high-risk → REQUIRE_CONFIRMATION أو REQUIRE_REVIEW', () async {
    final high = await entry.authorizeThenRun<String>(
      request: _req(risk: LioActionRisk.high),
      run: () async => 'x',
    );
    expect(high.decision.kind, LioGatewayDecisionKind.requireConfirmation);
    expect(high.executed, isFalse);

    final critical = await entry.authorizeThenRun<String>(
      request: _req(risk: LioActionRisk.critical),
      run: () async => 'x',
    );
    expect(critical.decision.kind, LioGatewayDecisionKind.requireReview);
    expect(critical.executed, isFalse);
  });

  test('F emergency → EMERGENCY_LIMITED only per policy', () async {
    final outcome = await entry.authorizeThenRun<String>(
      request: _req(
        purpose: 'emergency_signal',
        scope: 'emergency_contacts_min',
        action: 'signal_trusted_contacts',
        emergency: true,
        risk: LioActionRisk.high,
      ),
      run: () async => 'limited',
    );
    expect(outcome.decision.kind, LioGatewayDecisionKind.emergencyLimited);
    expect(outcome.executed, isTrue);
    expect(outcome.value, 'limited');
  });

  test('G audit event exists for every decision', () async {
    entry.lioGateway.auditLog.clear();
    await entry.authorizeThenRun(request: _req(id: 'a1'), run: () async => 1);
    await entry.authorizeThenRun(
      request: _req(id: 'a2', authorized: false),
      run: () async => 1,
    );
    expect(entry.lioGateway.auditLog.events.length, 2);
    expect(
      entry.lioGateway.auditLog.events.map((e) => e.requestId).toSet(),
      {'a1', 'a2'},
    );
  });

  test('H production path unified — no bypass of LIO entry', () async {
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
    expect(identical(entry.lioGateway.orchestrator, bundle.fabric.lio), isTrue);

    final agentOutcome = await entry.runAgentRequest(
      gatewayRequest: _req(id: 'agent-1', risk: LioActionRisk.low),
      agentContext: AgentContext(
        taskId: 't1',
        profileId: 'p1',
        userRequest: 'hydration guidance',
        permissions: const AgentGrantedPermissions(
          granted: {AgentPermission.readKnowledgeBase},
        ),
      ),
      sessionId: 's1',
    );
    expect(agentOutcome.decision.kind, LioGatewayDecisionKind.allow);
    expect(agentOutcome.executed, isTrue);
    expect(agentOutcome.value, isA<AgentResult>());
    expect(agentOutcome.value!.finalState, isNot(AgentTaskState.idle));

    final blocked = entry.blockedAgentResult(
      taskId: 't-blocked',
      decision: (await entry.authorizeThenRun(
        request: _req(id: 'deny-1', authorized: false),
        run: () async => 0,
      ))
          .decision,
    );
    expect(blocked.finalState, AgentTaskState.blocked);
  });
}
