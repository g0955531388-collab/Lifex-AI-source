/// مرجع للمقارنة. التعارض يُعرض ولا يُختار منه تشخيص أو جرعة.
library lifex_ai.core.reference_ledger;

import 'medical_record_canon.dart';

class ReferenceConflict {
  const ReferenceConflict({
    required this.title,
    required this.kind,
    required this.sources,
    required this.bodies,
    required this.noteAr,
  });

  final String title;
  final String kind;
  final List<String> sources;
  final List<String> bodies;
  final String noteAr;
}

class ReferenceLedger {
  const ReferenceLedger({
    required this.rows,
    required this.conflicts,
  });

  static const empty = ReferenceLedger(rows: [], conflicts: []);

  final List<Map<String, dynamic>> rows;
  final List<ReferenceConflict> conflicts;

  static const conflictNoteAr =
      'تعارض بين المصادر على هذا العنوان. لا يُختار أحد النصين كحقيقة.';

  static const doseNoteAr =
      'تعارض في وصف الدواء بين المصادر. لا تُعتمد جرعة من هذا التعارض.';

  static ReferenceLedger fromDocuments(Map<String, Object?> documents) {
    final rows = <Map<String, dynamic>>[];
    for (final entry in documents.entries) {
      rows.addAll(_rowsOf(entry.key, entry.value));
    }
    return ReferenceLedger(rows: rows, conflicts: conflictsAmong(rows));
  }

  static List<ReferenceConflict> conflictsAmong(
    List<Map<String, dynamic>> rows,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final title = _title(row);
      if (title.isEmpty) continue;
      final key = '${_kind(row)}|${MedicalRecordCanon.normalize(title)}';
      groups.putIfAbsent(key, () => []).add(row);
    }
    final found = <ReferenceConflict>[];
    for (final group in groups.values) {
      final bodies = <String, List<String>>{};
      for (final row in group) {
        final body = _body(row);
        if (body.isEmpty) continue;
        final folded = MedicalRecordCanon.normalize(body);
        bodies.putIfAbsent(folded, () => []).add(_source(row));
      }
      if (bodies.length < 2) continue;
      final sample = group.first;
      final kind = _kind(sample);
      found.add(
        ReferenceConflict(
          title: _title(sample),
          kind: kind,
          sources: {
            for (final row in group) _source(row),
          }.toList(),
          bodies: {
            for (final row in group)
              if (_body(row).isNotEmpty) _body(row),
          }.toList(),
          noteAr: kind == 'دواء مرجعي' ? doseNoteAr : conflictNoteAr,
        ),
      );
    }
    return found;
  }

  /// السابق أولاً. النص المطابق يُبقى مرة واحدة، والنص المختلف يُبقى معه.
  List<Map<String, dynamic>> merged({String? kind}) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final rowKind = _kind(row);
      if (kind != null && rowKind != kind) continue;
      final key = '$rowKind|${MedicalRecordCanon.normalize(_title(row))}';
      groups.putIfAbsent(key, () => []).add(row);
    }
    final out = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      final filled = [
        for (final row in group)
          if (_body(row).trim().isNotEmpty) row,
      ];
      final source = filled.isEmpty ? group : filled;
      final seen = <String>{};
      for (final row in source) {
        if (seen.add(MedicalRecordCanon.normalize(_body(row)))) out.add(row);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> compare(String query) {
    final q = MedicalRecordCanon.normalize(query);
    if (q.isEmpty) return const [];
    return [
      for (final row in rows)
        if (MedicalRecordCanon.queryMatches(_blob(row), q)) row,
    ];
  }

  List<ReferenceConflict> conflictsFor(String query) {
    final q = MedicalRecordCanon.normalize(query);
    if (q.isEmpty) return const [];
    return [
      for (final item in conflicts)
        if (MedicalRecordCanon.queryMatches(
          MedicalRecordCanon.normalize('${item.title} ${item.kind}'),
          q,
        ))
          item,
    ];
  }

  static List<Map<String, dynamic>> _rowsOf(String source, Object? decoded) {
    if (decoded is List) {
      return [
        for (final item in decoded) ..._rowsOf(source, item),
      ];
    }
    if (decoded is Map || decoded is String) return _one(source, decoded);
    return const [];
  }

  static List<Map<String, dynamic>> _one(String source, Object? item) {
    if (item is String) {
      final title = item.trim();
      if (title.isEmpty || title.contains('...')) return const [];
      return [
        {
          'source': source,
          'ledgerKind': 'دواء مرجعي',
          'name': title,
        },
      ];
    }
    if (item is! Map) return const [];
    final row = Map<String, dynamic>.from(item);
    final title = _title(row);
    if (title.isEmpty || title.contains('...')) return const [];
    final body = _body(row);
    if (body.contains('...')) return const [];
    row['source'] = row['source'] ?? source;
    row['ledgerKind'] = _kind(row);
    return [row];
  }

  static String _source(Map<String, dynamic> row) =>
      (row['source'] ?? '').toString();

  static String titleOf(Map<String, dynamic> row) => _title(row);

  static String bodyOf(Map<String, dynamic> row) => _body(row);

  static String kindOf(Map<String, dynamic> row) => _kind(row);

  static String _title(Map<String, dynamic> row) {
    for (final key in ['name', 'sign', 'nameAr', 'nameEn', 'age_group', 'title']) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _kind(Map<String, dynamic> row) {
    final given = '${row['ledgerKind'] ?? ''}'.trim();
    if (given.isNotEmpty) return given;
    if ('${row['age_group'] ?? ''}'.trim().isNotEmpty) return 'معيار نمو';
    if ('${row['sign'] ?? ''}'.trim().isNotEmpty) return 'علامة بصرية';
    if ('${row['strength'] ?? ''}'.trim().isNotEmpty ||
        '${row['form'] ?? ''}'.trim().isNotEmpty) {
      return 'دواء مرجعي';
    }
    return 'حالة مرجعية';
  }

  static String _body(Map<String, dynamic> row) {
    final symptoms = row['symptoms'];
    final symptomText = symptoms is List ? symptoms.join('، ') : '';
    final male = row['male'];
    final female = row['female'];
    final growth = male is Map || female is Map
        ? 'ذكر ${_measure(male)} أنثى ${_measure(female)}'
        : '';
    return [
      row['meaning'],
      row['description'],
      row['form'],
      row['strength'],
      row['category'],
      symptomText,
      growth,
    ].where((part) => part != null && '$part'.trim().isNotEmpty).join(' — ');
  }

  static String _measure(Object? side) {
    if (side is! Map) return '';
    return '${side['height_cm'] ?? ''} سم ${side['weight_kg'] ?? ''} كغم'.trim();
  }

  static String _blob(Map<String, dynamic> row) => MedicalRecordCanon.normalize(
        '${_title(row)} ${_body(row)} ${_kind(row)}',
      );
}
