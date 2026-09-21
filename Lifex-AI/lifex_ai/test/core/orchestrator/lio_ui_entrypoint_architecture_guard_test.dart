import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';

void main() {
  List<File> dartFiles(Directory dir) {
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String norm(String p) => p.replaceAll('\\', '/');

  test('UI/Presentation must not call Agent coordinator directly', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib/screens'))) {
      final text = f.readAsStringSync();
      if (text.contains('coordinator.handleUserRequest') ||
          text.contains('.coordinator.handleUserRequest')) {
        offenders.add(norm(f.path));
      }
      if (RegExp(r'Provider\.of<\s*AgentCoreBundle\s*>').hasMatch(text) &&
          text.contains('handleUserRequest')) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('UI/Presentation must not construct or call MCP Live Gateway', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib/screens'))) {
      final text = f.readAsStringSync();
      if (text.contains('LifexMcpLiveGateway(') ||
          text.contains('attachLiveMcpGateway(')) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('UI must use LioSensitiveActionEntry for sensitive agent/chat', () {
    final text = File('lib/screens/ai_agent_screen.dart').readAsStringSync();
    expect(text.contains('LioSensitiveActionEntry'), isTrue);
    expect(text.contains('authorizeThenRun'), isTrue);
    expect(text.contains('runAgentRequest'), isTrue);
    expect(text.contains('coordinator.handleUserRequest'), isFalse);
  });

  test('Application entry does not create a second ProductionLioGateway', () {
    final text = File(
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    ).readAsStringSync();
    expect(text.contains('ProductionLioGateway('), isFalse);
    expect(text.contains('LioSensitiveActionEntry'), isTrue);
    expect(LioSensitiveActionEntry.entryId, 'LioSensitiveActionEntry');
  });

  test('ProductionLioGateway only constructed in Composition Root', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final path = norm(f.path);
      if (path.endsWith('lio_gateway.dart')) continue;
      if (path.endsWith('lifex_production_composition.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('ProductionLioGateway(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('No second Fabric/AgentCore/ProductionKnowledge in screens', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      final text = f.readAsStringSync();
      expect(text.contains('LifexIntelligenceFabric.forProduction'), isFalse);
      expect(text.contains('AgentCore.initialize'), isFalse);
      expect(
        text.contains('ProductionKnowledgeComposition.createRetriever'),
        isFalse,
      );
    }
  });

  test('Composition wires sensitiveActionEntry to same gateway/agentCore', () {
    final text =
        File('lib/core/lio/lifex_production_composition.dart').readAsStringSync();
    expect(text.contains('LioSensitiveActionEntry('), isTrue);
    expect(text.contains('sensitiveActionEntry'), isTrue);
  });
}
