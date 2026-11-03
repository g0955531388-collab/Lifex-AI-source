/// =============================================================
/// Lifex-AI — محولات استرجاع محلية قابلة للاختبار
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.local_retrievers;

import 'dart:math';

import '../lio_types.dart';
import 'knowledge_types.dart';
import 'retrieval_adapters.dart';

/// BM25 مبسّط محلي (Okapi-like) — بلا اعتماد خارجي.
class LocalBm25KeywordRetriever implements KeywordRetriever {
  LocalBm25KeywordRetriever(this.corpus, {this.k1 = 1.2, this.b = 0.75});

  final KnowledgeCorpus corpus;
  final double k1;
  final double b;

  @override
  RetrievalChannel get channel => RetrievalChannel.keywordBm25;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async {
    final qTerms = _tokenize(query.text);
    if (qTerms.isEmpty) return const [];

    final docs = corpus.records
        .where((r) => r.layer == KnowledgeLayer.knowledge)
        .toList();
    if (docs.isEmpty) return const [];

    final N = docs.length;
    final avgdl = docs
            .map((d) => _tokenize(d.searchableText).length)
            .fold<int>(0, (a, c) => a + c) /
        N;

    final df = <String, int>{};
    for (final t in qTerms) {
      df[t] = docs.where((d) => _tokenize(d.searchableText).contains(t)).length;
    }

    final hits = <ScoredKnowledgeHit>[];
    for (final doc in docs) {
      final tokens = _tokenize(doc.searchableText);
      if (tokens.isEmpty) continue;
      final tfMap = <String, int>{};
      for (final t in tokens) {
        tfMap[t] = (tfMap[t] ?? 0) + 1;
      }
      double score = 0;
      for (final t in qTerms) {
        final tf = (tfMap[t] ?? 0).toDouble();
        if (tf == 0) continue;
        final nQi = df[t] ?? 0;
        final idf = log(((N - nQi + 0.5) / (nQi + 0.5)) + 1);
        final denom = tf + k1 * (1 - b + b * (tokens.length / avgdl));
        score += idf * ((tf * (k1 + 1)) / denom);
      }
      if (score > 0) {
        hits.add(ScoredKnowledgeHit(
          record: doc,
          score: score,
          channel: channel,
        ));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(query.topK).toList();
  }

  List<String> _tokenize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
      .split(RegExp(r'[^a-z0-9\u0600-\u06ff]+'))
      .where((t) => t.length >= 2)
      .toList();
}

/// Vector غير موصول — صادق.
class UnavailableVectorRetriever implements VectorRetriever {
  const UnavailableVectorRetriever();

  @override
  RetrievalChannel get channel => RetrievalChannel.vector;

  @override
  bool get isAvailable => false;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async =>
      const [];
}

/// Vector في الذاكرة للاختبارات فقط (cosine على embedding محقون).
class InMemoryVectorRetriever implements VectorRetriever {
  InMemoryVectorRetriever(this.corpus);

  final KnowledgeCorpus corpus;

  @override
  RetrievalChannel get channel => RetrievalChannel.vector;

  @override
  bool get isAvailable => true;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async {
    final withEmb = corpus.records
        .where((r) =>
            r.layer == KnowledgeLayer.knowledge &&
            r.embedding != null &&
            r.embedding!.isNotEmpty)
        .toList();
    if (withEmb.isEmpty) return const [];

    final seed = withEmb
        .where((r) => r.searchableText.contains(query.text.toLowerCase()))
        .toList();
    final queryVec =
        seed.isNotEmpty ? seed.first.embedding! : withEmb.first.embedding!;

    final hits = <ScoredKnowledgeHit>[];
    for (final r in withEmb) {
      final s = _cosine(queryVec, r.embedding!);
      if (s > 0) {
        hits.add(ScoredKnowledgeHit(record: r, score: s, channel: channel));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(query.topK).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }
}

class LocalMetadataFilterRetriever implements MetadataFilterRetriever {
  LocalMetadataFilterRetriever(this.corpus);

  final KnowledgeCorpus corpus;

  @override
  RetrievalChannel get channel => RetrievalChannel.metadata;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async {
    if (query.metadataEquals.isEmpty) return const [];
    final hits = <ScoredKnowledgeHit>[];
    for (final r in corpus.records) {
      if (r.layer != KnowledgeLayer.knowledge) continue;
      var ok = true;
      for (final e in query.metadataEquals.entries) {
        if (r.metadata[e.key] != e.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        hits.add(ScoredKnowledgeHit(record: r, score: 1.0, channel: channel));
      }
    }
    return hits.take(query.topK).toList();
  }
}

class LocalGraphRelationshipRetriever implements GraphRelationshipRetriever {
  LocalGraphRelationshipRetriever(this.corpus);

  final KnowledgeCorpus corpus;

  @override
  RetrievalChannel get channel => RetrievalChannel.graph;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async {
    final byId = {for (final r in corpus.records) r.id: r};
    final seeds = corpus.records.where((r) =>
        r.layer == KnowledgeLayer.knowledge &&
        r.searchableText.contains(query.text.toLowerCase()));
    final hits = <ScoredKnowledgeHit>[];
    final seen = <String>{};
    for (final seed in seeds) {
      for (final rel in seed.relatedIds) {
        final r = byId[rel];
        if (r == null || r.layer != KnowledgeLayer.knowledge) continue;
        if (!seen.add(r.id)) continue;
        hits.add(ScoredKnowledgeHit(record: r, score: 0.5, channel: channel));
      }
    }
    return hits.take(query.topK).toList();
  }
}

/// SQL منظم — غير موصول؛ Clinical ممنوع دائمًا.
class UnavailableStructuredSqlRetriever implements StructuredSqlRetriever {
  const UnavailableStructuredSqlRetriever();

  @override
  RetrievalChannel get channel => RetrievalChannel.structuredSql;

  @override
  bool get isAvailable => false;

  @override
  bool get mayTouchClinical => false;

  @override
  Future<List<ScoredKnowledgeHit>> search(KnowledgeQuery query) async {
    if (query.allowClinical) {
      throw StateError('FORBIDDEN — Structured SQL لا يلمس Clinical.');
    }
    return const [];
  }
}

/// إعادة ترتيب: سلطة المصدر + درجة القناة − عقوبة التعارض.
class AuthorityAwareReranker implements KnowledgeReranker {
  const AuthorityAwareReranker();

  @override
  List<ScoredKnowledgeHit> rerank({
    required KnowledgeQuery query,
    required List<ScoredKnowledgeHit> hits,
  }) {
    final ranked = List<ScoredKnowledgeHit>.of(hits);
    ranked.sort((a, b) => _weight(b).compareTo(_weight(a)));
    return ranked.take(query.topK).toList();
  }

  double _weight(ScoredKnowledgeHit h) {
    final auth = h.record.provenance.authority.index;
    final authorityBoost =
        (LioSourceAuthority.values.length - auth).toDouble();
    final conflictPenalty =
        h.record.provenance.conflict == LioConflictStatus.none ? 0.0 : 2.0;
    return h.score + authorityBoost - conflictPenalty;
  }
}
