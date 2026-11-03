/// =============================================================
/// Lifex-AI — أنواع Knowledge Engine (Foundation)
/// Knowledge ≠ Clinical Data ≠ AI Memory. LLM ليس مصدر الحقيقة.
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.knowledge_types;

import '../source_reliability.dart';

/// طبقة البيانات — فصل صارم.
enum KnowledgeLayer {
  /// معرفة طبية/علمية عامة (مرجع 54 وما شابهه كمعرفة عامة).
  knowledge,

  /// بيانات مريض خاصة — محظورة على Knowledge Engine.
  clinicalData,

  /// سياق AI فقط — ليس SoT.
  aiMemory,
}

enum RetrievalChannel {
  keywordBm25,
  vector,
  metadata,
  graph,
  structuredSql,
}

enum KnowledgeRetrievalStatus {
  ok,
  empty,
  conflict,
  missingProvenance,
  toolUnavailable,
  forbidden,
}

extension KnowledgeRetrievalStatusX on KnowledgeRetrievalStatus {
  String get wireName {
    switch (this) {
      case KnowledgeRetrievalStatus.ok:
        return 'OK';
      case KnowledgeRetrievalStatus.empty:
        return 'EMPTY';
      case KnowledgeRetrievalStatus.conflict:
        return 'CONFLICT';
      case KnowledgeRetrievalStatus.missingProvenance:
        return 'MISSING_PROVENANCE';
      case KnowledgeRetrievalStatus.toolUnavailable:
        return 'TOOL_UNAVAILABLE';
      case KnowledgeRetrievalStatus.forbidden:
        return 'FORBIDDEN';
    }
  }
}

/// وحدة معرفة مفهرسة — ليست سجلًا سريريًا.
class KnowledgeRecord {
  const KnowledgeRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.provenance,
    this.layer = KnowledgeLayer.knowledge,
    this.terms = const [],
    this.metadata = const {},
    this.relatedIds = const [],
    this.embedding,
  });

  final String id;
  final String title;
  final String body;
  final LioSourceProvenance provenance;
  final KnowledgeLayer layer;
  final List<String> terms;
  final Map<String, String> metadata;
  final List<String> relatedIds;

  /// متجه اختياري — null إن لم يتوفر محرك vector.
  final List<double>? embedding;

  String get searchableText =>
      ('$title $body ${terms.join(' ')}').toLowerCase();
}

class KnowledgeQuery {
  const KnowledgeQuery({
    required this.text,
    this.metadataEquals = const {},
    this.channels = const [
      RetrievalChannel.keywordBm25,
      RetrievalChannel.metadata,
      RetrievalChannel.graph,
    ],
    this.topK = 8,
    this.allowClinical = false,
    this.requireProvenance = true,
  });

  final String text;
  final Map<String, String> metadataEquals;
  final List<RetrievalChannel> channels;
  final int topK;

  /// دائمًا false في المسار الآمن — أي true يُرفض.
  final bool allowClinical;
  final bool requireProvenance;
}

class ScoredKnowledgeHit {
  const ScoredKnowledgeHit({
    required this.record,
    required this.score,
    required this.channel,
  });

  final KnowledgeRecord record;
  final double score;
  final RetrievalChannel channel;
}
