/// =============================================================
/// Lifex-AI — عقد أدلة CI (GitHub Actions)
/// لا تُفترض قيم غير موجودة.
/// =============================================================
library lifex_ai.core.lio.ci_evidence.ci_evidence_model;

enum CiJobConclusion {
  success,
  failure,
  cancelled,
  skipped,
  unknown,
}

enum CiCheckResult {
  success,
  failure,
  unknown,
  unavailable,
}

class CiJobEvidence {
  const CiJobEvidence({
    required this.name,
    required this.status,
    this.conclusion,
  });

  final String name;
  final String status;
  final CiJobConclusion? conclusion;
}

class CiArtifactEvidence {
  const CiArtifactEvidence({
    required this.name,
    this.id,
    this.digestOrSha256,
    this.sizeBytes,
  });

  final String name;
  final String? id;
  final String? digestOrSha256;
  final int? sizeBytes;

  bool get hasIntegrityDigest =>
      digestOrSha256 != null && digestOrSha256!.trim().isNotEmpty;
}

/// دليل CI واحد — حقول اختيارية حسب التوفر.
class CiEvidence {
  const CiEvidence({
    this.repository,
    this.workflowRunId,
    this.workflowName,
    this.workflowStatus,
    this.conclusion,
    this.branch,
    this.commitSha,
    this.event,
    this.jobs = const [],
    this.analyzeResult = CiCheckResult.unavailable,
    this.testResult = CiCheckResult.unavailable,
    this.apkBuildResult = CiCheckResult.unavailable,
    this.artifact,
    this.timestamp,
    this.source = 'github_actions',
    this.provenance = const {},
    this.fetchError,
  });

  final String? repository;
  final String? workflowRunId;
  final String? workflowName;
  final String? workflowStatus;
  final String? conclusion;
  final String? branch;
  final String? commitSha;
  final String? event;
  final List<CiJobEvidence> jobs;
  final CiCheckResult analyzeResult;
  final CiCheckResult testResult;
  final CiCheckResult apkBuildResult;
  final CiArtifactEvidence? artifact;
  final DateTime? timestamp;
  final String source;
  final Map<String, Object?> provenance;
  final String? fetchError;

  List<String> get jobNames => jobs.map((j) => j.name).toList();

  List<String> get jobStatuses =>
      jobs.map((j) => j.conclusion?.name ?? j.status).toList();

  bool get hasMinimalRunIdentity =>
      (repository?.isNotEmpty ?? false) &&
      (commitSha?.isNotEmpty ?? false) &&
      (workflowRunId?.isNotEmpty ?? false);
}

/// توقّع ادّعاء APK ناجح من commit معيّن.
class CiApkClaimExpectation {
  const CiApkClaimExpectation({
    required this.repository,
    required this.commitSha,
    required this.branch,
    this.artifactName,
    this.expectedDigestOrSha256,
    this.requireDigestMatch = false,
  });

  final String repository;
  final String commitSha;
  final String branch;
  final String? artifactName;
  final String? expectedDigestOrSha256;

  /// إن true ولم يتوفر digest → NOT_VERIFIED وليس VERIFIED.
  final bool requireDigestMatch;
}

enum CiVerificationStatus {
  verified,
  failed,
  notVerified,
  toolUnavailable,
}

extension CiVerificationStatusX on CiVerificationStatus {
  String get wireName {
    switch (this) {
      case CiVerificationStatus.verified:
        return 'VERIFIED';
      case CiVerificationStatus.failed:
        return 'FAILED';
      case CiVerificationStatus.notVerified:
        return 'NOT_VERIFIED';
      case CiVerificationStatus.toolUnavailable:
        return 'TOOL_UNAVAILABLE';
    }
  }
}

class CiVerificationResult {
  const CiVerificationResult({
    required this.verificationStatus,
    required this.claim,
    required this.reason,
    required this.timestamp,
    this.evidence,
    this.repository,
    this.commitSha,
    this.workflowRunId,
    this.verifiedChecks = const [],
    this.failedChecks = const [],
    this.missingChecks = const [],
    this.provenance = const {},
    this.integrityEvidence = 'unavailable',
    this.auditId,
  });

  final CiVerificationStatus verificationStatus;
  final String claim;
  final CiEvidence? evidence;
  final String reason;
  final String? repository;
  final String? commitSha;
  final String? workflowRunId;
  final List<String> verifiedChecks;
  final List<String> failedChecks;
  final List<String> missingChecks;
  final Map<String, Object?> provenance;
  final DateTime timestamp;
  final String integrityEvidence;
  final String? auditId;
}

class CiVerificationAuditEvent {
  const CiVerificationAuditEvent({
    required this.auditId,
    required this.at,
    required this.actor,
    required this.agent,
    required this.verifier,
    required this.repository,
    required this.commit,
    required this.workflow,
    required this.evidenceSource,
    required this.verificationStatus,
    required this.checks,
    this.errors = const [],
  });

  final String auditId;
  final DateTime at;
  final String actor;
  final String agent;
  final String verifier;
  final String? repository;
  final String? commit;
  final String? workflow;
  final String evidenceSource;
  final String verificationStatus;
  final List<String> checks;
  final List<String> errors;
}
