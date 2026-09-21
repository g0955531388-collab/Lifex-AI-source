/// =============================================================
/// Lifex-AI — سياق طلب MCP (إلزامي قبل التنفيذ)
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_request_context;

import '../lio_types.dart';

class McpGatewayRequest {
  const McpGatewayRequest({
    required this.requestId,
    required this.correlationId,
    required this.actorId,
    required this.agentId,
    required this.taskId,
    required this.purpose,
    required this.scope,
    required this.requestedAction,
    required this.resource,
    required this.toolId,
    required this.riskLevel,
    required this.timestamp,
    this.authenticated = false,
    this.authorized = false,
    this.consentGranted = false,
    this.humanApproved = false,
    this.arguments = const {},
    this.roleKey,
  });

  final String requestId;
  final String correlationId;
  final String actorId;
  final String agentId;
  final String taskId;
  final String purpose;
  final String scope;
  final String requestedAction;
  final String resource;
  final String toolId;
  final LioRiskLevel riskLevel;
  final DateTime timestamp;
  final bool authenticated;
  final bool authorized;
  final bool consentGranted;
  final bool humanApproved;
  final Map<String, Object?> arguments;
  final String? roleKey;

  bool get hasIdentity =>
      actorId.trim().isNotEmpty && agentId.trim().isNotEmpty;

  McpGatewayRequest copyWith({
    bool? humanApproved,
    bool? consentGranted,
  }) {
    return McpGatewayRequest(
      requestId: requestId,
      correlationId: correlationId,
      actorId: actorId,
      agentId: agentId,
      taskId: taskId,
      purpose: purpose,
      scope: scope,
      requestedAction: requestedAction,
      resource: resource,
      toolId: toolId,
      riskLevel: riskLevel,
      timestamp: timestamp,
      authenticated: authenticated,
      authorized: authorized,
      consentGranted: consentGranted ?? this.consentGranted,
      humanApproved: humanApproved ?? this.humanApproved,
      arguments: arguments,
      roleKey: roleKey,
    );
  }
}
