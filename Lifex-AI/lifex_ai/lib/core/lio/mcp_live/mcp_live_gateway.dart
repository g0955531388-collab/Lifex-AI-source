/// =============================================================
/// Lifex-AI — MCP Live Gateway (تنفيذ حي)
/// المسار الوحيد:
/// LIO → Identity/Auth/Consent/Purpose/Scope/Policy → Adapter → Result → Verifier → Audit
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_live_gateway;

import '../claim_verifier.dart';
import '../lio_orchestrator.dart';
import '../lio_types.dart';
import '../mcp_gateway.dart';
import 'mcp_errors.dart';
import 'mcp_live_handlers.dart';
import 'mcp_live_types.dart';
import 'mcp_policy_decision.dart';
import 'mcp_request_context.dart';
import 'mcp_result_verifier.dart';
import 'mcp_security_pipeline.dart';
import 'mcp_tool_adapters.dart';
import 'mcp_tool_contract.dart';
import 'mcp_tool_result.dart';
import 'mcp_transport.dart';

/// تقرير تنفيذ كامل لمسار Gateway.
class McpGatewayExecutionReport {
  const McpGatewayExecutionReport({
    required this.result,
    required this.policyDecision,
    required this.auditEvent,
  });

  final McpToolResult result;
  final McpPolicyDecision policyDecision;
  final McpAuditEvent auditEvent;
}

/// البوابة الوحيدة لأدوات الوكلاء في مرحلة MCP Live Foundation.
class LifexMcpLiveGateway {
  LifexMcpLiveGateway({
    required this.registry,
    required this.lio,
    McpLiveToolRegistry? toolContracts,
    McpToolAdapterHub? adapters,
    McpSecurityPipeline? security,
    McpResultVerifier? resultVerifier,
    McpLiveTransport? transport,
    McpLiveFoundationHandlers handlers = const McpLiveFoundationHandlers(),
  })  : toolContracts = toolContracts ?? McpLiveToolRegistry(),
        adapters = adapters ?? McpToolAdapterHub(),
        security = security ?? const McpSecurityPipeline(),
        resultVerifier = resultVerifier ?? const McpResultVerifier(),
        transport = transport ??
            InProcessMcpTransport(handlers: handlers.build());

  /// سجل عقود الموجة 1 (وصفي).
  final LifexMcpGateway registry;

  final LifexIntelligenceOrchestrator lio;
  final McpLiveToolRegistry toolContracts;
  final McpToolAdapterHub adapters;
  final McpSecurityPipeline security;
  final McpResultVerifier resultVerifier;
  final McpLiveTransport transport;

  McpLiveSessionState _state = McpLiveSessionState.disconnected;
  final List<McpAuditEvent> _audit = [];
  int _auditSeq = 0;

  McpLiveSessionState get state => _state;
  List<McpAuditEvent> get auditEvents => List.unmodifiable(_audit);

