import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/claim_verifier.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_errors.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_live_gateway.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_policy_decision.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_request_context.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_adapters.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_contract.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_result.dart';

McpGatewayRequest _req({
  String requestId = 'r1',
  String actorId = 'ghazi',
  String agentId = 'agent.code',
  String toolId = 'mcp.local_files',
  String action = 'ping',
  String scope = 'project_files',
  String purpose = 'development',
  String resource = '',
  bool authenticated = true,
  bool authorized = true,
  bool consent = true,
  bool humanApproved = false,
  LioRiskLevel risk = LioRiskLevel.low,
  String? roleKey = 'code',
  Map<String, Object?> arguments = const {},
}) {
  return McpGatewayRequest(
    requestId: requestId,
    correlationId: 'c1',
    actorId: actorId,
    agentId: agentId,
    taskId: 't1',
    purpose: purpose,
    scope: scope,
    requestedAction: action,
    resource: resource,
    toolId: toolId,
    riskLevel: risk,
    timestamp: DateTime.now(),
    authenticated: authenticated,
    authorized: authorized,
    consentGranted: consent,
    humanApproved: humanApproved,
    arguments: arguments,
    roleKey: roleKey,
  );
}

void main() {
  late LifexIntelligenceFabric fabric;
  late LifexMcpLiveGateway live;

  setUp(() async {
    fabric = LifexIntelligenceFabric();
    live = fabric.attachLiveMcpGateway();
    await live.connect();
  });

  test('Test1 صالح → Execute → Result → Verify(NOT_VERIFIED) → Audit', () async {
    final report = await live.execute(_req());
    expect(report.result.success, isTrue);
    expect(report.policyDecision, McpPolicyDecision.allow);
    expect(report.result.verification, McpVerificationStatus.notVerified);
    expect(report.auditEvent.executionSuccess, isTrue);
    expect(live.auditEvents, isNotEmpty);
  });

  test('Test2 بلا Identity → DENY UNAUTHENTICATED', () async {
    final report = await live.execute(_req(actorId: '', agentId: ''));
    expect(report.result.success, isFalse);
    expect(report.result.errorCode, McpErrorCode.unauthenticated);
    expect(report.policyDecision, McpPolicyDecision.deny);
  });

  test('Test3 بلا Authorization → DENY', () async {
    final report = await live.execute(_req(authorized: false));
    expect(report.result.errorCode, McpErrorCode.unauthorized);
  });

  test('Test4 يحتاج Consent → REQUIRE_CONSENT', () async {
    final report = await live.execute(
      _req(
        toolId: 'mcp.browser',
        action: 'search',
        scope: 'public_web',
        purpose: 'clinical_research',
        consent: false,
        roleKey: 'research',
        risk: LioRiskLevel.medium,
        humanApproved: true,
      ),
    );
    expect(report.policyDecision, McpPolicyDecision.requireConsent);
    expect(report.result.errorCode, McpErrorCode.consentRequired);
  });

  test('Test5 High Risk → REQUIRE_CONFIRMATION بلا تنفيذ', () async {
    final report = await live.execute(
      _req(
        toolId: 'mcp.cursor',
        action: 'propose_edit',
        scope: 'source_code',
        risk: LioRiskLevel.high,
        humanApproved: false,
        roleKey: 'code',
      ),
    );
    expect(report.policyDecision, McpPolicyDecision.requireConfirmation);
    expect(report.result.errorCode, McpErrorCode.approvalRequired);
    expect(report.result.success, isFalse);
  });

  test('Test6 Tool غير متاح → TOOL_UNAVAILABLE', () async {
    final report = await live.execute(
      _req(
        toolId: 'mcp.github',
        action: 'read_repository',
        scope: 'repository_read',
        risk: LioRiskLevel.medium,
        humanApproved: false,
        roleKey: 'code',
      ),
    );
    expect(report.result.errorCode, McpErrorCode.toolUnavailable);
    expect(report.result.success, isFalse);
  });

  test('Test7 Tool Timeout → TOOL_TIMEOUT', () async {
    live.adapters.replace(
      'mcp.local_files',
      TimeoutMcpToolAdapter(
        toolId: 'mcp.local_files',
        delay: const Duration(seconds: 2),
      ),
    );
    // shrink timeout via custom contract registry
    final tight = McpLiveToolRegistry(seed: {
      'mcp.local_files': McpToolContract(
        toolId: 'mcp.local_files',
        toolName: 'Files',
        description: 'timeout test',
        capabilities: const ['ping'],
        allowedOperations: const ['ping'],
        writeOperations: const [],
        allowedScopes: const ['project_files'],
        requiredPermissions: const [],
        riskLevel: LioRiskLevel.low,
        approvalPolicy: McpApprovalPolicy.none,
        enabled: true,
        timeout: const Duration(milliseconds: 50),
        auditPolicy: McpAuditPolicy.minimal,
      ),
    });
    final gated = LifexMcpLiveGateway(
      registry: fabric.mcp,
      lio: fabric.lio,
      toolContracts: tight,
      adapters: live.adapters,
    );
    await gated.connect();
    final report = await gated.execute(_req());
    expect(report.result.errorCode, McpErrorCode.toolTimeout);
  });

  test('Test8 Policy تمنع العملية → POLICY_DENIED', () async {
    final report = await live.execute(
      _req(action: 'not_a_real_op'),
    );
    expect(report.result.errorCode, McpErrorCode.policyDenied);
  });

  test('Test9 Scope غير مسموح → SCOPE_DENIED', () async {
    final report = await live.execute(
      _req(scope: 'patient_phi_dump'),
    );
    expect(report.result.errorCode, McpErrorCode.scopeDenied);
  });

  test('Test10 نجاح ثم Verification فاشل → VERIFICATION_FAILED', () async {
    final report = await live.execute(
      _req(),
      verificationEvidence: const [
        LioEvidence(
          kind: LioEvidenceKind.analyzer,
          passed: false,
          detailAr: 'analyze failed',
        ),
        LioEvidence(
          kind: LioEvidenceKind.unitTest,
          passed: true,
          detailAr: 'tests ok',
        ),
      ],
    );
    expect(report.result.errorCode, McpErrorCode.verificationFailed);
    expect(report.result.verification, McpVerificationStatus.failed);
  });

  test('Test11 كل Tool Call ينتج Audit Event', () async {
    final before = live.auditEvents.length;
    await live.execute(_req(requestId: 'a1'));
    await live.execute(_req(requestId: 'a2', authorized: false));
    expect(live.auditEvents.length, greaterThanOrEqualTo(before + 2));
  });

  test('Test12 لا مسار SQL/Clinical عبر Gateway', () async {
    final report = await live.execute(
      _req(
        action: 'query_sql',
        resource: 'sql://patients',
        scope: 'project_files',
      ),
    );
    expect(report.policyDecision, McpPolicyDecision.blocked);
    expect(report.result.errorCode, McpErrorCode.forbidden);
  });

  test('كتابة GitHub بلا موافقة → REQUIRE_CONFIRMATION', () async {
    final report = await live.execute(
      _req(
        toolId: 'mcp.github',
        action: 'push',
        scope: 'repository_write',
        humanApproved: false,
        roleKey: 'code',
      ),
    );
    expect(report.policyDecision, McpPolicyDecision.requireConfirmation);
    expect(report.result.errorCode, McpErrorCode.approvalRequired);
  });

  test('بعد الموافقة الكتابة ما زالت TOOL_UNAVAILABLE (صادق)', () async {
    final report = await live.execute(
      _req(
        toolId: 'mcp.github',
        action: 'push',
        scope: 'repository_write',
        humanApproved: true,
        roleKey: 'code',
        risk: LioRiskLevel.high,
      ),
    );
    expect(report.result.errorCode, McpErrorCode.toolUnavailable);
  });
}
