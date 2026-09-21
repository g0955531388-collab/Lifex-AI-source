/// =============================================================
/// Lifex-AI — محرك موثوقية المصادر + Provenance
/// Search → cite ≠ Search → trust
/// =============================================================
library lifex_ai.core.lio.source_reliability;

import 'lio_types.dart';

class LioSourceProvenance {
  const LioSourceProvenance({
    required this.sourceId,
    required this.sourceType,
    required this.authority,
    required this.retrievedAt,
    this.url,
    this.repository,
    this.commit,
    this.document,
    this.version,
    this.author,
    this.license,
    this.evidenceLevel = 0.0,
    this.confidence = 0.0,
    this.conflict = LioConflictStatus.none,
    this.jurisdiction,
  });

  final String sourceId;
  final String sourceType;
  final LioSourceAuthority authority;
  final DateTime retrievedAt;
  final String? url;
  final String? repository;
  final String? commit;
  final String? document;
  final String? version;
  final String? author;
  final String? license;
  final double evidenceLevel;
  final double confidence;
  final LioConflictStatus conflict;
  final String? jurisdiction;

  bool get isCitable =>
      url != null ||
      repository != null ||
      document != null ||
      commit != null;
}

class LifexSourceReliabilityEngine {
  const LifexSourceReliabilityEngine();

  /// وزن السلطة — لا تُعامل مدونة مجهولة كـ WHO.
  double weightOf(LioSourceAuthority authority) {
    switch (authority) {
      case LioSourceAuthority.officialStandard:
        return 1.0;
      case LioSourceAuthority.peerReviewed:
        return 0.9;
      case LioSourceAuthority.officialVendor:
        return 0.75;
      case LioSourceAuthority.repositoryCommit:
        return 0.7;
      case LioSourceAuthority.documentation:
        return 0.65;
      case LioSourceAuthority.news:
        return 0.4;
      case LioSourceAuthority.unknownBlog:
        return 0.2;
      case LioSourceAuthority.unverified:
        return 0.05;
    }
  }

  /// رفض «نسخ من الإنترنت» بلا provenance.
  bool acceptAsEvidence(LioSourceProvenance p) {
    if (!p.isCitable) return false;
    if (p.conflict == LioConflictStatus.confirmed) return false;
    if (weightOf(p.authority) < 0.2) return false;
    return true;
  }

  LioConflictStatus compare({
    required LioSourceProvenance a,
    required LioSourceProvenance b,
    required bool claimsContradict,
  }) {
    if (!claimsContradict) return LioConflictStatus.none;
    final wa = weightOf(a.authority);
    final wb = weightOf(b.authority);
    if ((wa - wb).abs() < 0.15) return LioConflictStatus.unresolved;
    return LioConflictStatus.confirmed;
  }

  /// اختيار الأرجح عند التعارض — بلا اختراع حقيقة طبية.
  LioSourceProvenance? prefer(LioSourceProvenance a, LioSourceProvenance b) {
    final wa = weightOf(a.authority);
    final wb = weightOf(b.authority);
    if (wa == wb) return null;
    return wa > wb ? a : b;
  }
}
