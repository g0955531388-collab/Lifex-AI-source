/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: knowledge_agent.dart
/// المسار: lib/core/agent/agents/knowledge_agent.dart
/// الوصف: الوكيل المعرفي (بند 14). مسؤوليته البحث في قاعدة المعرفة عبر
/// KnowledgeRetriever وبناء Context جاهز للوكيل المطلوب. طبقة رقيقة
/// جداً — كل المنطق الفعلي في knowledge/knowledge_retriever.dart.
/// =============================================================
library;

import '../knowledge/knowledge_context.dart';
import '../knowledge/knowledge_retriever.dart';
import 'specialized_agent.dart';

class KnowledgeAgent implements SpecializedAgent {
  KnowledgeAgent({required KnowledgeRetriever retriever})
      : _retriever = retriever;

  final KnowledgeRetriever _retriever;

  @override
  String get agentName => 'KnowledgeAgent';

  @override
  String get responsibilityAr =>
      'البحث في قاعدة المعرفة وبناء سياق جاهز للوكيل المطلوب.';

  Future<KnowledgeContext> search(String query, {int maxResults = 8}) {
    return _retriever.retrieve(query, maxResults: maxResults);
  }
}
