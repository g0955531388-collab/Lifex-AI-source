import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/claim_verifier.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_mcp_bridge.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_model.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_verification.dart';
import 'package:lifex_ai/core/lio/ci_evidence/github_ci_evidence_reader.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_request_context.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_adapters.dart';

CiEvidence _okEvidence({
  String repo = 'owner/Lifex-AI-source',
  String sha = 'abc123def',
  String branch = 'feature/ci-evidence-verifier',
  String runId = '35492487005',
  String? digest = 'sha256:deadbeef',
  String artifact = 'lifex-ai-debug-apk',
  String conclusion = 'success',
  CiCheckResult analyze = CiCheckResult.success,
  CiCheckResult test = CiCheckResult.success,
  CiCheckResult apk = CiCheckResult.success,
}) {
  return CiEvidence(
    repository: repo,
    workflowRunId: runId,
    workflowName: 'Lifex-AI',
    workflowStatus: 'completed',
    conclusion: conclusion,
    branch: branch,
    commitSha: sha,
    event: 'pull_request',
    jobs: const [
      CiJobEvidence(
        name: 'Analyze and test',
        status: 'completed',
        conclusion: CiJobConclusion.success,
      ),
      CiJobEvidence(
        name: 'Build debug APK',
        status: 'completed',
        conclusion: CiJobConclusion.success,
      ),
    ],
    analyzeResult: analyze,
    testResult: test,
    apkBuildResult: apk,
    artifact: CiArtifactEvidence(
      name: artifact,
      id: '1',
      digestOrSha256: digest,
    ),
    timestamp: DateTime(2026, 9, 20),
    source: 'github_actions',
  );
}

