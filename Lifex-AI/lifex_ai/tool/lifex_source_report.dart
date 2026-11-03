// تقرير تحليل المصدر: lib/ و test/ فقط، بلا حزم مبنية.
// التشغيل من مجلد lifex_ai:
//   dart run tool/lifex_source_report.dart
// يخرج غير صفري إذا وُجد CRITICAL أو HIGH.
import 'dart:io';

const roots = ['lib', 'test'];
const reportPath = 'docs/implementation/source_analysis_report.md';

const deadCode = {
  'DEAD_CODE',
  'DEAD_CODE_CATCH_FOLLOWING_CATCH',
  'DEAD_NULL_AWARE_EXPRESSION',
  'UNUSED_ELEMENT',
  'UNUSED_FIELD',
  'UNUSED_IMPORT',
  'UNUSED_LOCAL_VARIABLE',
  'UNUSED_CATCH_CLAUSE',
  'UNUSED_CATCH_STACK',
  'UNNECESSARY_IMPORT',
  'UNREACHABLE_SWITCH_CASE',
};

const nullSafety = {
  'UNNECESSARY_NULL_COMPARISON',
  'UNNECESSARY_NON_NULL_ASSERTION',
  'INVALID_NULL_AWARE_OPERATOR',
  'UNNECESSARY_NULL_CHECKS',
  'NULL_CHECK_ON_NULLABLE_TYPE_PARAMETER',
  'UNNECESSARY_NULL_AWARE_ASSIGNMENTS',
  'UNNECESSARY_NULLABLE_FOR_FINAL_VARIABLE_DECLARATIONS',
  'NULL_CHECK_ALWAYS_FAILS',
  'RECEIVER_OF_TYPE_NEVER',
};

const performance = {
  'PREFER_CONST_CONSTRUCTORS',
  'PREFER_CONST_CONSTRUCTORS_IN_IMMUTABLES',
  'PREFER_CONST_DECLARATIONS',
  'PREFER_CONST_LITERALS_TO_CREATE_IMMUTABLES',
  'AVOID_UNNECESSARY_CONTAINERS',
  'SIZED_BOX_FOR_WHITESPACE',
  'UNNECESSARY_TO_LIST_IN_SPREADS',
};

/// أخطاء صحة وقت التشغيل تُرفع إلى HIGH حتى لو صنّفها المحلل معلومة.
const runtimeRisk = {
  'USE_BUILD_CONTEXT_SYNCHRONOUSLY',
  'DEPRECATED_MEMBER_USE',
  'AVOID_PRINT',
};

class Issue {
  Issue(this.severity, this.type, this.code, this.file, this.line, this.message);
  final String severity;
  final String type;
  final String code;
  final String file;
  final int line;
  final String message;

  String get category {
    if (severity == 'ERROR') return 'error';
    if (deadCode.contains(code)) return 'dead-code';
    if (nullSafety.contains(code)) return 'null-safety';
    if (performance.contains(code)) return 'performance';
    return 'other';
  }

  String get tier {
    if (severity == 'ERROR') return 'CRITICAL';
    if (severity == 'WARNING' || runtimeRisk.contains(code)) return 'HIGH';
    if (category == 'dead-code' || category == 'null-safety') return 'MEDIUM';
    return 'LOW';
  }
}

String _relative(String path, String root) {
  final normal = path.replaceAll(r'\\', '/').replaceAll('\\', '/');
  final base = root.replaceAll('\\', '/');
  return normal.startsWith('$base/') ? normal.substring(base.length + 1) : normal;
}

Future<void> main() async {
  final root = Directory.current.path;
  final dart = Platform.resolvedExecutable;
  final run = await Process.run(dart, ['analyze', '--format=machine', ...roots]);
  final raw = '${run.stdout}\n${run.stderr}';
  final issues = <Issue>[];
  for (final line in raw.split('\n')) {
    final parts = line.trim().split('|');
    if (parts.length < 8) continue;
    if (!{'ERROR', 'WARNING', 'INFO'}.contains(parts[0])) continue;
    final file = _relative(parts[3], root);
    if (file.startsWith('build/') || file.contains('.dart_tool/')) continue;
    issues.add(Issue(
      parts[0],
      parts[1],
      parts[2],
      file,
      int.tryParse(parts[4]) ?? 0,
      parts.sublist(7).join('|'),
    ));
  }
  const tierOrder = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
  issues.sort((a, b) {
    final t = tierOrder.indexOf(a.tier).compareTo(tierOrder.indexOf(b.tier));
    if (t != 0) return t;
    final f = a.file.compareTo(b.file);
    return f != 0 ? f : a.line.compareTo(b.line);
  });
  final byTier = {for (final t in tierOrder) t: 0};
  final byCategory = <String, int>{};
  for (final issue in issues) {
    byTier[issue.tier] = byTier[issue.tier]! + 1;
    byCategory[issue.category] = (byCategory[issue.category] ?? 0) + 1;
  }
  final out = StringBuffer()
    ..writeln('# Source analysis report')
    ..writeln()
    ..writeln('Roots: ${roots.join(', ')}. Built packages are not analyzed.')
    ..writeln('Command: `dart run tool/lifex_source_report.dart`')
    ..writeln()
    ..writeln('| Tier | Count |')
    ..writeln('|---|---:|');
  for (final t in tierOrder) {
    out.writeln('| $t | ${byTier[t]} |');
  }
  out
    ..writeln()
    ..writeln('| Category | Count |')
    ..writeln('|---|---:|');
  for (final c in ['error', 'performance', 'dead-code', 'null-safety', 'other']) {
    out.writeln('| $c | ${byCategory[c] ?? 0} |');
  }
  out
    ..writeln()
    ..writeln('| Tier | Category | Code | File | Line | Message |')
    ..writeln('|---|---|---|---|---:|---|');
  for (final i in issues) {
    final message = i.message.replaceAll('|', '/');
    out.writeln(
        '| ${i.tier} | ${i.category} | ${i.code} | ${i.file} | ${i.line} | $message |');
  }
  final file = File(reportPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(out.toString());
  stdout.writeln('issues ${issues.length}');
  for (final t in tierOrder) {
    stdout.writeln('$t ${byTier[t]}');
  }
  for (final c in byCategory.keys) {
    stdout.writeln('category $c ${byCategory[c]}');
  }
  stdout.writeln('report $reportPath');
  final blocking = byTier['CRITICAL']! + byTier['HIGH']!;
  exitCode = blocking > 0 ? 1 : 0;
}
