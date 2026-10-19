/// =============================================================
/// Lifex-AI — لقطة أدلة CI من GitHub Actions (READ ONLY snapshot)
/// مصدر: run 35534653852 على PR #5 — ليست تقرير وكيل.
/// =============================================================
library lifex_ai.core.lio.ci_evidence.github_actions_run_snapshot;

import 'ci_evidence_model.dart';
import 'github_ci_evidence_reader.dart';

/// بيانات تشغيل Actions الحقيقي لفرع Knowledge Engine (مُجمَّعة READ ONLY).
class GithubActionsRunSnapshot {
  const GithubActionsRunSnapshot._();

  static const String repository = 'g0955531388-collab/Lifex-AI-source';
  static const String workflowRunId = '35534653852';
  static const String workflowName = 'Lifex-AI';
  static const String branch = 'feature/knowledge-engine-hybrid-rag';
  static const String commitSha =
      '31c8d15e37fcc9e5cb4e56454f48ceeb662dbd0c';
  static const String event = 'pull_request';
  static const String debugArtifactName = 'lifex-ai-debug-apk';
  static const String debugArtifactId = '10612765289';
  static const String debugArtifactDigest =
      'sha256:e374211fe4a15ce9e990419e6e38e0b69001cc4cf8481d6e8c6447119d55799e';
  static const String releaseArtifactName = 'lifex-ai-release-apk';
  static const String releaseArtifactId = '10611449914';
  static const String releaseArtifactDigest =
      'sha256:8d287b7d26c890ab46ce3af0a0843814a462454df94724cd055d20fa2bebc3f5';
  static const String evidenceSourceUrl =
      'https://github.com/g0955531388-collab/Lifex-AI-source/actions/runs/35534653852';

  /// دليل CI للتحقق من debug APK لهذا الـ commit.
  static CiEvidence debugApkEvidence() {
    return CiEvidence(
      repository: repository,
      workflowRunId: workflowRunId,
      workflowName: workflowName,
      workflowStatus: 'completed',
      conclusion: 'success',
      branch: branch,
      commitSha: commitSha,
      event: event,
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
        CiJobEvidence(
          name: 'Build release APK',
          status: 'completed',
          conclusion: CiJobConclusion.success,
        ),
      ],
      analyzeResult: CiCheckResult.success,
      testResult: CiCheckResult.success,
      apkBuildResult: CiCheckResult.success,
      artifact: const CiArtifactEvidence(
        name: debugArtifactName,
        id: debugArtifactId,
        digestOrSha256: debugArtifactDigest,
        sizeBytes: 145752612,
      ),
      timestamp: DateTime.utc(2026, 9, 20, 20, 18),
      source: 'github_actions',
      provenance: const {
        'runUrl': evidenceSourceUrl,
        'capturedFrom': 'GitHub Actions API (READ ONLY)',
        'notAgentReport': true,
      },
    );
  }

  static CiApkClaimExpectation debugApkExpectation() {
    return const CiApkClaimExpectation(
      repository: repository,
      commitSha: commitSha,
      branch: branch,
      artifactName: debugArtifactName,
      expectedDigestOrSha256: debugArtifactDigest,
    );
  }

  /// قارئ حقن — يقدّم لقطة الـ run الحقيقي فقط.
  static InMemoryGitHubCiEvidenceReader reader() {
    final r = InMemoryGitHubCiEvidenceReader();
    r.put(workflowRunId, debugApkEvidence());
    return r;
  }
}
