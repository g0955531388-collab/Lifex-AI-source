import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_errors.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_live_gateway.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_live_types.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_request_context.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_adapters.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_transport.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';

void main() {
  late LifexIntelligenceFabric fabric;
  late LifexMcpLiveGateway live;

  setUp(() {
    fabric = LifexIntelligenceFabric();
    live = fabric.attachLiveMcpGateway();
  });

  test('connect يجعل الجلسة ready على In-Process', () async {
    expect(live.state, McpLiveSessionState.disconnected);
    final state = await live.connect();
    expect(state, McpLiveSessionState.ready);
    expect(live.foundationReport()['phase'], 'MCP_LIVE_GATEWAY_FOUNDATION');
    expect(live.foundationReport()['nextPhasesExcluded'], contains('KNOWLEDGE_ENGINE'));
  });

  test('بدون connect → sessionNotReady', () async {
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.local_files',
        roleKey: 'code',
        arguments: {'action': 'ping'},
      ),
    );
    expect(r.status, McpLiveInvokeStatus.sessionNotReady);
  });

  test('local_files ping ينجح بعد السياسة', () async {
    await live.connect();
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.local_files',
        roleKey: 'code',
        arguments: {'action': 'ping'},
      ),
    );
    expect(r.status, McpLiveInvokeStatus.ok);
    expect(r.payload['live'], isTrue);
  });

  test('cursor بلا موافقة بشرية → deniedByPolicy', () async {
    await live.connect();
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.cursor',
        roleKey: 'code',
        arguments: {'action': 'propose_edit'},
        humanApproved: false,
      ),
    );
    expect(r.status, McpLiveInvokeStatus.deniedByPolicy);
    expect(r.messageAr, contains('Human Approval'));
  });

  test('cursor بموافقة → TOOL_UNAVAILABLE صادق', () async {
    await live.connect();
    final report = await live.execute(
      McpGatewayRequest(
        requestId: 'c1',
        correlationId: 'c',
        actorId: 'ghazi',
        agentId: 'agent.code',
        taskId: 't',
        purpose: 'dev',
        scope: 'source_code',
        requestedAction: 'propose_edit',
        resource: '',
        toolId: 'mcp.cursor',
        riskLevel: LioRiskLevel.high,
        timestamp: DateTime.now(),
        authenticated: true,
        authorized: true,
        consentGranted: true,
        humanApproved: true,
        roleKey: 'code',
      ),
    );
    expect(report.result.errorCode, McpErrorCode.toolUnavailable);
  });

  test('مسار clinical مرفوض في local_files', () async {
    await live.connect();
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.local_files',
        roleKey: 'research',
        arguments: {'action': 'stat', 'path': '/data/clinical/patient.json'},
      ),
    );
    expect(r.status, McpLiveInvokeStatus.transportError);
    expect(r.messageAr, contains('محظور'));
  });

  test('research لا يستدعي mcp.cursor', () async {
    await live.connect();
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.cursor',
        roleKey: 'research',
        arguments: {'action': 'propose_edit'},
        humanApproved: true,
      ),
    );
    expect(r.status, McpLiveInvokeStatus.deniedByPolicy);
  });

  test('HTTP/SSE بدون endpoint → degraded + adapter files ما زال يعمل عبر Hub', () async {
    final httpLive = LifexMcpLiveGateway(
      registry: fabric.mcp,
      lio: fabric.lio,
      transport: HttpSseMcpTransport(),
    );
    await httpLive.connect();
    expect(httpLive.state, McpLiveSessionState.degraded);
    // النقل HTTP غير موصول؛ المحوّل In-Process للملفات يبقى الأساس الحي.
    final report = await httpLive.execute(
      McpGatewayRequest(
        requestId: 'h1',
        correlationId: 'c',
        actorId: 'ghazi',
        agentId: 'agent.code',
        taskId: 't',
        purpose: 'dev',
        scope: 'project_files',
        requestedAction: 'ping',
        resource: '',
        toolId: 'mcp.local_files',
        riskLevel: LioRiskLevel.low,
        timestamp: DateTime.now(),
        authenticated: true,
        authorized: true,
        consentGranted: true,
        roleKey: 'code',
      ),
    );
    expect(report.result.success, isTrue);
  });

  test('GitHub عبر HTTP adapter يعلن TOOL_UNAVAILABLE', () async {
    await live.connect();
    live.adapters.replace('mcp.github', GitHubMcpToolAdapter());
    final report = await live.execute(
      McpGatewayRequest(
        requestId: 'g1',
        correlationId: 'c',
        actorId: 'ghazi',
        agentId: 'agent.code',
        taskId: 't',
        purpose: 'ci_read',
        scope: 'repository_read',
        requestedAction: 'read_workflow_status',
        resource: 'repo',
        toolId: 'mcp.github',
        riskLevel: LioRiskLevel.medium,
        timestamp: DateTime.now(),
        authenticated: true,
        authorized: true,
        consentGranted: true,
        roleKey: 'code',
      ),
    );
    expect(report.result.errorCode, McpErrorCode.toolUnavailable);
  });

  test('التدقيق يُسجَّل لكل استدعاء', () async {
    await live.connect();
    await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.local_files',
        roleKey: 'code',
        arguments: {'action': 'ping'},
      ),
    );
    expect(live.auditEvents, isNotEmpty);
    expect(live.auditEvents.last.toolId, 'mcp.local_files');
  });
}
