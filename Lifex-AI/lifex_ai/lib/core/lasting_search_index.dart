/// =============================================================
/// Lifex-AI — البحث الداخلي الدائم
/// الملف: lasting_search_index.dart
/// قواعد تُضاف للمحرك الداخلي بلا تاريخ انتهاء. ليست تشخيصاً.
/// =============================================================
library lifex_ai.core.lasting_search_index;

import 'local_knowledge.dart';
import 'medical_record_canon.dart';

class LastingSearchIndex {
  LastingSearchIndex();

  final List<Map<String, dynamic>> _rows = [];

  int get count => _rows.length;
  bool get neverExpires => true;

  void ingest(Iterable<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final title = (row['nameAr'] ??
              row['name'] ??
              row['sign'] ??
              row['title'] ??
              '')
          .toString()
          .trim();
      if (title.isEmpty) continue;
      final key = MedicalRecordCanon.normalize(title);
      final exists = _rows.any(
        (item) =>
            MedicalRecordCanon.normalize(
              '${item['nameAr'] ?? item['name'] ?? item['sign'] ?? ''}',
            ) ==
            key,
      );
      if (exists) continue;
      _rows.add({
        ...row,
        'lasting': true,
      });
    }
  }

  List<KnowledgeHit> search(String query) {
    final q = MedicalRecordCanon.normalize(query);
    if (q.isEmpty) return const [];
    final hits = <KnowledgeHit>[];
    for (final row in _rows) {
      final blob = MedicalRecordCanon.normalize(
        '${row['nameAr'] ?? ''} ${row['name'] ?? ''} ${row['sign'] ?? ''} '
        '${row['description'] ?? ''} ${row['meaning'] ?? ''} ${row['nameEn'] ?? ''}',
      );
      if (!MedicalRecordCanon.queryMatches(blob, q)) continue;
      hits.add(
        KnowledgeHit(
          kindAr: 'قاعدة داخلية دائمة',
          titleAr: (row['nameAr'] ?? row['name'] ?? row['sign'] ?? row['id'])
              .toString(),
          detailAr:
              '${row['description'] ?? row['meaning'] ?? row['generalInfoAr'] ?? ''} '
              'بلا انتهاء صلاحية في محرك البحث الداخلي.',
        ),
      );
      if (hits.length >= 8) break;
    }
    return hits;
  }
}

class InternalSearchEngine {
  const InternalSearchEngine({
    required this.knowledge,
    required this.lasting,
  });

  final LocalKnowledge knowledge;
  final LastingSearchIndex lasting;

  List<KnowledgeHit> search(String query) {
    final merged = [...knowledge.search(query), ...lasting.search(query)];
    final seen = <String>{};
    return [
      for (final hit in merged)
        if (seen.add('${hit.kindAr}:${hit.titleAr}')) hit,
    ];
  }
}
