/// =============================================================
/// Lifex-AI — Verifier مستقل
/// Claim بلا Evidence = FAIL. الوكيل لا يصدّق نفسه.
/// =============================================================
library lifex_ai.core.lio.claim_verifier;

import 'lio_types.dart';
import 'source_reliability.dart';

enum LioEvidenceKind {
  unitTest,
  analyzer,
  buildApk,
  artifactSha256,
  artifactAttestation,
  provenanceCite,
  humanSignoff,
}

class LioClaim {
  const LioClaim({
    required this.id,
    required this.statementAr,
    required this.madeByAgentId,
    this.risk = LioRiskLevel.medium,
  });

  final String id;
  final String statementAr;
  final String madeByAgentId;
  final LioRiskLevel risk;
}

class LioEvidence {
  const LioEvidence({
    required this.kind,
    required this.passed,
    required this.detailAr,
    this.sha256,
    this.provenance,
  });

  final LioEvidenceKind kind;
  final bool passed;
  final String detailAr;
  final String? sha256;
  final LioSourceProvenance? provenance;
}

class LioVerificationReport {
  const LioVerificationReport({
    required this.claimId,
    required this.verdict,
    required this.reasonAr,
    required this.evidence,
    required this.requiresHuman,
  });

  final String claimId;
  final LioVerificationVerdict verdict;
  final String reasonAr;
  final List<LioEvidence> evidence;
  final bool requiresHuman;
}

/// لا يقبل ادعاء الإصلاح بدون أدلة تشغيلية.
class LifexClaimVerifier {
  const LifexClaimVerifier({
    this.reliability = const LifexSourceReliabilityEngine(),
  });

  final LifexSourceReliabilityEngine reliability;

  static const requiredForCodeFix = <LioEvidenceKind>{
    LioEvidenceKind.analyzer,
    LioEvidenceKind.unitTest,
  };

  static const requiredForReleaseApk = <LioEvidenceKind>{
    LioEvidenceKind.buildApk,
    LioEvidenceKind.artifactSha256,
  };

  LioVerificationReport verify({
    required LioClaim claim,
    required List<LioEvidence> evidence,
    Set<LioEvidenceKind> required = requiredForCodeFix,
  }) {
    if (evidence.isEmpty) {
      return LioVerificationReport(
        claimId: claim.id,
        verdict: LioVerificationVerdict.fail,
        reasonAr: 'ادّعاء بلا دليل — مرفوض.',
        evidence: evidence,
        requiresHuman: claim.risk == LioRiskLevel.high ||
            claim.risk == LioRiskLevel.critical,
      );
    }

    // الوكيل لا يوافق على ادّعائه بنفسه كدليل وحيد.
    final selfOnly = evidence.every(
      (e) => e.kind == LioEvidenceKind.humanSignoff && !e.passed,
    );
    if (selfOnly) {
      return LioVerificationReport(
        claimId: claim.id,
        verdict: LioVerificationVerdict.fail,
        reasonAr: 'لا يكفي توقيع الوكيل على نفسه.',
        evidence: evidence,
        requiresHuman: true,
      );
    }

    for (final kind in required) {
      final hit = evidence.where((e) => e.kind == kind).toList();
      if (hit.isEmpty || hit.every((e) => !e.passed)) {
        return LioVerificationReport(
          claimId: claim.id,
          verdict: LioVerificationVerdict.fail,
          reasonAr: 'دليل مطلوب ناقص أو فاشل: $kind',
          evidence: evidence,
          requiresHuman: claim.risk.index >= LioRiskLevel.high.index,
        );
      }
    }

    for (final e in evidence) {
      if (e.provenance != null &&
          !reliability.acceptAsEvidence(e.provenance!)) {
        return LioVerificationReport(
          claimId: claim.id,
          verdict: LioVerificationVerdict.inconclusive,
          reasonAr: 'provenance غير مقبول كدليل.',
          evidence: evidence,
          requiresHuman: true,
        );
      }
    }

    final needsHuman = claim.risk == LioRiskLevel.critical ||
        claim.risk == LioRiskLevel.high;
    return LioVerificationReport(
      claimId: claim.id,
      verdict: needsHuman
          ? LioVerificationVerdict.needsHuman
          : LioVerificationVerdict.pass,
      reasonAr: needsHuman
          ? 'الأدلة الآلية ناجحة — بانتظار موافقة بشرية.'
          : 'الأدلة الآلية كافية.',
      evidence: evidence,
      requiresHuman: needsHuman,
    );
  }
}
