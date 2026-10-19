/// =============================================================
/// Lifex-AI — عقود الاسترجاع الهجين (Adapters)
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.retrieval_contracts;

import 'knowledge_types.dart';

abstract class KnowledgeCorpus {
  Iterable<KnowledgeRecord> get records;
}

class InMemoryKnowledgeCorpus implements KnowledgeCorpus {
  InMemoryKnowledgeCorpus([List<KnowledgeRecord>? seed])
      : _records = List.of(seed ?? const []);

  final List<KnowledgeRecord> _records;

  @override
  Iterable<KnowledgeRecord> get records => List.unmodifiable(_records);

  void add(KnowledgeRecord r) {
    if (r.layer == KnowledgeLayer.clinicalData) {
      throw StateError(
        'FORBIDDEN — Knowledge corpus يرفض Clinical Data.',
      );
    }
    _records.add(r);
  }
}

abstract class KeywordRetriever {
  RetrievalChannel get channel => RetrievalChannel.keywordBm25;
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query);
}

abstract class VectorRetriever {
  RetrievalChannel get channel => RetrievalChannel.vector;
  bool get isAvailable;
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query);
}

abstract class MetadataFilterRetriever {
  RetrievalChannel get channel => RetrievalChannel.metadata;
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query);
}

abstract class GraphRelationshipRetriever {
  RetrievalChannel get channel => RetrievalChannel.graph;
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query);
}

abstract class StructuredSqlRetriever {
  RetrievalChannel get channel => RetrievalChannel.structuredSql;
  bool get isAvailable;
  bool get mayTouchClinical => false;
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query);
}

abstract class KnowledgeReranker {
  List<ScoredKnowledgeHit> rerank({
    required KnowledgeQuery query,
    required List<ScoredKnowledgeHit> hits,
  });
}
