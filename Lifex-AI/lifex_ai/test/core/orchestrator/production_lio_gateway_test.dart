import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/core/orchestrator/clock.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway_contracts.dart';
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

LioGatewayRequest _base({
  String requestId = 'r1',
  String correlationId = 'c1',
  String identity = 'acct-1',
  String purpose = 'knowledge_lookup',
  String action = 'search_public_knowledge',
  String scope = 'knowledge_public',
  LioDataSensitivity sensitivity = LioDataSensitivity.public,
  LioConsentContext? consent,
  LioActionRisk risk = LioActionRisk.low,
  bool authenticated = true,
  bool authorized = true,
  bool emergency = false,
  bool humanConfirmed = false,
  bool reviewApproved = false,
  bool approvalRequirement = false,
  bool stepUpSatisfied = true,
  bool minimumNecessary = true,
  Map<String, Object?> fields = const {},
}) {
  return LioGatewayRequest(
    requestId: requestId,
    correlationId: correlationId,
    identityAccountId: identity,
    purpose: purpose,
    requestedAction: action,
    dataScope: scope,
    sensitivity: sensitivity,
    consent: consent ??
        const LioConsentContext(consentGranted: true, purposeAligned: true),
    riskLevel: risk,
    timestamp: DateTime.utc(2026, 1, 1),
    authenticated: authenticated,
    authorized: authorized,
    emergencyLimitedMode: emergency,
    humanConfirmed: humanConfirmed,
    reviewApproved: reviewApproved,
    approvalRequirement: approvalRequirement,
    stepUpSatisfied: stepUpSatisfied,
    declaredFields: fields,
    minimumNecessarySatisfied: minimumNecessary,
  );
}

void main() {
  late FixedClock clock;
  late ProductionLioGateway gateway;
  late LifexProductionBundle bundle;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 9, 21, 12, 0, 0));
    final corpus = InMemoryKnowledgeCorpus([
      _rec('1', 'Hydration fluid guidance for adults education'),
    ]);
    final engine = LifexKnowledgeEngine(corpus: corpus);
    bundle = LifexProductionComposition.assemble(
      medicalDatabaseManager: _FakeDb(),
      aiModuleBundle: _ai(),
      aiServiceRouter: _router(),
      knowledgeEngine: engine,
      corpus: corpus,
      clock: clock,
    );
    gateway = bundle.lioGateway;
  });

  test('A valid low-risk request → ALLOW', () {
    final d = gateway.evaluate(_base());
    expect(d.kind, LioGatewayDecisionKind.allow);
    expect(d.wireDecision, 'ALLOW');
    expect(d.mayProceedToMcp, isTrue);
  });

  test('B empty/invalid request → DENY', () {
    final d = gateway.evaluate(_base(requestId: '', purpose: ''));
    expect(d.kind, LioGatewayDecisionKind.deny);
    expect(d.reasonCode, 'INVALID_REQUEST');
  });

  test('C missing authorization → DENY', () {
    final d = gateway.evaluate(_base(authorized: false));
    expect(d.kind, LioGatewayDecisionKind.deny);
    expect(d.reasonCode, 'UNAUTHORIZED');
  });

  test('D missing consent when required → REQUIRE_CONSENT', () {
    final d = gateway.evaluate(
      _base(
        purpose: 'care_support',
        scope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
        consent: const LioConsentContext(
          consentGranted: false,
          purposeAligned: false,
        ),
      ),
    );
    expect(d.kind, LioGatewayDecisionKind.requireConsent);
    expect(d.wireDecision, 'REQUIRE_CONSENT');
  });

  test('E high-risk action → REQUIRE_CONFIRMATION أو REQUIRE_REVIEW', () {
    final high = gateway.evaluate(
      _base(risk: LioActionRisk.high, humanConfirmed: false),
    );
    expect(high.kind, LioGatewayDecisionKind.requireConfirmation);

    final critical = gateway.evaluate(
      _base(risk: LioActionRisk.critical, reviewApproved: false),
    );
    expect(critical.kind, LioGatewayDecisionKind.requireReview);
  });

  test('F emergency-limited request → EMERGENCY_LIMITED + audit', () {
    gateway.auditLog.clear();
    final d = gateway.evaluate(
      _base(
        purpose: 'emergency_signal',
        scope: 'emergency_contacts_min',
        action: 'signal_trusted_contacts',
        emergency: true,
        risk: LioActionRisk.high,
      ),
    );
    expect(d.kind, LioGatewayDecisionKind.emergencyLimited);
    expect(d.wireDecision, 'EMERGENCY_LIMITED');
    expect(gateway.auditLog.events, isNotEmpty);
    expect(gateway.auditLog.events.last.outcome, 'EMERGENCY_LIMITED_PATH');
  });

  test('G purpose/scope violation → DENY', () {
    final purpose = gateway.evaluate(_base(purpose: 'diagnose_disease'));
    expect(purpose.kind, LioGatewayDecisionKind.deny);
    expect(purpose.reasonCode, 'PURPOSE_VIOLATION');

    final scope = gateway.evaluate(_base(scope: 'full_clinical_dump'));
    expect(scope.kind, LioGatewayDecisionKind.deny);
    expect(scope.reasonCode, 'SCOPE_VIOLATION');
  });

  test('H minimization violation → DENY', () {
    final d = gateway.evaluate(
      _base(
        fields: const {'diagnosis': 'x', 'password': 'secret'},
        minimumNecessary: false,
      ),
    );
    expect(d.kind, LioGatewayDecisionKind.deny);
    expect(d.reasonCode, 'MINIMIZATION_VIOLATION');
  });

  test('I every decision creates audit event', () {
    gateway.auditLog.clear();
    gateway.evaluate(_base());
    gateway.evaluate(_base(authorized: false, requestId: 'r2'));
    expect(gateway.auditLog.events.length, 2);
    expect(gateway.auditLog.events.every((e) => e.requestId.isNotEmpty), isTrue);
    expect(
      gateway.auditLog.events.every((e) => !e.toSafeMap().containsKey('password')),
      isTrue,
    );
  });

  test('J Clock injection works deterministically', () {
    gateway.auditLog.clear();
    final d = gateway.evaluate(_base());
    expect(d.timestamp, DateTime.utc(2026, 9, 21, 12, 0, 0));
    clock.advance(const Duration(minutes: 5));
    final d2 = gateway.evaluate(_base(requestId: 'r-clock'));
    expect(d2.timestamp, DateTime.utc(2026, 9, 21, 12, 5, 0));
  });

  test('K production path cannot bypass LIO', () {
    expect(identical(bundle.lioGateway.orchestrator, bundle.fabric.lio), isTrue);
    expect(bundle.isUnifiedProductionKnowledgePath, isTrue);
    expect(ProductionLioGateway.gatewayId, 'ProductionLioGateway');
    expect(
      ProductionLioGateway.productionFlow.first,
      'Human/UI',
    );
    expect(ProductionLioGateway.productionFlow.contains('LIO'), isTrue);
    expect(ProductionLioGateway.productionFlow.contains('MCP Gateway'), isTrue);

    // DB bypass attempts denied
    final db = gateway.evaluate(
      _base(action: 'direct_db_query', scope: 'sql://patients'),
    );
    expect(db.kind, LioGatewayDecisionKind.deny);
    expect(db.reasonCode, 'DB_BYPASS_FORBIDDEN');

    // Loose fabric is not the production gateway path
    final loose = LifexIntelligenceFabric();
    expect(identical(loose.lio, bundle.lioGateway.orchestrator), isFalse);
  });
}
