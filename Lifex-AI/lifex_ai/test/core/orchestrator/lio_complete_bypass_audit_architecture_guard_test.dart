import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/core/orchestrator/clock.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway_contracts.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_entry_inventory.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/features/ai/ai_bridge.dart';
import 'package:lifex_ai/features/ai/ai_engine.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/ai/doctor_guidance_engine.dart';
import 'package:lifex_ai/features/ai/health_analysis_engine.dart';
import 'package:lifex_ai/features/ai/health_decision_engine.dart';
import 'package:lifex_ai/features/ai/unified_ai_hub_gateway.dart';

/// حراسة شاملة: إغلاق bypass لمسارات Production الحساسة عبر LIO.
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

  bool isAllowedAgentInternal(String path) {
    return path.contains('/core/agent/') ||
        path.endsWith('lio_sensitive_action_entry.dart');
  }

  bool isAllowedMcpConstruction(String path) {
    return path.endsWith('mcp_live_gateway.dart') ||
        path.endsWith('lifex_intelligence_fabric.dart') ||
        path.endsWith('lifex_production_composition.dart') ||
        path.contains('/ci_evidence/');
  }

  bool isAllowedToolExecute(String path) {
    return path.endsWith('agent_tool_registry.dart') ||
        path.endsWith('agent_executor.dart');
  }

  bool isAiProviderDefinition(String path) {
    return path.contains('/features/ai/') ||
        path.endsWith('agent_model_client.dart') ||
        path.endsWith('lio_sensitive_action_entry.dart') ||
        path.endsWith('main.dart') ||
        path.endsWith('agent_core.dart') ||
        path.endsWith('lifex_production_composition.dart') ||
        path.endsWith('lifex_app_context.dart');
  }

  group('A inventory — every known sensitive entry must pass LIO', () {
    test('inventory entries all require LIO and document legal path', () {
      const inventory = LioSensitiveEntryInventory();
      expect(inventory.productionEntries, isNotEmpty);
      for (final e in inventory.productionEntries) {
        expect(e.mustPassLio, isTrue, reason: e.path);
        expect(e.legalPathNote, isNotEmpty);
        expect(File(e.path).existsSync(), isTrue, reason: e.path);
      }
      expect(
        LioSensitiveEntryInventory.legalFlow,
        containsAll([
          'LioSensitiveActionEntry',
          'ProductionLioGateway',
          'MCP/Agent/Tool',
          'Audit',
        ]),
      );
    });

    test('UI sensitive screens call entry methods, not Agent/Router/Hub', () {
      final agent = File('lib/screens/ai_agent_screen.dart').readAsStringSync();
      expect(agent.contains('LioSensitiveActionEntry'), isTrue);
      expect(agent.contains('runAgentRequest'), isTrue);
      expect(agent.contains('runAiChatQuery'), isTrue);
      expect(agent.contains('coordinator.handleUserRequest'), isFalse);
      expect(agent.contains('AiServiceRouter'), isFalse);
      expect(agent.contains('AgentCoreBundle'), isFalse);

      final hub = File('lib/screens/ai_hub_screen.dart').readAsStringSync();
      expect(hub.contains('LioSensitiveActionEntry'), isTrue);
      expect(hub.contains('connectExternalAiAccount'), isTrue);
      expect(hub.contains('disconnectExternalAiAccount'), isTrue);
      expect(hub.contains('listConnectedAiAccounts'), isTrue);
      expect(hub.contains('Provider.of<UnifiedAiHubGateway>'), isFalse);
      expect(hub.contains('Provider.of<AiServiceRouter>'), isFalse);
      expect(RegExp(r'\.connectAccount\(').hasMatch(hub), isFalse);
    });
  });

  group('B UI → Agent bypass must fail architecture guard', () {
    test('screens must not call Agent coordinator or AgentCore', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        final path = norm(f.path);
        if (text.contains('coordinator.handleUserRequest') ||
            text.contains('AgentCore.initialize') ||
            text.contains('Provider.of<AgentCoreBundle>') ||
            RegExp(r'context\.read<\s*AgentCoreBundle\s*>').hasMatch(text)) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('C UI → MCP bypass must fail', () {
    test('screens must not construct or call MCP Live Gateway', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (text.contains('LifexMcpLiveGateway') ||
            text.contains('attachLiveMcpGateway(')) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('D Application → Tool bypass must fail', () {
    test('executeTool only inside Agent tool stack', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        // Call sites: .executeTool( — not inventory string mentions.
        if (!RegExp(r'\.executeTool\s*\(').hasMatch(text)) continue;
        if (isAllowedToolExecute(path)) continue;
        offenders.add(path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('E Application → Agent bypass must fail', () {
    test('handleUserRequest only via SensitiveActionEntry or Agent internals', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        // Call sites only — ignore inventory / docs mentioning the symbol.
        if (!RegExp(r'\.handleUserRequest\s*\(').hasMatch(text) &&
            !RegExp(r'handleUserRequest\s*\(\s*\{').hasMatch(text)) {
          continue;
        }
        if (isAllowedAgentInternal(path)) continue;
        if (path.contains('/screens/') ||
            path.contains('/features/') ||
            path.contains('/services/') ||
            path.contains('/data/')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('F Application → MCP bypass must fail', () {
    test('LifexMcpLiveGateway construction only at Fabric/Composition boundary', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        if (!RegExp(r'LifexMcpLiveGateway\s*\(').hasMatch(text)) continue;
        if (isAllowedMcpConstruction(path)) continue;
        if (path.endsWith('lio_sensitive_entry_inventory.dart')) continue;
        offenders.add(path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('G no second ProductionLioGateway', () {
    test('single class and single construction site outside definition', () {
      final classHits = <String>[];
      final ctorHits = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        if (text.contains('class ProductionLioGateway')) {
          classHits.add(path);
        }
        if (RegExp(r'ProductionLioGateway\s*\(').hasMatch(text) &&
            !path.endsWith('lio_gateway.dart') &&
            !path.endsWith('lifex_production_composition.dart') &&
            !path.endsWith('lio_sensitive_entry_inventory.dart')) {
          ctorHits.add(path);
        }
      }
      expect(classHits, hasLength(1));
      expect(ctorHits, isEmpty, reason: ctorHits.join('\n'));
      expect(ProductionLioGateway.gatewayId, 'ProductionLioGateway');
    });
  });

  group('H no second Production Fabric', () {
    test('forProduction only in Composition Root', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        if (!text.contains('LifexIntelligenceFabric.forProduction')) continue;
        if (path.endsWith('lifex_production_composition.dart')) continue;
        if (path.endsWith('lifex_intelligence_fabric.dart')) continue;
        offenders.add(path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('I no second ProductionKnowledgeComposition', () {
    test('createRetriever only in Composition Root', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        if (!text.contains('ProductionKnowledgeComposition.createRetriever')) {
          continue;
        }
        if (path.endsWith('lifex_production_composition.dart')) continue;
        if (path.endsWith('production_knowledge_composition.dart')) continue;
        offenders.add(path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('J every LIO decision produces Audit', () {
    late FixedClock clock;
    late LioSensitiveActionEntry entry;

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 9, 21, 16, 0, 0));
      final corpus = InMemoryKnowledgeCorpus([
        KnowledgeRecord(
          id: '1',
          title: 'fluid',
          body: 'Hydration fluid guidance',
          terms: const ['hydration', 'fluid'],
          provenance: LioSourceProvenance(
            sourceId: 's1',
            sourceType: 'test',
            authority: LioSourceAuthority.documentation,
            retrievedAt: DateTime(2026, 9, 20),
            document: 'd1',
            evidenceLevel: 0.7,
            confidence: 0.7,
          ),
        ),
      ]);
      final analysis = HealthAnalysisEngine(
        symptomKeywordMap: const {},
        emergencySymptomIds: const {},
      );
      final guidance = DoctorGuidanceEngine(symptomBodySystemMap: const {});
      final bundle = LifexProductionComposition.assemble(
        medicalDatabaseManager: _FakeDb(),
        aiModuleBundle: AiModuleBundle(
          engine: AiEngine.instance,
          analysisEngine: analysis,
          guidanceEngine: guidance,
          decisionEngine: HealthDecisionEngine(
            analysisEngine: analysis,
            guidanceEngine: guidance,
          ),
        ),
        aiServiceRouter: AiServiceRouter(
          hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
        ),
        knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
        corpus: corpus,
        clock: clock,
      );
      entry = bundle.sensitiveActionEntry;
    });

    LioGatewayRequest req({
      required String id,
      bool authorized = true,
      bool emergency = false,
      LioActionRisk risk = LioActionRisk.low,
    }) {
      return LioGatewayRequest(
        requestId: id,
        correlationId: 'c',
        identityAccountId: 'a',
        purpose: emergency ? 'emergency_signal' : 'knowledge_lookup',
        requestedAction: emergency ? 'signal_trusted_contacts' : 'agent_user_request',
        dataScope: emergency ? 'emergency_contacts_min' : 'knowledge_public',
        sensitivity: LioDataSensitivity.public,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: risk,
        timestamp: DateTime.utc(2026, 1, 1),
        authenticated: true,
        authorized: authorized,
        emergencyLimitedMode: emergency,
        minimumNecessarySatisfied: true,
      );
    }

    test('allow and deny both write audit events', () async {
      entry.lioGateway.auditLog.clear();
      await entry.authorizeThenRun(request: req(id: 'j1'), run: () async => 1);
      await entry.authorizeThenRun(
        request: req(id: 'j2', authorized: false),
        run: () async => 1,
      );
      expect(entry.lioGateway.auditLog.events.length, 2);
      expect(
        entry.lioGateway.auditLog.events.map((e) => e.requestId).toSet(),
        {'j1', 'j2'},
      );
    });

    test('K Emergency remains EMERGENCY_LIMITED per current policy', () async {
      final outcome = await entry.authorizeThenRun(
        request: req(id: 'k1', emergency: true, risk: LioActionRisk.high),
        run: () async => 'ok',
      );
      expect(outcome.decision.kind, LioGatewayDecisionKind.emergencyLimited);
      expect(outcome.executed, isTrue);
      expect(
        entry.lioGateway.auditLog.events.any((e) => e.requestId == 'k1'),
        isTrue,
      );
    });
  });

  group('extra guards — UI providers / sole entry / repository', () {
    test('main must not expose Agent/MCP/Tool/AI providers to UI tree', () {
      final text = File('lib/main.dart').readAsStringSync();
      for (final forbidden in LioSensitiveEntryInventory.mainForbiddenUiProviders) {
        expect(text.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(text.contains('Provider<LioSensitiveActionEntry>'), isTrue);
    });

    test('screens must not Provider.of forbidden Agent/MCP/AI types', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        for (final t in LioSensitiveEntryInventory.uiForbiddenProviderTypes) {
          if (RegExp('Provider\\.of<\\s*$t\\s*>').hasMatch(text) ||
              RegExp('context\\.read<\\s*$t\\s*>').hasMatch(text) ||
              RegExp('context\\.watch<\\s*$t\\s*>').hasMatch(text)) {
            offenders.add('${norm(f.path)} → $t');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('sole Application sensitive entry class is LioSensitiveActionEntry', () {
      expect(
        LioSensitiveEntryInventory.soleApplicationEntry,
        LioSensitiveActionEntry.entryId,
      );
      final entryFiles = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'class\s+\w*SensitiveActionEntry\b').hasMatch(text)) {
          entryFiles.add(norm(f.path));
        }
      }
      expect(entryFiles, hasLength(1));
      expect(entryFiles.single, contains('lio_sensitive_action_entry.dart'));
    });

    test('repositories/data must not call Agent/MCP/Tool', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/data'))) {
        final text = f.readAsStringSync();
        final path = norm(f.path);
        if (text.contains('handleUserRequest') ||
            text.contains('LifexMcpLiveGateway') ||
            text.contains('executeTool(') ||
            text.contains('AgentCore.initialize')) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('UI must not call AiServiceRouter.query / Hub connect directly', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final path = norm(f.path);
        final text = f.readAsStringSync();
        if (isAiProviderDefinition(path)) continue;
        if (text.contains('aiServiceRouter.query') ||
            text.contains('AiServiceRouter') ||
            RegExp(r'\.connectAccount\(').hasMatch(text) ||
            RegExp(r'\.disconnectAccount\(').hasMatch(text)) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no Fake/Stub LIO/Agent doubles in lib/', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final text = f.readAsStringSync();
        if (RegExp(
          r'class\s+(Fake|Stub)\w*(LioGateway|AgentCore|SensitiveAction)\b',
        ).hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('agent request path still audits via entry', () async {
      final clock = FixedClock(DateTime.utc(2026, 9, 21, 16, 30, 0));
      final corpus = InMemoryKnowledgeCorpus(const []);
      final analysis = HealthAnalysisEngine(
        symptomKeywordMap: const {},
        emergencySymptomIds: const {},
      );
      final guidance = DoctorGuidanceEngine(symptomBodySystemMap: const {});
      final bundle = LifexProductionComposition.assemble(
        medicalDatabaseManager: _FakeDb(),
        aiModuleBundle: AiModuleBundle(
          engine: AiEngine.instance,
          analysisEngine: analysis,
          guidanceEngine: guidance,
          decisionEngine: HealthDecisionEngine(
            analysisEngine: analysis,
            guidanceEngine: guidance,
          ),
        ),
        aiServiceRouter: AiServiceRouter(
          hubGateway: UnifiedAiHubGateway(credentialStore: _MemCreds()),
        ),
        knowledgeEngine: LifexKnowledgeEngine(corpus: corpus),
        corpus: corpus,
        clock: clock,
      );
      final entry = bundle.sensitiveActionEntry;
      entry.lioGateway.auditLog.clear();
      await entry.runAgentRequest(
        gatewayRequest: LioGatewayRequest(
          requestId: 'agent-audit',
          correlationId: 'c',
          identityAccountId: 'a',
          purpose: 'knowledge_lookup',
          requestedAction: 'agent_user_request',
          dataScope: 'knowledge_public',
          sensitivity: LioDataSensitivity.public,
          consent: const LioConsentContext(
            consentGranted: true,
            purposeAligned: true,
          ),
          riskLevel: LioActionRisk.low,
          timestamp: DateTime.utc(2026, 1, 1),
          authenticated: true,
          authorized: true,
          minimumNecessarySatisfied: true,
        ),
        agentContext: AgentContext(
          taskId: 't',
          profileId: 'p',
          userRequest: 'help',
          permissions: const AgentGrantedPermissions(
            granted: {AgentPermission.readKnowledgeBase},
          ),
        ),
        sessionId: 's',
      );
      expect(
        entry.lioGateway.auditLog.events.any((e) => e.requestId == 'agent-audit'),
        isTrue,
      );
    });
  });
}

class _FakeDb implements MedicalDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MemCreds implements SecureCredentialStore {
  final Map<String, String> _m = {};
  @override
  Future<void> saveCredential(String key, String value) async => _m[key] = value;
  @override
  Future<String?> readCredential(String key) async => _m[key];
  @override
  Future<void> deleteCredential(String key) async => _m.remove(key);
}
