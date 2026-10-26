import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/json_documents.dart';
import 'package:lifex_ai/core/reference_ledger.dart';

void main() {
  test('الملف الملتصق يُقرأ على وثائق والوثيقة المكسورة لا تُسقط ما بعدها', () {
    const raw = '''
[{"name":"AlphaOne","description":"first paragraph"}]
[{"name":"BetaDose","strength":"10mg","form":"Tablet"}]
{ "name": "BrokenRow", "description":
[{"name":"GammaKeep","description":"third paragraph"}]
''';
    final docs = splitJsonDocuments(raw);
    expect(docs, hasLength(3));
    final ledger = ReferenceLedger.fromDocuments({
      'pasted.json': docs,
    });
    expect(ledger.compare('AlphaOne').single['name'], 'AlphaOne');
    expect(ledger.compare('GammaKeep').single['name'], 'GammaKeep');
    expect(ledger.compare('BrokenRow'), isEmpty);
  });

  test('اختلاف النص تعارض ولا يُختار كحقيقة أو جرعة', () {
    final ledger = ReferenceLedger.fromDocuments({
      'project.json': [
        {'name': 'شيب', 'description': 'وصف قصير'},
        {'sign': 'Pale Face', 'meaning': 'قد يشير إلى فقر دم'},
        {'name': 'Paracetamol', 'form': 'Tablet', 'strength': '500mg'},
      ],
      'added.json': [
        {'name': 'شيب', 'description': 'وصف أطول ومختلف'},
        {'sign': 'Pale Face', 'meaning': 'قد يشير إلى فقر دم'},
        {'name': 'Paracetamol', 'form': 'Tablet', 'strength': '1000mg'},
        {'name': 'Paracetamol'},
      ],
    });
    final name = ledger.conflictsFor('شيب').single;
    expect(name.noteAr, ReferenceLedger.conflictNoteAr);
    expect(name.bodies, hasLength(2));
    expect(ledger.compare('شيب'), hasLength(2));
    expect(ledger.conflictsFor('Pale Face'), isEmpty);
    final dose = ledger.conflictsFor('Paracetamol').single;
    expect(dose.noteAr, ReferenceLedger.doseNoteAr);
    expect(dose.noteAr, contains('لا تُعتمد جرعة'));
    final merged = ledger.merged(kind: 'حالة مرجعية');
    final pale = ledger.merged(kind: 'علامة بصرية');
    expect(merged.where((row) => row['name'] == 'شيب'), hasLength(2));
    expect(pale, hasLength(1));
  });
}
