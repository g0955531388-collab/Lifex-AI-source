/// =============================================================
/// Lifex-AI — Evidence Pack للمعرفة (Provenance إلزامي)
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.evidence_pack;

import '../source_reliability.dart';
import 'knowledge_types.dart';

/// عنصر أدلة واحد داخل الحزمة.
class KnowledgeEvidenceItem {
  const KnowledgeEvidenceItem({
    required this.recordId,
    required this.title,
    required this.snippet,
    required this.score,
    required this.channel,
    required this.provenance,
    this.competingIds = const [],
  });

  final String recordId;
  final String title;
  final String snippet;
  final double score;
  final RetrievalChannel channel;
  final LioSourceProvenance provenance;
  final List<String> competingIds;

  Map<String, Object?> toMap() => {
        'recordId': recordId,
        'title': title,
        'snippet': snippet,
        'score': score,
        'channel': channel.name,
        'sourceId': provenance.sourceId,
        'sourceType': provenance.sourceType,
        'sourceUri': provenance.url,
        'repository': provenance.repository,
        'document': provenance.document,
        'version': provenance.version,
        'timestamp': provenance.retrievedAt.toIso8601String(),
        'author': provenance.author,
        'authority': provenance.authority.name,
        'evidenceLevel': provenance.evidenceLevel,
        'confidence': provenance.confidence,
        'conflictStatus': provenance.conflict.name,
        'retrievedAt': provenance.retrievedAt.toIso8601String(),
        'competingIds': competingIds,
      };
}

/// حزمة أدلة قابلة للتتبع — تُمرَّر إلى LIO / Verifier.
class KnowledgeEvidencePack {
  const KnowledgeEvidencePack({
    required this.query,
    required this.status,
    required this.items,
    required this.retrievedAt,
    this.conflicts = const [],
    this.notesAr = const [],
    this.llmIsSourceOfTruth = false,
    this.mayDiagnose = false,
    this.mayPrescribe = false,
  });

  final String query;
  final KnowledgeRetrievalStatus status;
  final List<KnowledgeEvidenceItem> items;
  final DateTime retrievedAt;
  final List<String> conflicts;
  final List<String> notesAr;

  /// دائماً false — LLM ليس SoT.
  final bool llmIsSourceOfTruth;

  /// دائماً false — لا تشخيص/وصف.
  final bool mayDiagnose;
  final bool mayPrescribe;

  bool get isEmpty => items.isEmpty;

  bool get hasConflict =>
      status == KnowledgeRetrievalStatus.conflict || conflicts.isNotEmpty;

  Map<String, Object?> toMap() => {
        'query': query,
        'status': status.wireName,
        'itemCount': items.length,
        'items': items.map((e) => e.toMap()).toList(),
        'conflicts': conflicts,
        'notesAr': notesAr,
        'llmIsSourceOfTruth': llmIsSourceOfTruth,
        'mayDiagnose': mayDiagnose,
        'mayPrescribe': mayPrescribe,
        'retrievedAt': retrievedAt.toIso8601String(),
        'layer': KnowledgeLayer.knowledge.name,
      };
}

/// يوسّع provenance بحقل lastVerified عند البناء.
LioSourceProvenance provenanceWithVerification({
  required LioSourceProvenance base,
  DateTime? lastVerified,
}) {
  return LioSourceProvenance(
    sourceId: base.sourceId,
    sourceType: base.sourceType,
    authority: base.authority,
    retrievedAt: base.retrievedAt,
    url: base.url,
    repository: base.repository,
    commit: base.commit,
    document: base.document,
    version: base.version,
    author: base.author,
    license: base.license,
    evidenceLevel: base.evidenceLevel,
    confidence: base.confidence,
    conflict: base.conflict,
    jurisdiction: base.jurisdiction ??
        (lastVerified == null
            ? null
            : 'lastVerified=${lastVerified.toIso8601String()}'),
  );
}
