/// =============================================================
/// Lifex-AI — نتيجة أداة MCP الموحّدة
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_tool_result;

import 'mcp_errors.dart';
import 'mcp_policy_decision.dart';

enum McpVerificationStatus {
  verified,
  notVerified,
  failed,
  skipped,
}

class McpToolResult {
  const McpToolResult({
    required this.success,
    required this.status,
    required this.toolId,
    required this.requestId,
    required this.executionTimeMs,
    this.data = const {},
    this.errorCode,
    this.errorMessageAr,
    this.provenance,
    this.auditReference,
    this.verification = McpVerificationStatus.notVerified,
    this.policyDecision,
  });

  final bool success;
  final String status;
  final Map<String, Object?> data;
  final McpErrorCode? errorCode;
  final String? errorMessageAr;
  final String toolId;
  final String requestId;
  final int executionTimeMs;
  final Map<String, Object?>? provenance;
  final String? auditReference;
  final McpVerificationStatus verification;
  final McpPolicyDecision? policyDecision;

  factory McpToolResult.denied({
    required String toolId,
    required String requestId,
    required McpErrorCode code,
    required String messageAr,
    required McpPolicyDecision decision,
    required int executionTimeMs,
    String? auditReference,
  }) {
    return McpToolResult(
      success: false,
      status: code.wireName,
      toolId: toolId,
      requestId: requestId,
      executionTimeMs: executionTimeMs,
      errorCode: code,
      errorMessageAr: messageAr,
      policyDecision: decision,
      auditReference: auditReference,
      verification: McpVerificationStatus.skipped,
    );
  }
}

class McpAuditEvent {
  const McpAuditEvent({
    required this.auditId,
    required this.at,
    required this.requestId,
    required this.correlationId,
    required this.actorId,
    required this.agentId,
    required this.toolId,
    required this.requestedAction,
    required this.resource,
    required this.purpose,
    required this.scope,
    required this.policyDecision,
    required this.humanApproved,
    required this.executionSuccess,
    required this.verification,
    this.errorCode,
    this.messageAr = '',
  });

  final String auditId;
  final DateTime at;
  final String requestId;
  final String correlationId;
  final String actorId;
  final String agentId;
  final String toolId;
  final String requestedAction;
  final String resource;
  final String purpose;
  final String scope;
  final String policyDecision;
  final bool humanApproved;
  final bool executionSuccess;
  final String verification;
  final String? errorCode;
  final String messageAr;
}
