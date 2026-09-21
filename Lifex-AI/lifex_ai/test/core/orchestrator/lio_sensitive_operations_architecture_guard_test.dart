import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_operation_inventory.dart';

/// حراسة معمارية للعمليات الحساسة غير AI/Agent/MCP.
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

  group('inventory', () {
    test('every sensitive op requires LIO and files exist', () {
      const inv = LioSensitiveOperationInventory();
      expect(inv.productionEntries, isNotEmpty);
      for (final e in inv.productionEntries) {
        expect(e.mustPassLio, isTrue, reason: e.path);
        expect(File(e.path).existsSync(), isTrue, reason: e.path);
      }
      expect(
        LioSensitiveOperationInventory.legalFlow,
        containsAll([
          'LioSensitiveActionEntry',
          'ProductionLioGateway',
          'Application operation',
          'Audit',
        ]),
      );
    });
  });

  group('A UI → sensitive Repository bypass', () {
    test('screens must not Provider.of MedicalDatabaseManager', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'Provider\.of<\s*MedicalDatabaseManager\s*>')
                .hasMatch(text) ||
            RegExp(r'context\.read<\s*MedicalDatabaseManager\s*>')
                .hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('B UI → Database bypass', () {
    test('screens must not call readBundleFile/downloadAndUpdateBundle', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'readBundleFile\s*\(').hasMatch(text) ||
            RegExp(r'downloadAndUpdateBundle\s*\(').hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('C UI → Export bypass', () {
    test('screens must not invoke export without Entry', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        // Direct Share/export bridges without Entry.
        if (text.contains('EncyclopediaShareBridge()') &&
            text.contains('shareEncyclopedia')) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('D UI → Share bypass', () {
    test('share UI uses LioSensitiveActionEntry', () {
      final text =
          File('lib/widgets/encyclopedia_share_bar.dart').readAsStringSync();
      expect(text.contains('LioSensitiveActionEntry'), isTrue);
      expect(text.contains('sharePublicEncyclopedia'), isTrue);
      expect(text.contains('EncyclopediaShareBridge()'), isFalse);
    });
  });

  group('E UI → Delete bypass', () {
    test('screens must not call MedicalDatabaseManager delete paths', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (text.contains('MedicalDatabaseManager') &&
            RegExp(r'\.delete\w*\s*\(').hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('F UI → Download/Print bypass', () {
    test('settings medical download goes through Entry', () {
      final text = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(text.contains('refreshMedicalKnowledge'), isTrue);
      expect(text.contains('Provider.of<MedicalDatabaseManager>'), isFalse);
      expect(text.contains('SearchRefreshEngine'), isFalse);
    });
  });

  group('G Application → sensitive Repository bypass', () {
    test('wallet/emergency UI uses Entry not managers', () {
      for (final path in [
        'lib/screens/wallet_screen.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/voice_control_screen.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text.contains('LioSensitiveActionEntry'), isTrue, reason: path);
        expect(text.contains('Provider.of<WalletManager>'), isFalse,
            reason: path);
        expect(text.contains('context.read<EmergencyManager>'), isFalse,
            reason: path);
        expect(text.contains('Provider.of<EmergencyManager>'), isFalse,
            reason: path);
      }
    });
  });

  group('H Application → Database bypass', () {
    test('Entry does not embed SQL/sqflite', () {
      final text = File(
        'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      ).readAsStringSync();
      expect(text.contains('sqflite'), isFalse);
      expect(text.contains('SELECT '), isFalse);
      expect(text.contains('MedicalDatabaseManager('), isFalse);
    });
  });

  group('I Application → sensitive operation bypass', () {
    test('UI forbidden provider types absent from screens', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        for (final t in LioSensitiveOperationInventory.uiForbiddenProviderTypes) {
          if (RegExp('Provider\\.of<\\s*$t\\s*>').hasMatch(text) ||
              RegExp('context\\.read<\\s*$t\\s*>').hasMatch(text) ||
              RegExp('context\\.watch<\\s*$t\\s*>').hasMatch(text)) {
            offenders.add('${norm(f.path)} → $t');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('J Repository → sensitive external operation bypass', () {
    test('data layer must not construct ProductionLioGateway', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/data'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'ProductionLioGateway\s*\(').hasMatch(text) ||
            RegExp(r'LioSensitiveActionEntry\s*\(').hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('K no second ProductionLioGateway', () {
    test('single class definition', () {
      final hits = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        if (f.readAsStringSync().contains('class ProductionLioGateway')) {
          hits.add(norm(f.path));
        }
      }
      expect(hits, hasLength(1));
      expect(ProductionLioGateway.gatewayId, 'ProductionLioGateway');
    });
  });

  group('L no second LioSensitiveActionEntry', () {
    test('single entry class', () {
      final hits = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        if (RegExp(r'class\s+LioSensitiveActionEntry\b')
            .hasMatch(f.readAsStringSync())) {
          hits.add(norm(f.path));
        }
      }
      expect(hits, hasLength(1));
      expect(LioSensitiveActionEntry.entryId, 'LioSensitiveActionEntry');
    });
  });

  group('M no second Production Fabric', () {
    test('forProduction only in composition/fabric', () {
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

  group('N no second ProductionKnowledgeComposition', () {
    test('createRetriever only in composition', () {
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

  group('O Fake/Stub inside lib/', () {
    test('no Fake/Stub LIO/Entry doubles in lib', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final text = f.readAsStringSync();
        if (RegExp(
          r'class\s+(Fake|Stub)\w*(LioGateway|SensitiveAction|Wallet|Emergency)\b',
        ).hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  test('AppContext binds application ops without second gateway', () {
    final text = File('lib/core/lio/lifex_app_context.dart').readAsStringSync();
    expect(text.contains('bindApplicationOps'), isTrue);
    expect(text.contains('ProductionLioGateway('), isFalse);
    expect(text.contains('LioSensitiveActionEntry('), isFalse);
  });
}
