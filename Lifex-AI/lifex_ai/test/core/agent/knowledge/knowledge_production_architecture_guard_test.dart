import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/knowledge/medical_bundle_corpus_seeder.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
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

  test('Production lib must not import test/support doubles', () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (text.contains('test/support/') ||
          text.contains('knowledge_retriever_test_doubles')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Production lib must not define Stub/Fake KnowledgeRetriever', () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libRoot)) {
      final text = f.readAsStringSync();
      if (RegExp(r'class\s+(Fake|Stub)\w*KnowledgeRetriever\b')
          .hasMatch(text)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Agent Knowledge production has no legacy scoring loop', () {
    final retrieverFile = File(
      'lib/core/agent/knowledge/knowledge_retriever.dart',
    );
    final text = retrieverFile.readAsStringSync();
    expect(text.contains('scored.sort'), isFalse);
    expect(text.contains('engineAvailable'), isFalse);
    expect(text.contains('KnowledgeEngineBridgedRetriever'), isTrue);
    expect(text.contains('AgentKnowledgeBridge'), isTrue);
    expect(text.contains('_engine.retrieve'), isTrue);
  });

  test('Seeder has seedInto only — not a search engine', () {
    final seederFile = File(
      'lib/core/agent/knowledge/medical_bundle_corpus_seeder.dart',
    );
    final text = seederFile.readAsStringSync();
    expect(text.contains('seedInto'), isTrue);
    expect(RegExp(r'Future<.*>\s+retrieve\s*\(').hasMatch(text), isFalse);
    expect(text.contains('ليس محرك استرجاع') || text.contains('بلا بحث'), isTrue);
    // API surface
    expect(
      const MedicalBundleCorpusSeeder().toString(),
      contains('MedicalBundleCorpusSeeder'),
    );
  });

  test('Agent consumers do not import corpus for direct search', () {
    final consumers = [
      'lib/core/agent/agents/knowledge_agent.dart',
      'lib/core/agent/tools/knowledge_search_tool.dart',
      'lib/core/agent/agent_orchestrator.dart',
      'lib/core/agent/agent_core.dart',
    ];
    for (final path in consumers) {
      final text = File(path).readAsStringSync();
      expect(
        text.contains('retrieval_adapters.dart'),
        isFalse,
        reason: '$path must not search corpus directly',
      );
      expect(text.contains('InMemoryKnowledgeCorpus'), isFalse);
    }
  });

  test('LLM is not Source of Truth', () {
    const canon = LifexLioCanon();
    const safety = KnowledgeEngineSafety();
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
    expect(safety.llmIsSourceOfTruth, isFalse);
  });

  test('AgentCore production requires injected production KnowledgeRetriever',
      () {
    final text = File('lib/core/agent/agent_core.dart').readAsStringSync();
    expect(text.contains('required KnowledgeRetriever knowledgeRetriever'), isTrue);
    expect(text.contains('ProductionKnowledgeComposition.createRetriever'), isFalse);
    expect(text.contains('FakeKnowledgeRetriever'), isFalse);
    expect(text.contains('StubKnowledgeRetriever'), isFalse);
  });
}
