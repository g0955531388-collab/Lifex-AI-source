/// =============================================================
/// Lifex-AI — تحقق ادّعاءات CI عبر LifexClaimVerifier (بلا Verifier ثانٍ)
/// =============================================================
library lifex_ai.core.lio.ci_evidence.ci_evidence_verification;

import '../claim_verifier.dart';
import '../lio_types.dart';
import '../source_reliability.dart';
import 'ci_evidence_model.dart';
import 'github_ci_evidence_reader.dart';

/// خدمة تحقق — تستهلك أدلة فقط؛ لا Write.
class CiEvidenceVerificationService {
  CiEvidenceVerificationService({
    LifexClaimVerifier? claimVerifier,
    GitHubCiEvidenceReader? reader,
  })  : claimVerifier = claimVerifier ?? const LifexClaimVerifier(),
        reader = reader ?? const UnavailableGitHubCiEvidenceReader();

  final LifexClaimVerifier claimVerifier;
  final GitHubCiEvidenceReader reader;

  final List<CiVerificationAuditEvent> _audit = [];
  int _seq = 0;

  List<CiVerificationAuditEvent> get auditEvents =>
      List.unmodifiable(_audit);

  bool get allowsWrite => false;

  bool get readerAllowsWrite => reader.allowsWrite;

