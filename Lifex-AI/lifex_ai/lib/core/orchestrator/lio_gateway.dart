/// =============================================================
/// Lifex-AI — Production LIO Gateway
/// Human/UI → AppContext → LIO → Identity → AuthN → AuthZ → Consent
/// → Purpose → Scope → Security → Risk → MCP → Agent → Verify → Audit
///
/// لا Singleton جديد — يُحقن عبر LifexProductionComposition.
/// لا تشخيص طبي، لا أدوية، لا SQL مباشر، لا LLM كـ SoT.
/// =============================================================
library lifex_ai.core.orchestrator.lio_gateway;

import '../lio/lio_orchestrator.dart';
import 'clock.dart';
import 'lio_gateway_contracts.dart';
import 'lio_gateway_policy.dart';

/// بوابة LIO الإنتاجية — قرار سياسة + تدقيق قبل MCP.
///
/// لا تنفّذ أجهزة/SMS/OCR هنا؛ MCP يبقى boundary/contract فقط.
class ProductionLioGateway {
  ProductionLioGateway({
    required this.orchestrator,
    LioGatewayPolicy? policy,
    LioAuditLog? auditLog,
    LifexClock? clock,
  })  : policy = policy ?? const LioGatewayPolicy(),
        auditLog = auditLog ?? LioAuditLog(),
        clock = clock ?? const SystemClock();

  /// المعرّف المعماري — للحراس ومنع تعدد بوابات الإنتاج.
  static const String gatewayId = 'ProductionLioGateway';

  /// مسار الإنتاج الإلزامي (عقد قابل للاختبار).
  static const List<String> productionFlow = [
    'Human/UI',
    'LifexAppContext',
    'LIO',
    'Identity',
    'Authentication',
    'Authorization',
    'Consent',
    'Purpose',
    'DataScope/Minimization',
    'SecurityPolicy',
    'Risk/ActionClassification',
    'MCP Gateway',
    'Agent/Tool execution',
    'Verification',
    'Audit',
  ];

  /// نفس Orchestrator من Fabric الإنتاجي — لا نسخة ثانية.
  final LifexIntelligenceOrchestrator orchestrator;
  final LioGatewayPolicy policy;
  final LioAuditLog auditLog;
  final LifexClock clock;

  /// يقيّم الطلب ويسجّل تدقيقاً دائماً. لا يصل إلى DB/Repository.
  LioGatewayDecision evaluate(LioGatewayRequest request) {
    final now = clock.now();
    final stamped = LioGatewayRequest(
      requestId: request.requestId,
      correlationId: request.correlationId,
      identityAccountId: request.identityAccountId,
      purpose: request.purpose,
      requestedAction: request.requestedAction,
      dataScope: request.dataScope,
      sensitivity: request.sensitivity,
      consent: request.consent,
      riskLevel: request.riskLevel,
      timestamp: now,
      authenticated: request.authenticated,
      authorized: request.authorized,
      deviceTrusted: request.deviceTrusted,
      approvalRequirement: request.approvalRequirement,
      stepUpSatisfied: request.stepUpSatisfied,
      humanConfirmed: request.humanConfirmed,
      reviewApproved: request.reviewApproved,
      emergencyLimitedMode: request.emergencyLimitedMode,
      declaredFields: request.declaredFields,
      minimumNecessarySatisfied: request.minimumNecessarySatisfied,
    );
    final decision = policy.evaluate(stamped);
    _audit(stamped, decision);
    return decision;
  }

  /// هل القرار يسمح بالمرور إلى حدود MCP (بدون تنفيذ حقيقي هنا)؟
  bool mayHandOffToMcp(LioGatewayDecision decision) =>
      decision.mayProceedToMcp && decision.kind.mayProceedToMcp;

  void _audit(LioGatewayRequest request, LioGatewayDecision decision) {
    final outcome = switch (decision.kind) {
      LioGatewayDecisionKind.allow => 'ALLOWED_TO_MCP',
      LioGatewayDecisionKind.emergencyLimited => 'EMERGENCY_LIMITED_PATH',
      _ => 'STOPPED',
    };
    auditLog.record(
      LioAuditEvent(
        requestId: request.requestId,
        correlationId: request.correlationId,
        actor: request.identityAccountId,
        action: request.requestedAction,
        decision: decision.wireDecision,
        purpose: request.purpose,
        scope: request.dataScope,
        risk: request.riskLevel.name,
        timestamp: decision.timestamp,
        outcome: outcome,
        reasonCode: decision.reasonCode,
      ),
    );
  }
}
