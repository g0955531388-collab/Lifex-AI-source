/// =============================================================
/// Lifex-AI — تحقق نتائج MCP عبر Verifier الموجود (بلا تكرار)
/// بلا بيانات CI → NOT_VERIFIED وليس VERIFIED.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_result_verifier;

import '../claim_verifier.dart';
import '../lio_types.dart';
import 'mcp_tool_adapters.dart';
import 'mcp_tool_result.dart';

class McpResultVerifier {
  const McpResultVerifier({
    this.claimVerifier = const LifexClaimVerifier(),
  });

  final LifexClaimVerifier claimVerifier;

  /// يتحقق من نتيجة الأداة. بدون أدلة تشغيلية → notVerified.
  McpVerificationStatus verify({
    required String requestId,
    required String agentId,
    required McpAdapterOutcome outcome,
    required LioRiskLevel risk,
    List<LioEvidence> evidence = const [],
  }) {
    if (!outcome.ok) {
      return McpVerificationStatus.skipped;
    }

    if (evidence.isEmpty) {
      // نجاح تكييف محلي (مثل ping) بلا أدلة CI → NOT_VERIFIED صراحة.
      return McpVerificationStatus.notVerified;
    }

    final report = claimVerifier.verify(
      claim: LioClaim(
        id: 'mcp-$requestId',
        statementAr: outcome.messageAr,
        madeByAgentId: agentId,
        risk: risk,
      ),
      evidence: evidence,
    );

    switch (report.verdict) {
      case LioVerificationVerdict.pass:
        return McpVerificationStatus.verified;
      case LioVerificationVerdict.needsHuman:
        return McpVerificationStatus.notVerified;
      case LioVerificationVerdict.fail:
      case LioVerificationVerdict.inconclusive:
        return McpVerificationStatus.failed;
    }
  }
}
