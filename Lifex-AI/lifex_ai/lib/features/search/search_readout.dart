/// نص بطاقة نتائج البحث للنطق: كل نتيجة بمصدرها، والتقريبي موسوم، والخاتمة تنبيه المرجع.
library lifex_ai.features.search.search_readout;

import '../../core/local_knowledge.dart';

class SearchReadout {
  const SearchReadout._();

  static const spokenLimit = 3;

  static String compose({
    required String query,
    required List<KnowledgeHit> hits,
    required bool approximate,
    required bool english,
    String publicSummary = '',
  }) {
    final parts = <String>[];
    final shown = hits.take(spokenLimit).toList();
    if (shown.isEmpty) {
      parts.add(english
          ? 'No result inside Lifex-AI for: $query.'
          : 'لا نتيجة داخل Lifex-AI لعبارة: $query.');
    } else {
      if (approximate) {
        parts.add(english
            ? 'No exact match for $query. Closest results, check the name:'
            : 'لا تطابق حرفي لعبارة $query. أقرب النتائج، تحقّق من الاسم:');
      } else {
        parts.add(english
            ? 'Found ${hits.length} results inside Lifex-AI.'
            : 'وجدت ${hits.length} نتيجة داخل Lifex-AI.');
      }
      for (var i = 0; i < shown.length; i++) {
        final hit = shown[i];
        parts.add(english
            ? '${i + 1}. ${hit.titleAr}. Source: local reference, ${hit.kindAr}.'
            : '${i + 1}. ${hit.titleAr}. المصدر: مرجع محلي، ${hit.kindAr}.');
      }
    }
    final summary = publicSummary.trim();
    if (summary.isNotEmpty) {
      parts.add(english
          ? 'Public engine summary without a key: $summary'
          : 'خلاصة محرك عام بلا مفتاح: $summary');
    }
    parts.add(english
        ? 'Awareness reference only. Not a diagnosis and not a substitute for a doctor.'
        : 'مرجع توعية فقط. ليس تشخيصاً ولا بديلاً عن الطبيب.');
    return parts.join('\n');
  }
}
