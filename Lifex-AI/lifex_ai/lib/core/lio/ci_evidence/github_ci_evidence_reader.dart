/// =============================================================
/// Lifex-AI — قارئ أدلة CI من GitHub (READ ONLY)
/// =============================================================
library lifex_ai.core.lio.ci_evidence.github_ci_evidence_reader;

import 'ci_evidence_model.dart';

enum GitHubEvidenceFetchStatus {
  ok,
  unavailable,
  notFound,
  error,
}

class GitHubEvidenceFetchResult {
  const GitHubEvidenceFetchResult({
    required this.status,
    this.evidence,
    this.messageAr,
  });

  final GitHubEvidenceFetchStatus status;
  final CiEvidence? evidence;
  final String? messageAr;

  bool get isOk =>
      status == GitHubEvidenceFetchStatus.ok && evidence != null;
}

/// مصدر أدلة CI — بلا أي Write Capability.
abstract class GitHubCiEvidenceReader {
  bool get isAvailable;

  /// دائماً false — Verifier/Reader لا يكتب.
  bool get allowsWrite => false;

  Future<GitHubEvidenceFetchResult> fetchCiEvidence({
    required String repository,
    String? workflowRunId,
    String? commitSha,
    String? branch,
  });
}

/// GitHub غير موصول — الحالة الصادقة الافتراضية.
class UnavailableGitHubCiEvidenceReader implements GitHubCiEvidenceReader {
  const UnavailableGitHubCiEvidenceReader();

  @override
  bool get isAvailable => false;

  @override
  bool get allowsWrite => false;

  @override
  Future<GitHubEvidenceFetchResult> fetchCiEvidence({
    required String repository,
    String? workflowRunId,
    String? commitSha,
    String? branch,
  }) async {
    return const GitHubEvidenceFetchResult(
      status: GitHubEvidenceFetchStatus.unavailable,
      messageAr:
          'TOOL_UNAVAILABLE — قارئ GitHub CI غير موصول بمفاتيح/شبكة حقيقية.',
    );
  }
}

/// مصدر قابل للحقن في الاختبارات — READ ONLY.
class InMemoryGitHubCiEvidenceReader implements GitHubCiEvidenceReader {
  InMemoryGitHubCiEvidenceReader({
    this.available = true,
    Map<String, CiEvidence>? byRunId,
    this.defaultEvidence,
  }) : _byRunId = Map.of(byRunId ?? {});

  final bool available;
  final Map<String, CiEvidence> _byRunId;
  final CiEvidence? defaultEvidence;

  @override
  bool get isAvailable => available;

  @override
  bool get allowsWrite => false;

  void put(String runId, CiEvidence evidence) => _byRunId[runId] = evidence;

  @override
  Future<GitHubEvidenceFetchResult> fetchCiEvidence({
    required String repository,
    String? workflowRunId,
    String? commitSha,
    String? branch,
  }) async {
    if (!available) {
      return const GitHubEvidenceFetchResult(
        status: GitHubEvidenceFetchStatus.unavailable,
        messageAr: 'TOOL_UNAVAILABLE — GitHub CI reader offline.',
      );
    }
    if (workflowRunId != null && _byRunId.containsKey(workflowRunId)) {
      return GitHubEvidenceFetchResult(
        status: GitHubEvidenceFetchStatus.ok,
        evidence: _byRunId[workflowRunId],
      );
    }
    if (defaultEvidence != null) {
      return GitHubEvidenceFetchResult(
        status: GitHubEvidenceFetchStatus.ok,
        evidence: defaultEvidence,
      );
    }
    return GitHubEvidenceFetchResult(
      status: GitHubEvidenceFetchStatus.notFound,
      messageAr: 'لا دليل CI للطلب ($repository / $workflowRunId).',
    );
  }
}