  /// المسار: Claim → fetch READ → تقييم فحوصات → LifexClaimVerifier → Audit.
  Future<CiVerificationResult> verifyApkClaim({
    required LioClaim claim,
    required CiApkClaimExpectation expected,
    required String actor,
    required String agent,
    String? workflowRunId,
  }) async {
    final at = DateTime.now();

    if (reader.allowsWrite) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.failed,
        reason: 'SECURITY — قارئ CI يدّعي Write Capability — مرفوض.',
        at: at,
        actor: actor,
        agent: agent,
        expected: expected,
        failed: const ['reader_must_be_readonly'],
      );
    }

    if (!reader.isAvailable) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.toolUnavailable,
        reason: 'TOOL_UNAVAILABLE — تعذّر الوصول إلى GitHub CI.',
        at: at,
        actor: actor,
        agent: agent,
        expected: expected,
      );
    }

    final fetch = await reader.fetchCiEvidence(
      repository: expected.repository,
      workflowRunId: workflowRunId,
      commitSha: expected.commitSha,
      branch: expected.branch,
    );

    if (fetch.status == GitHubEvidenceFetchStatus.unavailable) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.toolUnavailable,
        reason: fetch.messageAr ?? 'TOOL_UNAVAILABLE',
        at: at,
        actor: actor,
        agent: agent,
        expected: expected,
      );
    }

    if (!fetch.isOk || fetch.evidence == null) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.notVerified,
        reason: fetch.messageAr ?? 'NOT_VERIFIED — بيانات CI ناقصة.',
        at: at,
        actor: actor,
        agent: agent,
        expected: expected,
        missing: const ['ci_evidence'],
      );
    }

    return evaluateFetchedEvidence(
      claim: claim,
      expected: expected,
      evidence: fetch.evidence!,
      actor: actor,
      agent: agent,
      at: at,
    );
  }

  /// تقييم دليل مُجلب مسبقاً (مثلاً عبر MCP Gateway) — بلا تجاوز للسياسة.
  CiVerificationResult evaluateFetchedEvidence({
    required LioClaim claim,
    required CiApkClaimExpectation expected,
    required CiEvidence evidence,
    required String actor,
    required String agent,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final verified = <String>[];
    final failed = <String>[];
    final missing = <String>[];

    void check(String name, bool present, bool ok) {
      if (!present) {
        missing.add(name);
      } else if (ok) {
        verified.add(name);
      } else {
        failed.add(name);
      }
    }

    check(
      'repository',
      evidence.repository != null && evidence.repository!.isNotEmpty,
      evidence.repository == expected.repository,
    );
    check(
      'branch',
      evidence.branch != null && evidence.branch!.isNotEmpty,
      evidence.branch == expected.branch,
    );
    check(
      'commitSha',
      evidence.commitSha != null && evidence.commitSha!.isNotEmpty,
      evidence.commitSha == expected.commitSha,
    );
    check(
      'workflowRun',
      evidence.workflowRunId != null && evidence.workflowRunId!.isNotEmpty,
      true,
    );

    final conclusionOk = (evidence.conclusion ?? '').toLowerCase() == 'success';
    check(
      'workflowConclusion',
      evidence.conclusion != null,
      conclusionOk,
    );

    check(
      'analyze',
      evidence.analyzeResult != CiCheckResult.unavailable,
      evidence.analyzeResult == CiCheckResult.success,
    );
    check(
      'test',
      evidence.testResult != CiCheckResult.unavailable,
      evidence.testResult == CiCheckResult.success,
    );
    check(
      'apkBuild',
      evidence.apkBuildResult != CiCheckResult.unavailable,
      evidence.apkBuildResult == CiCheckResult.success,
    );

    final art = evidence.artifact;
    final artPresent = art != null && art.name.isNotEmpty;
    final artNameOk = expected.artifactName == null ||
        (artPresent && art.name == expected.artifactName);
    check('artifact', artPresent, artNameOk);

    var integrity = 'unavailable';
    if (expected.requireDigestMatch ||
        expected.expectedDigestOrSha256 != null) {
      if (art == null || !art.hasIntegrityDigest) {
        missing.add('artifactDigest');
        integrity = 'unavailable';
      } else if (expected.expectedDigestOrSha256 != null &&
          art.digestOrSha256 != expected.expectedDigestOrSha256) {
        failed.add('artifactDigest');
        integrity = 'mismatch';
      } else if (expected.expectedDigestOrSha256 != null) {
        verified.add('artifactDigest');
        integrity = 'matched';
      } else {
        // digest موجود لكن الادعاء لم يطلب مطابقة قيمة معيّنة
        verified.add('artifactDigestPresent');
        integrity = 'present_unchecked_value';
      }
    } else if (art != null && art.hasIntegrityDigest) {
      integrity = 'present_not_required';
    }

    // تناقضات واضحة → FAILED
    if (failed.isNotEmpty) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.failed,
        reason: 'VERIFICATION_FAILED — فحوصات متناقضة أو فاشلة: ${failed.join(", ")}',
        at: now,
        actor: actor,
        agent: agent,
        expected: expected,
        evidence: evidence,
        verified: verified,
        failed: failed,
        missing: missing,
        integrity: integrity,
      );
    }

    // نواقص → NOT_VERIFIED
    if (missing.isNotEmpty) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.notVerified,
        reason: 'NOT_VERIFIED — أدلة ناقصة: ${missing.join(", ")}',
        at: now,
        actor: actor,
        agent: agent,
        expected: expected,
        evidence: evidence,
        verified: verified,
        failed: failed,
        missing: missing,
        integrity: integrity,
      );
    }

    // مرّر إلى LifexClaimVerifier كأدلة تشغيلية
    final mapped = <LioEvidence>[
      LioEvidence(
        kind: LioEvidenceKind.analyzer,
        passed: evidence.analyzeResult == CiCheckResult.success,
        detailAr: 'CI analyze=${evidence.analyzeResult.name}',
        provenance: LioSourceProvenance(
          sourceId: 'ci-${evidence.workflowRunId}',
          sourceType: 'github_actions',
          authority: LioSourceAuthority.repositoryCommit,
          retrievedAt: now,
          repository: evidence.repository,
          commit: evidence.commitSha,
          url: evidence.workflowRunId,
        ),
      ),
      LioEvidence(
        kind: LioEvidenceKind.unitTest,
        passed: evidence.testResult == CiCheckResult.success,
        detailAr: 'CI test=${evidence.testResult.name}',
      ),
      LioEvidence(
        kind: LioEvidenceKind.buildApk,
        passed: evidence.apkBuildResult == CiCheckResult.success,
        detailAr: 'CI apk=${evidence.apkBuildResult.name}',
      ),
      if (art != null && art.hasIntegrityDigest)
        LioEvidence(
          kind: LioEvidenceKind.artifactSha256,
          passed: integrity == 'matched' ||
              integrity == 'present_not_required' ||
              integrity == 'present_unchecked_value',
          detailAr: 'digest=$integrity',
          sha256: art.digestOrSha256,
        ),
    ];

    final required = <LioEvidenceKind>{
      LioEvidenceKind.analyzer,
      LioEvidenceKind.unitTest,
      LioEvidenceKind.buildApk,
      if (expected.requireDigestMatch ||
          expected.expectedDigestOrSha256 != null)
        LioEvidenceKind.artifactSha256,
    };

    final report = claimVerifier.verify(
      claim: claim,
      evidence: mapped,
      required: required,
    );

    if (report.verdict == LioVerificationVerdict.fail ||
        report.verdict == LioVerificationVerdict.inconclusive) {
      return _finish(
        claim: claim,
        status: CiVerificationStatus.failed,
        reason: 'VERIFICATION_FAILED — LifexClaimVerifier: ${report.reasonAr}',
        at: now,
        actor: actor,
        agent: agent,
        expected: expected,
        evidence: evidence,
        verified: verified,
        failed: [...failed, 'claim_verifier'],
        missing: missing,
        integrity: integrity,
      );
    }

    return _finish(
      claim: claim,
      status: CiVerificationStatus.verified,
      reason: 'VERIFIED — أدلة CI متوافقة مع الادّعاء.',
      at: now,
      actor: actor,
      agent: agent,
      expected: expected,
      evidence: evidence,
      verified: verified,
      failed: failed,
      missing: missing,
      integrity: integrity,
    );
  }

  CiVerificationResult _finish({
    required LioClaim claim,
    required CiVerificationStatus status,
    required String reason,
    required DateTime at,
    required String actor,
    required String agent,
    required CiApkClaimExpectation expected,
    CiEvidence? evidence,
    List<String> verified = const [],
    List<String> failed = const [],
    List<String> missing = const [],
    String integrity = 'unavailable',
  }) {
    _seq++;
    final auditId = 'ci-verify-$_seq';
    final checks = <String>[
      ...verified.map((c) => 'ok:$c'),
      ...failed.map((c) => 'fail:$c'),
      ...missing.map((c) => 'missing:$c'),
    ];
    _audit.add(
      CiVerificationAuditEvent(
        auditId: auditId,
        at: at,
        actor: actor,
        agent: agent,
        verifier: 'LifexClaimVerifier+CiEvidence',
        repository: evidence?.repository ?? expected.repository,
        commit: evidence?.commitSha ?? expected.commitSha,
        workflow: evidence?.workflowRunId,
        evidenceSource: evidence?.source ?? 'github_actions',
        verificationStatus: status.wireName,
        checks: checks,
        errors: status == CiVerificationStatus.verified ? const [] : [reason],
      ),
    );

    return CiVerificationResult(
      verificationStatus: status,
      claim: claim.statementAr,
      evidence: evidence,
      reason: reason,
      repository: evidence?.repository ?? expected.repository,
      commitSha: evidence?.commitSha ?? expected.commitSha,
      workflowRunId: evidence?.workflowRunId,
      verifiedChecks: verified,
      failedChecks: failed,
      missingChecks: missing,
      provenance: {
        'source': evidence?.source ?? 'github_actions',
        'integrityEvidence': integrity,
        ...?evidence?.provenance,
      },
      timestamp: at,
      integrityEvidence: integrity,
      auditId: auditId,
    );
  }
}
