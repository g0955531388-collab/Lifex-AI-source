/// Test-only KnowledgeRetriever doubles.
/// Must NEVER be imported from lib/ production code.
library lifex_ai.test.support.knowledge_retriever_test_doubles;

import 'package:lifex_ai/core/agent/knowledge/knowledge_context.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_document.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_retriever.dart';

/// Fake صريح للاختبارات — يُحقن يدوياً فقط.
class FakeKnowledgeRetriever implements KnowledgeRetriever {
  FakeKnowledgeRetriever([this.matches = const []]);

  final List<KnowledgeDocument> matches;
  String? lastQuery;
  int retrieveCalls = 0;

  @override
  bool get isProductionKnowledgePath => false;

  @override
  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8}) async {
    retrieveCalls++;
    lastQuery = query;
    return KnowledgeContext(query: query, matches: matches);
  }

  @override
  void invalidateCache() {}
}

/// Stub فارغ للاختبارات — يُحقن يدوياً فقط.
class StubKnowledgeRetriever implements KnowledgeRetriever {
  const StubKnowledgeRetriever();

  @override
  bool get isProductionKnowledgePath => false;

  @override
  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8}) async {
    return const KnowledgeContext(query: '', matches: <KnowledgeDocument>[]);
  }

  @override
  void invalidateCache() {}
}
