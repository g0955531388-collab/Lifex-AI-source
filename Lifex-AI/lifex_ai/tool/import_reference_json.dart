/// يقرأ ملفات JSON الخارجية ويكتب الصفوف الصالحة لمرجع البحث.
/// لا يستورد قائمة أجهزة مخترعة ولا ملفاً فارغاً.
library;

import 'dart:convert';
import 'dart:io';

import 'package:lifex_ai/core/json_documents.dart';
import 'package:lifex_ai/core/reference_ledger.dart';

void main(List<String> args) {
  final sourceDir = Directory(
    args.isEmpty ? r'C:\Users\sdsds\Downloads\json' : args.first,
  );
  final out = File(
    'lib/data/reference/incoming_reference.json',
  );
  final rows = <Map<String, dynamic>>[];
  final names = sourceDir
      .listSync()
      .whereType<File>()
      .where((file) {
        final name = file.uri.pathSegments.last.toLowerCase();
        if (name == 'index.json' || name == 'download') return false;
        return name.endsWith('.json') || name.endsWith('.josn');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in names) {
    final text = file.readAsStringSync();
    final docs = splitJsonDocuments(text);
    final source = file.uri.pathSegments.last;
    for (final doc in docs) {
      rows.addAll(ReferenceLedger.fromDocuments({source: doc}).rows);
    }
  }
  const encoder = JsonEncoder.withIndent('  ');
  out.writeAsStringSync('${encoder.convert(rows)}\n');
  stdout.writeln('files=${names.length} rows=${rows.length}');
}
