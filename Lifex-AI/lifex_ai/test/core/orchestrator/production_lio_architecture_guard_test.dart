import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway.dart';

void main() {
  final libRoot = Directory('lib');

  List<File> dartFilesUnder(Directory dir) {
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String norm(String p) => p.replaceAll('\\', '/');

  test('Only one ProductionLioGateway class in lib/', () {
    final hits = <String>[];
    for (final f in dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (text.contains('class ProductionLioGateway')) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(hits.single, contains('lio_gateway.dart'));
    expect(ProductionLioGateway.gatewayId, 'ProductionLioGateway');
  });

  test('Production composition wires LIO gateway to fabric.lio', () {
    final text =
        File('lib/core/lio/lifex_production_composition.dart').readAsStringSync();
    expect(text.contains('ProductionLioGateway'), isTrue);
    expect(text.contains('lioGateway'), isTrue);
    expect(text.contains('identical(gateway.orchestrator, fabric.lio)'), isTrue);
  });

  test('AppContext exposes lioGateway from production bundle only', () {
    final text =
        File('lib/core/lio/lifex_app_context.dart').readAsStringSync();
    expect(text.contains('ProductionLioGateway get lioGateway'), isTrue);
    expect(text.contains('production.lioGateway'), isTrue);
    expect(text.contains('ProductionLioGateway('), isFalse);
  });

  test('LIO gateway does not talk SQL/DB/medical driver directly', () {
    final files = [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_gateway_policy.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      expect(text.contains('MedicalDatabaseManager'), isFalse, reason: path);
      expect(text.contains('sqflite'), isFalse, reason: path);
      expect(text.contains('SELECT '), isFalse, reason: path);
      expect(text.contains('FakeKnowledgeRetriever'), isFalse, reason: path);
      expect(text.contains('StubKnowledgeRetriever'), isFalse, reason: path);
    }
  });

  test('No Fake/Stub LIO gateway doubles in lib/', () {
    final offenders = <String>[];
    for (final f in dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (RegExp(r'class\s+(Fake|Stub)\w*LioGateway\b').hasMatch(text)) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Production path documents mandatory LIO flow steps', () {
    expect(
      ProductionLioGateway.productionFlow,
      containsAll([
        'Human/UI',
        'LifexAppContext',
        'LIO',
        'Identity',
        'Authentication',
        'Authorization',
        'Consent',
        'MCP Gateway',
        'Audit',
      ]),
    );
  });

  test('Agent/UI production consumers must not invent second LIO gateway', () {
    final offenders = <String>[];
    for (final f in dartFilesUnder(libRoot)) {
      final path = norm(f.path);
      if (path.contains('/orchestrator/lio_gateway.dart')) continue;
      if (path.contains('lifex_production_composition.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('ProductionLioGateway(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
