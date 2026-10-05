import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';

void main() {
  final libRoot = Directory('lib');

  List<File> _dartFilesUnder(Directory dir) {
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String _norm(String p) => p.replaceAll('\\', '/');

  test('Only LifexProductionComposition is the Agent Knowledge production root',
      () {
    final roots = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (text.contains('class LifexProductionComposition')) {
        roots.add(_norm(f.path));
      }
    }
    expect(roots, hasLength(1));
    expect(roots.single, contains('lifex_production_composition.dart'));
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
  });

  test('AgentCore production does not create its own KnowledgeRetriever', () {
    final text = File('lib/core/agent/agent_core.dart').readAsStringSync();
    expect(text.contains('ProductionKnowledgeComposition.createRetriever'), isFalse);
    expect(text.contains('required KnowledgeRetriever knowledgeRetriever'), isTrue);
    expect(text.contains('isProductionKnowledgePath'), isTrue);
    expect(text.contains('FakeKnowledgeRetriever'), isFalse);
    expect(text.contains('StubKnowledgeRetriever'), isFalse);
  });

  test('KnowledgeRetriever.production only from ProductionKnowledgeComposition',
      () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final path = _norm(f.path);
      if (path.endsWith('production_knowledge_composition.dart')) continue;
      if (path.endsWith('knowledge_retriever.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('KnowledgeRetriever.production(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('main wires LifexProductionComposition (not raw AgentCore alone)', () {
    final text = File('lib/main.dart').readAsStringSync();
    expect(text.contains('LifexProductionComposition.assemble'), isTrue);
    expect(RegExp(r'AgentCore\.initialize\s*\(').hasMatch(text), isFalse);
  });

  test('No Fake/Stub KnowledgeRetriever classes in lib/', () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (RegExp(r'class\s+(Fake|Stub)\w*KnowledgeRetriever\b').hasMatch(text)) {
        offenders.add(_norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Agent consumers do not bypass Bridge via corpus/engine imports', () {
    final consumers = [
      'lib/core/agent/agents/knowledge_agent.dart',
      'lib/core/agent/tools/knowledge_search_tool.dart',
      'lib/core/agent/agent_orchestrator.dart',
      'lib/core/agent/agent_core.dart',
    ];
    for (final path in consumers) {
      final text = File(path).readAsStringSync();
      expect(text.contains('InMemoryKnowledgeCorpus'), isFalse, reason: path);
      expect(text.contains('LifexKnowledgeEngine('), isFalse, reason: path);
      expect(text.contains('scored.sort'), isFalse, reason: path);
      expect(text.contains('engineAvailable'), isFalse, reason: path);
    }
  });

  test('Production lib must not import test/support doubles', () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (text.contains('test/support/') ||
          text.contains('knowledge_retriever_test_doubles')) {
        offenders.add(_norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('No production Stub fallback markers in Agent Knowledge path', () {
    final files = [
      'lib/core/lio/lifex_production_composition.dart',
      'lib/core/agent/knowledge/production_knowledge_composition.dart',
      'lib/core/agent/knowledge/knowledge_retriever.dart',
      'lib/core/agent/agent_core.dart',
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      expect(text.contains('FakeKnowledgeRetriever'), isFalse, reason: path);
      expect(text.contains('StubKnowledgeRetriever'), isFalse, reason: path);
      expect(text.contains('engineAvailable'), isFalse, reason: path);
    }
  });

  test('LLM is not Source of Truth', () {
    const canon = LifexLioCanon();
    const safety = KnowledgeEngineSafety();
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
    expect(safety.llmIsSourceOfTruth, isFalse);
  });
}