  /// توافق خلفي مع اختبارات الجلسة السابقة.
  List<McpLiveAuditEntry> get auditTrail => _audit
      .map(
        (e) => McpLiveAuditEntry(
          at: e.at,
          toolId: e.toolId,
          roleKey: e.agentId,
          status: e.executionSuccess
              ? McpLiveInvokeStatus.ok
              : McpLiveInvokeStatus.deniedByPolicy,
          messageAr: e.messageAr,
        ),
      )
      .toList(growable: false);

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
    } catch (_) {
      _state = McpLiveSessionState.failed;
    }
    return _state;
  }

  Future<void> disconnect() async {
    await transport.disconnect();
    _state = McpLiveSessionState.disconnected;
  }

  List<LioMcpToolDescriptor> listTools() => registry.tools;

  List<McpToolContract> listToolContracts() => toolContracts.all;

  List<McpLiveResourceDescriptor> listResources() => foundationResources;

  /// نقطة الدخول الوحيدة للتنفيذ الحي.
  Future<McpGatewayExecutionReport> execute(
    McpGatewayRequest request, {
    List<LioEvidence> verificationEvidence = const [],
  }) async {
    final started = DateTime.now();

    if (_state != McpLiveSessionState.ready &&
        _state != McpLiveSessionState.degraded) {
      return _deny(
        request: request,
        decision: McpPolicyDecision.blocked,
        code: McpErrorCode.sessionNotReady,
        messageAr: 'الجلسة غير جاهزة. connect() أولاً.',
        started: started,
      );
    }

    final contract = toolContracts.tool(request.toolId);
    if (contract == null) {
      return _deny(
        request: request,
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.unknownTool,
        messageAr: 'أداة غير مسجّلة: ${request.toolId}',
        started: started,
      );
    }

    final verdict = security.evaluate(request: request, contract: contract);
    if (!verdict.mayProceedToExecute) {
      return _deny(
        request: request,
        decision: verdict.decision,
        code: verdict.errorCode ?? McpErrorCode.policyDenied,
        messageAr: verdict.messageAr ?? 'مرفوض بالسياسة.',
        started: started,
      );
    }

    // ربط سجل تحكم الوكلاء — لا مسار جانبي لأدوات غير مسموحة للدور.
    final roleKey = request.roleKey;
    if (roleKey != null && roleKey.isNotEmpty) {
      final profiles = lio.agents.all
          .where(
            (p) => LifexIntelligenceOrchestrator.roleKey(p.role) == roleKey,
          )
          .toList();
      if (profiles.isNotEmpty &&
          !profiles.first.allowedTools.contains(request.toolId)) {
        return _deny(
          request: request,
          decision: McpPolicyDecision.deny,
          code: McpErrorCode.forbidden,
          messageAr:
              'الأداة ${request.toolId} خارج صلاحيات الوكيل ${profiles.first.identity}.',
          started: started,
        );
      }
    }

    final adapter = adapters.of(request.toolId);
    if (adapter == null) {
      return _deny(
        request: request,
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.toolUnavailable,
        messageAr: 'لا محوّل مسجّل للأداة ${request.toolId}.',
        started: started,
      );
    }

    final outcome = await runAdapterWithTimeout(
      adapter: adapter,
      request: request,
      contract: contract,
    );

    final ms = DateTime.now().difference(started).inMilliseconds;
    final verification = resultVerifier.verify(
      requestId: request.requestId,
      agentId: request.agentId,
      outcome: outcome,
      risk: request.riskLevel,
      evidence: verificationEvidence,
    );

    // نجاح تكييف مع فشل تحقق صريح
    if (outcome.ok && verification == McpVerificationStatus.failed) {
      final audit = _record(
        request: request,
        decision: McpPolicyDecision.allow,
        success: false,
        verification: verification,
        errorCode: McpErrorCode.verificationFailed,
        messageAr: 'VERIFICATION_FAILED — النتيجة رُفضت من Verifier.',
      );
      return McpGatewayExecutionReport(
        policyDecision: McpPolicyDecision.allow,
        auditEvent: audit,
        result: McpToolResult(
          success: false,
          status: McpErrorCode.verificationFailed.wireName,
          toolId: request.toolId,
          requestId: request.requestId,
          executionTimeMs: ms,
          data: outcome.data,
          errorCode: McpErrorCode.verificationFailed,
          errorMessageAr: 'VERIFICATION_FAILED',
          provenance: outcome.provenance,
          auditReference: audit.auditId,
          verification: verification,
          policyDecision: McpPolicyDecision.allow,
        ),
      );
    }

    final success = outcome.ok;
    final audit = _record(
      request: request,
      decision: McpPolicyDecision.allow,
      success: success,
      verification: verification,
      errorCode: outcome.errorCode,
      messageAr: outcome.messageAr,
    );

    return McpGatewayExecutionReport(
      policyDecision: McpPolicyDecision.allow,
      auditEvent: audit,
      result: McpToolResult(
        success: success,
        status: outcome.status,
        toolId: request.toolId,
        requestId: request.requestId,
        executionTimeMs: ms,
        data: outcome.data,
        errorCode: outcome.errorCode,
        errorMessageAr: success ? null : outcome.messageAr,
        provenance: outcome.provenance,
        auditReference: audit.auditId,
        verification: verification,
        policyDecision: McpPolicyDecision.allow,
      ),
    );
  }

  /// توافق خلفي: تحويل استدعاء بسيط إلى المسار الكامل عند الإمكان.
  Future<McpLiveInvokeResult> invoke(McpLiveInvokeRequest request) async {
    final report = await execute(
      McpGatewayRequest(
        requestId: request.requestId ?? 'legacy-${DateTime.now().microsecondsSinceEpoch}',
        correlationId: 'legacy',
        actorId: request.humanApproved ? 'human' : 'agent',
        agentId: request.roleKey,
        taskId: 'legacy-task',
        purpose: 'legacy_invoke',
        scope: request.toolId == 'mcp.local_files' ? 'project_files' : 'source_code',
        requestedAction: (request.arguments['action'] as String?) ?? 'ping',
        resource: (request.arguments['path'] as String?) ?? '',
        toolId: request.toolId,
        riskLevel: LioRiskLevel.medium,
        timestamp: DateTime.now(),
        authenticated: true,
        authorized: true,
        consentGranted: !request.clinicalRequested,
        humanApproved: request.humanApproved,
        arguments: request.arguments,
        roleKey: request.roleKey,
      ),
    );
    final r = report.result;
    final status = () {
      if (r.success) return McpLiveInvokeStatus.ok;
      switch (r.errorCode) {
        case McpErrorCode.approvalRequired:
        case McpErrorCode.consentRequired:
        case McpErrorCode.policyDenied:
        case McpErrorCode.scopeDenied:
        case McpErrorCode.unauthorized:
        case McpErrorCode.unauthenticated:
        case McpErrorCode.forbidden:
          return McpLiveInvokeStatus.deniedByPolicy;
        case McpErrorCode.toolUnavailable:
          return McpLiveInvokeStatus.requiresExternalSetup;
        case McpErrorCode.sessionNotReady:
          return McpLiveInvokeStatus.sessionNotReady;
        case McpErrorCode.unknownTool:
          return McpLiveInvokeStatus.unknownTool;
        default:
          return McpLiveInvokeStatus.transportError;
      }
    }();
    return McpLiveInvokeResult(
      status: status,
      toolId: r.toolId,
      messageAr: r.errorMessageAr ?? r.status,
      payload: r.data,
      deniedReasonAr: r.errorMessageAr,
      durationMs: r.executionTimeMs,
    );
  }

  McpGatewayExecutionReport _deny({
    required McpGatewayRequest request,
    required McpPolicyDecision decision,
    required McpErrorCode code,
    required String messageAr,
    required DateTime started,
  }) {
    final ms = DateTime.now().difference(started).inMilliseconds;
    final audit = _record(
      request: request,
      decision: decision,
      success: false,
      verification: McpVerificationStatus.skipped,
      errorCode: code,
      messageAr: messageAr,
    );
    return McpGatewayExecutionReport(
      policyDecision: decision,
      auditEvent: audit,
      result: McpToolResult.denied(
        toolId: request.toolId,
        requestId: request.requestId,
        code: code,
        messageAr: messageAr,
        decision: decision,
        executionTimeMs: ms,
        auditReference: audit.auditId,
      ),
    );
  }

  McpAuditEvent _record({
    required McpGatewayRequest request,
    required McpPolicyDecision decision,
    required bool success,
    required McpVerificationStatus verification,
    required String messageAr,
    McpErrorCode? errorCode,
  }) {
    _auditSeq++;
    final event = McpAuditEvent(
      auditId: 'mcp-audit-$_auditSeq',
      at: DateTime.now(),
      requestId: request.requestId,
      correlationId: request.correlationId,
      actorId: request.actorId,
      agentId: request.agentId,
      toolId: request.toolId,
      requestedAction: request.requestedAction,
      resource: request.resource,
      purpose: request.purpose,
      scope: request.scope,
      policyDecision: decision.wireName,
      humanApproved: request.humanApproved,
      executionSuccess: success,
      verification: verification.name,
      errorCode: errorCode?.wireName,
      messageAr: messageAr,
    );
    _audit.add(event);
    return event;
  }

  Map<String, Object?> foundationReport() => {
        'phase': 'MCP_LIVE_GATEWAY_FOUNDATION',
        'state': _state.name,
        'transport': transport.kind.name,
        'toolContractCount': toolContracts.all.length,
        'adapterCount': 5,
        'auditCount': _audit.length,
        'pipeline':
            'LIO→Identity→Auth→Consent→Purpose→Scope→Policy→Gateway→Adapter→Result→Verifier→Audit',
        'nextPhasesExcluded': const [
          'BROWSER_AGENT_LIVE',
          'KNOWLEDGE_ENGINE',
          'HYBRID_RAG',
          'DISEASE_DB',
        ],
      };
}
