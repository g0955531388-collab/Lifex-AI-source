/// =============================================================
/// Lifex-AI — MCP Live Gateway Foundation — أنواع
/// مرحلة واحدة فقط: جلسة حيّة + نقل + استدعاء مقيّد — بلا Browser/Verifier.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_live_types;

enum McpLiveSessionState {
  disconnected,
  connecting,
  ready,
  degraded,
  failed,
}

enum McpTransportKind {
  /// تنفيذ داخل العملية — أساس Live Foundation.
  inProcess,
  /// HTTP/SSE لاحقاً — REQUIRES_EXTERNAL_SETUP حتى يُضبط endpoint.
  httpSse,
}

enum McpLiveInvokeStatus {
  ok,
  deniedByPolicy,
  requiresExternalSetup,
  transportError,
  sessionNotReady,
  unknownTool,
}

class McpLiveInvokeRequest {
  const McpLiveInvokeRequest({
    required this.toolId,
    required this.roleKey,
    required this.arguments,
    this.humanApproved = false,
    this.clinicalRequested = false,
    this.moneyRequested = false,
    this.requestId,
  });

  final String toolId;
  final String roleKey;
  final Map<String, Object?> arguments;
  final bool humanApproved;
  final bool clinicalRequested;
  final bool moneyRequested;
  final String? requestId;
}

class McpLiveInvokeResult {
  const McpLiveInvokeResult({
    required this.status,
    required this.toolId,
    required this.messageAr,
    this.payload = const {},
    this.deniedReasonAr,
    this.durationMs,
  });

  final McpLiveInvokeStatus status;
  final String toolId;
  final String messageAr;
  final Map<String, Object?> payload;
  final String? deniedReasonAr;
  final int? durationMs;

  bool get isOk => status == McpLiveInvokeStatus.ok;
  bool get isDenied => status == McpLiveInvokeStatus.deniedByPolicy;
}

class McpLiveResourceDescriptor {
  const McpLiveResourceDescriptor({
    required this.uri,
    required this.name,
    required this.descriptionAr,
  });

  final String uri;
  final String name;
  final String descriptionAr;
}

class McpLiveAuditEntry {
  const McpLiveAuditEntry({
    required this.at,
    required this.toolId,
    required this.roleKey,
    required this.status,
    required this.messageAr,
  });

  final DateTime at;
  final String toolId;
  final String roleKey;
  final McpLiveInvokeStatus status;
  final String messageAr;
}
