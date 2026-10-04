/// =============================================================
/// Lifex-AI — MCP Live Gateway Foundation
/// جلسة حيّة + سياسة LIO + نقل In-Process — مرحلة واحدة فقط.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_live_gateway;

import '../lio_orchestrator.dart';
import '../mcp_gateway.dart';
import 'mcp_live_handlers.dart';
import 'mcp_live_types.dart';
import 'mcp_transport.dart';

/// بوابة MCP الحيّة — لا تتجاوز سجل العقود ولا سياسة LIO.
class LifexMcpLiveGateway {
  LifexMcpLiveGateway({
    required this.registry,
    required this.lio,
    McpLiveTransport? transport,
    McpLiveFoundationHandlers handlers = const McpLiveFoundationHandlers(),
  }) : transport = transport ??
            InProcessMcpTransport(handlers: handlers.build());

  /// سجل أدوات العقود (موجة 1).
  final LifexMcpGateway registry;

  /// عقل القيادة — تفويض السياسة.
  final LifexIntelligenceOrchestrator lio;

  final McpLiveTransport transport;

  McpLiveSessionState _state = McpLiveSessionState.disconnected;
  final List<McpLiveAuditEntry> _audit = [];

  McpLiveSessionState get state => _state;
  List<McpLiveAuditEntry> get auditTrail => List.unmodifiable(_audit);

  static const foundationResources = <McpLiveResourceDescriptor>[
    McpLiveResourceDescriptor(
      uri: 'lifex://mcp/foundation/canon',
      name: 'LIO Canon',
      descriptionAr: 'قوانين LIO — Memory≠SoT و AI↛SQL.',
    ),
    McpLiveResourceDescriptor(
      uri: 'lifex://mcp/foundation/tool-registry',
      name: 'MCP Tool Registry',
      descriptionAr: 'أدوات مسجّلة تحت البوابة.',
    ),
  ];

  Future<McpLiveSessionState> connect() async {
    _state = McpLiveSessionState.connecting;
    try {
      await transport.connect();
      _state = transport.isConnected
          ? McpLiveSessionState.ready
          : McpLiveSessionState.degraded;
    } catch (e) {
      _state = McpLiveSessionState.failed;
      _audit.add(
        McpLiveAuditEntry(
          at: DateTime.now(),
          toolId: '*',
          roleKey: '*',
          status: McpLiveInvokeStatus.transportError,
          messageAr: 'فشل الاتصال: $e',
        ),
      );
    }
    return _state;
  }

  Future<void> disconnect() async {
    await transport.disconnect();
    _state = McpLiveSessionState.disconnected;
  }

  List<LioMcpToolDescriptor> listTools() => registry.tools;

  List<McpLiveResourceDescriptor> listResources() => foundationResources;

  /// استدعاء أداة: سياسة أولاً ثم النقل.
  Future<McpLiveInvokeResult> invoke(McpLiveInvokeRequest request) async {
    final started = DateTime.now();

    if (_state != McpLiveSessionState.ready &&
        _state != McpLiveSessionState.degraded) {
      return _finish(
        request,
        McpLiveInvokeResult(
          status: McpLiveInvokeStatus.sessionNotReady,
          toolId: request.toolId,
          messageAr: 'الجلسة غير جاهزة (state=$_state). استدعِ connect() أولاً.',
        ),
        started,
      );
    }

    if (registry.tool(request.toolId) == null) {
      return _finish(
        request,
        McpLiveInvokeResult(
          status: McpLiveInvokeStatus.unknownTool,
          toolId: request.toolId,
          messageAr: 'أداة غير مسجّلة في عقود MCP: ${request.toolId}',
        ),
        started,
      );
    }

    final policyDeny = registry.denyReason(
      toolId: request.toolId,
      role: request.roleKey,
      humanApproved: request.humanApproved,
      clinicalRequested: request.clinicalRequested,
      moneyRequested: request.moneyRequested,
    );
    if (policyDeny != null) {
      return _finish(
        request,
        McpLiveInvokeResult(
          status: McpLiveInvokeStatus.deniedByPolicy,
          toolId: request.toolId,
          messageAr: policyDeny,
          deniedReasonAr: policyDeny,
        ),
        started,
      );
    }

    // تحقق إضافي عبر ملف الوكيل إن وُجد دور مطابق في السجل.
    final roleProfile = lio.agents.all
        .where((p) => LifexIntelligenceOrchestrator.roleKey(p.role) == request.roleKey)
        .toList();
    if (roleProfile.isNotEmpty) {
      final profile = roleProfile.first;
      if (!profile.allowedTools.contains(request.toolId)) {
        final msg =
            'الأداة ${request.toolId} خارج أدوات ${profile.identity}.';
        return _finish(
          request,
          McpLiveInvokeResult(
            status: McpLiveInvokeStatus.deniedByPolicy,
            toolId: request.toolId,
            messageAr: msg,
            deniedReasonAr: msg,
          ),
          started,
        );
      }
    }

    final call = await transport.callTool(
      toolId: request.toolId,
      arguments: request.arguments,
    );

    if (call.requiresExternalSetup) {
      return _finish(
        request,
        McpLiveInvokeResult(
          status: McpLiveInvokeStatus.requiresExternalSetup,
          toolId: request.toolId,
          messageAr: call.messageAr,
          payload: call.payload,
        ),
        started,
      );
    }

    if (!call.ok) {
      return _finish(
        request,
        McpLiveInvokeResult(
          status: McpLiveInvokeStatus.transportError,
          toolId: request.toolId,
          messageAr: call.messageAr,
          payload: call.payload,
        ),
        started,
      );
    }

    return _finish(
      request,
      McpLiveInvokeResult(
        status: McpLiveInvokeStatus.ok,
        toolId: request.toolId,
        messageAr: call.messageAr,
        payload: call.payload,
      ),
      started,
    );
  }

  McpLiveInvokeResult _finish(
    McpLiveInvokeRequest request,
    McpLiveInvokeResult result,
    DateTime started,
  ) {
    final ms = DateTime.now().difference(started).inMilliseconds;
    final withMs = McpLiveInvokeResult(
      status: result.status,
      toolId: result.toolId,
      messageAr: result.messageAr,
      payload: result.payload,
      deniedReasonAr: result.deniedReasonAr,
      durationMs: ms,
    );
    _audit.add(
      McpLiveAuditEntry(
        at: DateTime.now(),
        toolId: request.toolId,
        roleKey: request.roleKey,
        status: withMs.status,
        messageAr: withMs.messageAr,
      ),
    );
    return withMs;
  }

  Map<String, Object?> foundationReport() => {
        'phase': 'MCP_LIVE_GATEWAY_FOUNDATION',
        'state': _state.name,
        'transport': transport.kind.name,
        'toolCount': registry.tools.length,
        'resourceCount': foundationResources.length,
        'auditCount': _audit.length,
        'nextPhasesExcluded': const [
          'BROWSER_AGENT',
          'VERIFIER_CI',
          'KNOWLEDGE_ENGINE',
          'HYBRID_RAG',
        ],
      };
}
