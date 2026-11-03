/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: knowledge_context.dart
/// نتيجة استرجاع معرفة — متوافقة مع العقود القديمة + حقول Evidence Pack.
/// =============================================================
library lifex_ai.core.agent.knowledge.knowledge_context;

import 'knowledge_document.dart';

class KnowledgeContext {
  const KnowledgeContext({
    required this.query,
    required this.matches,
    this.retrievalStatus,
    this.conflicts = const [],
    this.notesAr = const [],
    this.evidencePackMap,
    this.llmIsSourceOfTruth = false,
  });

  final String query;
  final List<KnowledgeDocument> matches;

  /// حالة الاسترجاع من Knowledge Engine (EMPTY / CONFLICT / …).
  final String? retrievalStatus;
  final List<String> conflicts;
  final List<String> notesAr;
  final Map<String, Object?>? evidencePackMap;

  /// دائماً false عبر الجسر — LLM ليس SoT.
  final bool llmIsSourceOfTruth;

  bool get isEmpty => matches.isEmpty;

  bool get hasConflict =>
      conflicts.isNotEmpty || retrievalStatus == 'CONFLICT';

  /// تحويل مضغوط لإدراجه في AgentContext دون إرسال الحقول الخام كاملة
  /// لكل وحدة معرفة (Context Filtering — بند 11/33).
  Map<String, dynamic> toContextMap({int maxItems = 5}) {
    final limited = matches.take(maxItems);
    return {
      'query': query,
      'matchCount': matches.length,
      'retrievalStatus': retrievalStatus,
      'conflicts': conflicts,
      'notesAr': notesAr,
      'llmIsSourceOfTruth': llmIsSourceOfTruth,
      'items': limited
          .map((doc) => {
                'id': doc.id,
                'category': doc.category,
                'sourceFile': doc.sourceFile,
                'data': doc.raw,
              })
          .toList(),
    };
  }
}
