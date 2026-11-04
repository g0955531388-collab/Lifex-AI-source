/// =============================================================
/// Lifex-AI — أخطاء MCP الموحّدة
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_errors;

enum McpErrorCode {
  invalidRequest,
  unauthenticated,
  unauthorized,
  forbidden,
  consentRequired,
  approvalRequired,
  toolUnavailable,
  toolTimeout,
  toolValidationFailed,
  policyDenied,
  scopeDenied,
  executionFailed,
  verificationFailed,
  sessionNotReady,
  unknownTool,
}

extension McpErrorCodeX on McpErrorCode {
  String get wireName {
    switch (this) {
      case McpErrorCode.invalidRequest:
        return 'INVALID_REQUEST';
      case McpErrorCode.unauthenticated:
        return 'UNAUTHENTICATED';
      case McpErrorCode.unauthorized:
        return 'UNAUTHORIZED';
      case McpErrorCode.forbidden:
        return 'FORBIDDEN';
      case McpErrorCode.consentRequired:
        return 'CONSENT_REQUIRED';
      case McpErrorCode.approvalRequired:
        return 'APPROVAL_REQUIRED';
      case McpErrorCode.toolUnavailable:
        return 'TOOL_UNAVAILABLE';
      case McpErrorCode.toolTimeout:
        return 'TOOL_TIMEOUT';
      case McpErrorCode.toolValidationFailed:
        return 'TOOL_VALIDATION_FAILED';
      case McpErrorCode.policyDenied:
        return 'POLICY_DENIED';
      case McpErrorCode.scopeDenied:
        return 'SCOPE_DENIED';
      case McpErrorCode.executionFailed:
        return 'EXECUTION_FAILED';
      case McpErrorCode.verificationFailed:
        return 'VERIFICATION_FAILED';
      case McpErrorCode.sessionNotReady:
        return 'SESSION_NOT_READY';
      case McpErrorCode.unknownTool:
        return 'UNKNOWN_TOOL';
    }
  }
}