void main() {
  const expected = CiApkClaimExpectation(
    repository: 'owner/Lifex-AI-source',
    commitSha: 'abc123def',
    branch: 'feature/ci-evidence-verifier',
    artifactName: 'lifex-ai-debug-apk',
    expectedDigestOrSha256: 'sha256:deadbeef',
  );

  const claim = LioClaim(
    id: 'apk-claim-1',
    statementAr: 'commit X produced a successful debug APK',
    madeByAgentId: 'agent.code',
    risk: LioRiskLevel.medium,
  );

  late InMemoryGitHubCiEvidenceReader reader;
  late CiEvidenceVerificationService verification;

  setUp(() {
    reader = InMemoryGitHubCiEvidenceReader();
    reader.put('35492487005', _okEvidence());
    verification = CiEvidenceVerificationService(reader: reader);
  });

  test('Test1 CI ناجح + commit + artifact → VERIFIED', () async {
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: '35492487005',
    );
    expect(r.verificationStatus, CiVerificationStatus.verified);
    expect(r.verifiedChecks, contains('commitSha'));
    expect(r.verifiedChecks, contains('artifact'));
    expect(r.integrityEvidence, 'matched');
  });

  test('Test2 Workflow فشل → FAILED', () async {
    reader.put(
      'fail-run',
      _okEvidence(conclusion: 'failure', runId: 'fail-run'),
    );
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'fail-run',
    );
    expect(r.verificationStatus, CiVerificationStatus.failed);
    expect(r.failedChecks, contains('workflowConclusion'));
  });

  test('Test3 Commit غير متطابق → FAILED', () async {
    reader.put('bad-sha', _okEvidence(sha: 'other', runId: 'bad-sha'));
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'bad-sha',
    );
    expect(r.verificationStatus, CiVerificationStatus.failed);
    expect(r.failedChecks, contains('commitSha'));
  });

  test('Test4 Artifact مفقود → NOT_VERIFIED', () async {
    reader.put(
      'no-art',
      CiEvidence(
        repository: expected.repository,
        workflowRunId: 'no-art',
        conclusion: 'success',
        branch: expected.branch,
        commitSha: expected.commitSha,
        analyzeResult: CiCheckResult.success,
        testResult: CiCheckResult.success,
        apkBuildResult: CiCheckResult.success,
      ),
    );
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'no-art',
    );
    expect(r.verificationStatus, CiVerificationStatus.notVerified);
    expect(r.missingChecks, contains('artifact'));
  });

  test('Test5 GitHub غير متاح → TOOL_UNAVAILABLE', () async {
    final offline = CiEvidenceVerificationService(
      reader: const UnavailableGitHubCiEvidenceReader(),
    );
    final r = await offline.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'x',
    );
    expect(r.verificationStatus, CiVerificationStatus.toolUnavailable);
  });

  test('Test6 بيانات ناقصة → NOT_VERIFIED', () async {
    reader.put(
      'thin',
      const CiEvidence(
        repository: 'owner/Lifex-AI-source',
        workflowRunId: 'thin',
      ),
    );
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'thin',
    );
    expect(r.verificationStatus, CiVerificationStatus.notVerified);
    expect(r.missingChecks, isNotEmpty);
  });

  test('Test7 Digest متوفر ومطابق → VERIFIED', () async {
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: '35492487005',
    );
    expect(r.verificationStatus, CiVerificationStatus.verified);
    expect(r.verifiedChecks, contains('artifactDigest'));
  });

  test('Test8 Digest غير متطابق → FAILED', () async {
    final r = await verification.verifyApkClaim(
      claim: claim,
      expected: const CiApkClaimExpectation(
        repository: 'owner/Lifex-AI-source',
        commitSha: 'abc123def',
        branch: 'feature/ci-evidence-verifier',
        artifactName: 'lifex-ai-debug-apk',
        expectedDigestOrSha256: 'sha256:wrong',
      ),
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: '35492487005',
    );
    expect(r.verificationStatus, CiVerificationStatus.failed);
    expect(r.failedChecks, contains('artifactDigest'));
  });

  test('Test9 Verifier لا يملك Write Capability', () {
    expect(verification.allowsWrite, isFalse);
    expect(verification.readerAllowsWrite, isFalse);
    expect(reader.allowsWrite, isFalse);
  });

  test('Test10 كل Verification ينتج Audit Event', () async {
    final before = verification.auditEvents.length;
    await verification.verifyApkClaim(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: '35492487005',
    );
    expect(verification.auditEvents.length, before + 1);
    expect(verification.auditEvents.last.verificationStatus, 'VERIFIED');
  });

  test('Test11 لا يتجاوز MCP Gateway', () async {
    final fabric = LifexIntelligenceFabric();
    final live = fabric.attachLiveMcpGateway();
    live.adapters.replace(
      'mcp.github',
      GitHubMcpToolAdapter(evidenceReader: reader),
    );
    await live.connect();
    final bridge = CiEvidenceMcpBridge(
      gateway: live,
      verification: verification,
    );
    final r = await bridge.verifyApkClaimViaGateway(
      claim: claim,
      expected: expected,
      actor: 'ghazi',
      agent: 'agent.code',
      workflowRunId: '35492487005',
    );
    expect(r.verificationStatus, CiVerificationStatus.verified);
    expect(live.auditEvents.any((e) => e.toolId == 'mcp.github'), isTrue);
  });

  test('Test12 لا وصول Clinical عبر مسار التحقق', () async {
    final fabric = LifexIntelligenceFabric();
    final live = fabric.attachLiveMcpGateway();
    await live.connect();
    final report = await live.execute(
      McpGatewayRequest(
        requestId: 'clin',
        correlationId: 'c',
        actorId: 'ghazi',
        agentId: 'agent.critic_verifier',
        taskId: 't',
        purpose: 'clinical_exfil',
        scope: 'clinical_care',
        requestedAction: 'read_ci_evidence',
        resource: 'clinical://patients',
        toolId: 'mcp.github',
        riskLevel: LioRiskLevel.low,
        timestamp: DateTime.now(),
        authenticated: true,
        authorized: true,
        consentGranted: false,
        roleKey: 'code',
      ),
    );
    expect(report.result.success, isFalse);
  });
}
