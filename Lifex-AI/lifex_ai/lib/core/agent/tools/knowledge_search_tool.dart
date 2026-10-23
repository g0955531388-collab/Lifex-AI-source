/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: knowledge_search_tool.dart
/// المسار: lib/core/agent/tools/knowledge_search_tool.dart
/// الوصف: غلاف حول KnowledgeRetriever (agent/knowledge/) ليكون قابلاً
/// للاستدعاء ضمن الخطة كأداة عادية، بنفس عقد AgentTool مثل بقية الأدوات.
/// =============================================================
library;

import '../agent_context.dart';
import '../agent_permissions.dart';
import '../knowledge/knowledge_retriever.dart';
import 'agent_tool.dart';

class KnowledgeSearchTool implements AgentTool {
  KnowledgeSearchTool({required KnowledgeRetriever retriever})
      : _retriever = retriever;

  final KnowledgeRetriever _retriever;

  @override
  String get name => 'knowledge_search';

  @override
  String get descriptionAr =>
      'البحث في قاعدة المعرفة الطبية المحلية عن أمراض/أعراض/أدوية/تحاليل ذات صلة.';

  @override
  Map<String, String> get inputSchema => const {
        'query': 'String — نص البحث (طلب المستخدم أو نص مستخرج من مستند)',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.readKnowledgeBase},
        riskLevel: AgentActionRiskLevel.low,
      );

  @override
  bool validate(Map<String, dynamic> arguments) {
    // يقبل query صريحاً، أو يستنتج من userRequest القادم تلقائياً من
    // AgentExecutor._buildArgumentsFor — لذا لا نرفض غياب query وحده.
    return true;
  }

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final query = (arguments['query'] as String?) ??
        (arguments['userRequest'] as String?) ??
        _extractedTextFromPriorObservations(arguments) ??
        '';

    if (query.trim().isEmpty) {
      return const AgentToolExecutionResult.failure(
          'لا يوجد نص واضح للبحث عنه في قاعدة المعرفة.');
    }

    final result = await _retriever.retrieve(query);

    return AgentToolExecutionResult.success({
      'dataType': 'knowledge_search',
      'matchCount': result.matches.length,
      'items': result.toContextMap()['items'],
      'confidence': result.isEmpty ? 'low' : 'medium',
    });
  }

  String? _extractedTextFromPriorObservations(Map<String, dynamic> arguments) {
    final prior = arguments['priorObservations'] as List<dynamic>?;
    if (prior == null) return null;
    for (final obs in prior) {
      if (obs is Map<String, dynamic> && obs['extractedText'] is String) {
        return obs['extractedText'] as String;
      }
    }
    return null;
  }
}
