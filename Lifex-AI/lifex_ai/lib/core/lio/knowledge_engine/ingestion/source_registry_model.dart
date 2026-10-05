/// =============================================================
/// Lifex-AI — نموذج سجل مصادر المعرفة (Knowledge Source Registry)
/// الوجود ≠ السلطة. LLM ليس SoT. لا Clinical.
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.source_registry_model;

import '../../lio_types.dart';
import '../../source_reliability.dart';

enum KnowledgeSourceKind {
  officialHealthAuthority,
  governmentalPublicHealth,
  regulatoryAuthority,
  peerReviewedLiterature,
  clinicalGuideline,
  medicalTerminologyStandard,
  deviceStandard,
  manufacturerDocumentation,
  educationalReference,
  internalAuthoredKnowledge,
}

enum KnowledgeSourceStatus {
  draft,
  pendingReview,
  active,
  inactive,
  superseded,
  quarantined,
  rejected,
}

enum KnowledgeDomain {
  publicHealth,
  clinicalGuideline,
  terminology,
  deviceStandard,
  pharmacologyReference,
  educational,
  engineeringProcess,
}

enum SourceConflictPolicy {
  preserveBoth,
  preferHigherAuthority,
  requireHumanReview,
}

/// قيد قيمة — لا سلسلة حرّة للـ authority/kind.
class RegisteredKnowledgeSource {
  const RegisteredKnowledgeSource({
    required this.sourceId,
    required this.kind,
    required this.title,
    required this.authority,
    required this.status,
    required this.retrievedAt,
    this.publisher,
    this.url,
    this.repository,
    this.documentRef,
    this.jurisdiction,
    this.language,
    this.license,
    this.evidenceLevel = 0.0,
    this.reliabilityWeight = 0.0,
    this.version,
    this.publicationDate,
    this.effectiveDate,
    this.lastVerifiedAt,
    this.contentHash,
    this.allowedDomains = const [KnowledgeDomain.educational],
    this.conflictPolicy = SourceConflictPolicy.preserveBoth,
    this.supersedesSourceId,
    this.supersededBySourceId,
    this.firstSeen,
    this.lastSeen,
    this.metadata = const {},
    this.provenanceNotes = const {},
  });

  final String sourceId;
  final KnowledgeSourceKind kind;
  final String title;
  final LioSourceAuthority authority;
  final KnowledgeSourceStatus status;
  final String? publisher;
  final String? url;
  final String? repository;
  final String? documentRef;
  final String? jurisdiction;
  final String? language;
  final String? license;
  final double evidenceLevel;
  final double reliabilityWeight;
  final String? version;
  final DateTime? publicationDate;
  final DateTime? effectiveDate;
  final DateTime retrievedAt;
  final DateTime? lastVerifiedAt;
  final String? contentHash;
  final List<KnowledgeDomain> allowedDomains;
  final SourceConflictPolicy conflictPolicy;
  final String? supersedesSourceId;
  final String? supersededBySourceId;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final Map<String, String> metadata;
  final Map<String, Object?> provenanceNotes;

  bool get isActive => status == KnowledgeSourceStatus.active;

  bool get isCitable =>
      (url != null && url!.isNotEmpty) ||
      (repository != null && repository!.isNotEmpty) ||
      (documentRef != null && documentRef!.isNotEmpty);

  /// تحويل إلى provenance LIO الموجود — بلا تكرار نموذج.
  LioSourceProvenance toProvenance({DateTime? retrievedOverride}) {
    return LioSourceProvenance(
      sourceId: sourceId,
      sourceType: kind.name,
      authority: authority,
      retrievedAt: retrievedOverride ?? retrievedAt,
      url: url,
      repository: repository,
      document: documentRef,
      version: version,
      author: publisher,
      license: license,
      evidenceLevel: evidenceLevel,
      confidence: reliabilityWeight,
      jurisdiction: jurisdiction,
    );
  }

  RegisteredKnowledgeSource copyWith({
    KnowledgeSourceStatus? status,
    String? version,
    String? contentHash,
    String? supersedesSourceId,
    String? supersededBySourceId,
    DateTime? lastVerifiedAt,
    DateTime? lastSeen,
    DateTime? firstSeen,
  }) {
    return RegisteredKnowledgeSource(
      sourceId: sourceId,
      kind: kind,
      title: title,
      authority: authority,
      status: status ?? this.status,
      publisher: publisher,
      url: url,
      repository: repository,
      documentRef: documentRef,
      jurisdiction: jurisdiction,
      language: language,
      license: license,
      evidenceLevel: evidenceLevel,
      reliabilityWeight: reliabilityWeight,
      version: version ?? this.version,
      publicationDate: publicationDate,
      effectiveDate: effectiveDate,
      retrievedAt: retrievedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      contentHash: contentHash ?? this.contentHash,
      allowedDomains: allowedDomains,
      conflictPolicy: conflictPolicy,
      supersedesSourceId: supersedesSourceId ?? this.supersedesSourceId,
      supersededBySourceId: supersededBySourceId ?? this.supersededBySourceId,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      metadata: metadata,
      provenanceNotes: provenanceNotes,
    );
  }
}
