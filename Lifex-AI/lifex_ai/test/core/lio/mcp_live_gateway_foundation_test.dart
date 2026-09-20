import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_live_gateway.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_live_types.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_transport.dart';

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
    expect(live.foundationReport()['nextPhasesExcluded'], contains('VERIFIER_CI'));
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
        humanApproved: false,
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
        arguments: {},
        humanApproved: false,
      ),
    );
    expect(r.status, McpLiveInvokeStatus.deniedByPolicy);
    expect(r.deniedReasonAr, contains('موافقة'));
  });

  test('cursor بموافقة → REQUIRES_EXTERNAL_SETUP (Foundation)', () async {
    await live.connect();
    final r = await live.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.cursor',
        roleKey: 'code',
        arguments: {'task': 'edit'},
        humanApproved: true,
      ),
    );
    expect(r.status, McpLiveInvokeStatus.requiresExternalSetup);
    expect(r.messageAr, contains('REQUIRES_EXTERNAL_SETUP'));
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
        arguments: {},
        humanApproved: true,
      ),
    );
    expect(r.status, McpLiveInvokeStatus.deniedByPolicy);
  });

  test('HTTP/SSE بدون endpoint يبقى REQUIRES_EXTERNAL_SETUP', () async {
    final httpLive = LifexMcpLiveGateway(
      registry: fabric.mcp,
      lio: fabric.lio,
      transport: HttpSseMcpTransport(),
    );
    await httpLive.connect();
    expect(httpLive.state, McpLiveSessionState.degraded);
    final r = await httpLive.invoke(
      const McpLiveInvokeRequest(
        toolId: 'mcp.local_files',
        roleKey: 'code',
        arguments: {'action': 'ping'},
      ),
    );
    expect(r.status, McpLiveInvokeStatus.requiresExternalSetup);
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
    expect(live.auditTrail, isNotEmpty);
    expect(live.auditTrail.last.toolId, 'mcp.local_files');
  });
}
