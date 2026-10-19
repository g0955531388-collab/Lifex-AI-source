/// =============================================================
/// Lifex-AI — قرارات MCP Gateway (مركزية — لا تكرار)
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_policy_decision;

enum McpPolicyDecision {
  allow,
  deny,
  requireConsent,
  requireConfirmation,
  requireStepUp,
  requireReview,
  emergencyLimited,
  blocked,
}

extension McpPolicyDecisionX on McpPolicyDecision {
  String get wireName {
    switch (this) {
      case McpPolicyDecision.allow:
        return 'ALLOW';
      case McpPolicyDecision.deny:
        return 'DENY';
      case McpPolicyDecision.requireConsent:
        return 'REQUIRE_CONSENT';
      case McpPolicyDecision.requireConfirmation:
        return 'REQUIRE_CONFIRMATION';
      case McpPolicyDecision.requireStepUp:
        return 'REQUIRE_STEP_UP';
      case McpPolicyDecision.requireReview:
        return 'REQUIRE_REVIEW';
      case McpPolicyDecision.emergencyLimited:
        return 'EMERGENCY_LIMITED';
      case McpPolicyDecision.blocked:
        return 'BLOCKED';
    }
  }

  bool get mayExecute =>
      this == McpPolicyDecision.allow ||
      this == McpPolicyDecision.emergencyLimited;
}
