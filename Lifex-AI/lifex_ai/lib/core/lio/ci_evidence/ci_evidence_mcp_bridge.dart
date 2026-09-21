/// =============================================================
/// Lifex-AI — جسر: MCP Gateway → CI Evidence → LifexClaimVerifier
/// لا يتجاوز Gateway. READ ONLY.
/// =============================================================
library lifex_ai.core.lio.ci_evidence.ci_evidence_mcp_bridge;

import '../claim_verifier.dart';
import '../lio_types.dart';
import '../mcp_live/mcp_errors.dart';
import '../mcp_live/mcp_live_gateway.dart';
import '../mcp_live/mcp_request_context.dart';
import 'ci_evidence_model.dart';
import 'ci_evidence_verification.dart';
import 'github_ci_evidence_reader.dart';

/// يجلب الأدلة عبر MCP فقط ثم يمرّرها إلى خدمة التحقق.
class CiEvidenceMcpBridge {
  CiEvidenceMcpBridge({
    required this.gateway,
    required this.verification,
  });

  final LifexMcpLiveGateway gateway;
  final CiEvidenceVerificationService verification;

  /// المسار الإلزامي: Gateway read → evaluate → Audit.
  Future<CiVerificationResult> verifyApkClaimViaGateway({
    required LioClaim claim,
    required CiApkClaimExpectation expected,
    required String actor,
    required String agent,
    required String workflowRunId,
    bool authenticated = true,
    bool authorized = true,
  }) async {
    if (verification.allowsWrite || verification.readerAllowsWrite) {
      return CiVerificationResult(
        verificationStatus: CiVerificationStatus.failed,
        claim: claim.statementAr,
        reason: 'SECURITY — Write Capability مرفوضة على مسار التحقق.',
        timestamp: DateTime.now(),
        repository: expected.repository,
        commitSha: expected.commitSha,
        failedChecks: const ['write_capability'],
      );
    }

    final report = await gateway.execute(
      McpGatewayRequest(
        requestId: 'ci-ev-${claim.id}',
        correlationId: 'ci-evidence',
        actorId: actor,
        agentId: agent,
        taskId: claim.id,
        purpose: 'ci_verification',
        scope: 'ci_read',
        requestedAction: 'read_ci_evidence',
        resource: expected.repository,
        toolId: 'mcp.github',
        riskLevel: LioRiskLevel.medium,
        timestamp: DateTime.now(),
        authenticated: authenticated,
        authorized: authorized,
        consentGranted: true,
        humanApproved: false,
        roleKey: 'code',
        arguments: {
          'repository': expected.repository,
          'workflowRunId': workflowRunId,
          'commitSha': expected.commitSha,
          'branch': expected.branch,
        },
      ),
    );

    if (report.result.errorCode == McpErrorCode.toolUnavailable ||
        report.result.status == 'TOOL_UNAVAILABLE') {
      return verification.verifyApkClaim(
        claim: claim,
        expected: expected,
        actor: actor,
        agent: agent,
        workflowRunId: workflowRunId,
      );
    }

    if (!report.result.success) {
      return CiVerificationResult(
        verificationStatus: CiVerificationStatus.notVerified,
        claim: claim.statementAr,
        reason:
            'NOT_VERIFIED — فشل جلب الأدلة عبر MCP: ${report.result.errorMessageAr ?? report.result.status}',
        timestamp: DateTime.now(),
        repository: expected.repository,
        commitSha: expected.commitSha,
        workflowRunId: workflowRunId,
        missingChecks: const ['mcp_fetch'],
        auditId: report.auditEvent.auditId,
      );
    }

    final data = report.result.data;
    final evidence = CiEvidence(
      repository: data['repository'] as String?,
      workflowRunId: data['workflowRunId'] as String?,
      workflowName: data['workflowName'] as String?,
      workflowStatus: data['workflowStatus'] as String?,
      conclusion: data['conclusion'] as String?,
      branch: data['branch'] as String?,
      commitSha: data['commitSha'] as String?,
      event: data['event'] as String?,
      analyzeResult: _parseCheck(data['analyzeResult'] as String?),
      testResult: _parseCheck(data['testResult'] as String?),
      apkBuildResult: _parseCheck(data['apkBuildResult'] as String?),
      artifact: data['artifactName'] == null
          ? null
          : CiArtifactEvidence(
              name: data['artifactName'] as String,
              id: data['artifactId'] as String?,
              digestOrSha256: data['artifactDigest'] as String?,
            ),
      timestamp: DateTime.now(),
      source: 'github_actions_via_mcp',
      provenance: report.result.provenance ?? const {},
    );

    return verification.evaluateFetchedEvidence(
      claim: claim,
      expected: expected,
      evidence: evidence,
      actor: actor,
      agent: agent,
    );
  }

  static CiCheckResult _parseCheck(String? raw) {
    switch (raw) {
      case 'success':
        return CiCheckResult.success;
      case 'failure':
        return CiCheckResult.failure;
      case 'unknown':
        return CiCheckResult.unknown;
      default:
        return CiCheckResult.unavailable;
    }
  }
}

/// مصنع اختبارات: Gateway + Reader + Verification.
class CiEvidenceTestHarness {
  CiEvidenceTestHarness({
    required this.gateway,
    required this.reader,
    required this.verification,
    required this.bridge,
  });

  final LifexMcpLiveGateway gateway;
  final GitHubCiEvidenceReader reader;
  final CiEvidenceVerificationService verification;
  final CiEvidenceMcpBridge bridge;
}
