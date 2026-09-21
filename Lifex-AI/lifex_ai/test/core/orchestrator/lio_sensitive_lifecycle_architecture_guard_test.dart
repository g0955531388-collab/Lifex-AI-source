import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/orchestrator/lio_gateway.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_action_entry.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_lifecycle_contracts.dart';
import 'package:lifex_ai/core/orchestrator/lio_sensitive_lifecycle_inventory.dart';

/// حراسة دورة حياة البيانات الحساسة A–S.
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
    test('lifecycle inventory requires LIO and documents ownership', () {
      const inv = LioSensitiveLifecycleInventory();
      expect(inv.productionEntries, isNotEmpty);
      for (final e in inv.productionEntries) {
        expect(e.passesLioEntry, isTrue, reason: e.path);
        expect(e.canonicalOwner, isNotEmpty);
        expect(File(e.path).existsSync(), isTrue, reason: e.path);
      }
      expect(
        LioSensitiveLifecycleInventory.legalFlow,
        containsAll(['LioSensitiveActionEntry', 'Audit']),
      );
    });
  });

  group('A UI→Repository sensitive', () {
    test('screens must not Provider HealthRepository', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'Provider\.of<\s*HealthRepository\s*>').hasMatch(text) ||
            RegExp(r'context\.read<\s*HealthRepository\s*>').hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('B UI→Database', () {
    test('screens must not Provider MedicalDatabaseManager', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final text = f.readAsStringSync();
        if (RegExp(r'Provider\.of<\s*MedicalDatabaseManager\s*>')
                .hasMatch(text) ||
            RegExp(r'readBundleFile\s*\(').hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('C UI→DELETE', () {
    test('appointment delete uses Entry; no raw removeOrCancel without Entry', () {
      final text = File('lib/screens/appointments_screen.dart').readAsStringSync();
      expect(text.contains('LioSensitiveActionEntry'), isTrue);
      expect(text.contains('authorizeThenRun'), isTrue);
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (t.contains('removeOrCancel(') &&
            !t.contains('LioSensitiveActionEntry')) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('D UI→ARCHIVE', () {
    test('screens must not invent archive engines', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(r'archivePhr\s*\(|archiveClinical\s*\(').hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('E UI→EXPORT', () {
    test('screens must not call clinical/PHR export engines', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(r'exportPhr\s*\(|exportClinical\s*\(|exportPatient\s*\(')
            .hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('F UI→SHARE', () {
    test('share widget uses Entry; no direct ShareBridge bypass', () {
      final text =
          File('lib/widgets/encyclopedia_share_bar.dart').readAsStringSync();
      expect(text.contains('sharePublicEncyclopedia'), isTrue);
      expect(text.contains('EncyclopediaShareBridge()'), isFalse);
    });
  });

  group('G UI→PRINT', () {
    test('screens must not invoke print pipelines for PHR', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(r'Printing\.|printDocument\s*\(|printPhr\s*\(').hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('H UI→DOWNLOAD', () {
    test('settings download goes through Entry', () {
      final text = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(text.contains('refreshMedicalKnowledge'), isTrue);
      expect(text.contains('downloadAndUpdateBundle'), isFalse);
    });
  });

  group('I UI→Device CONTROL', () {
    test('screens must not construct DeviceControlCenter or drive control', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (t.contains('DeviceControlCenter(') ||
            RegExp(r'\.executeControl\s*\(').hasMatch(t) ||
            RegExp(r'context\.read<\s*DeviceControlCenter\s*>').hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('J Application→Database', () {
    test('Entry does not embed SQL', () {
      final text = File(
        'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      ).readAsStringSync();
      expect(text.contains('sqflite'), isFalse);
      expect(text.contains('SELECT '), isFalse);
    });
  });

  group('K Application→sensitive external execution', () {
    test('Entry clinical export returns non-success contract', () {
      final text = File(
        'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      ).readAsStringSync();
      expect(text.contains('requestClinicalPhrExport'), isTrue);
      expect(text.contains('LioLifecycleResult.notImplemented'), isTrue);
      expect(text.contains('requestDeviceControl'), isTrue);
      expect(text.contains('LioLifecycleResult.unsupported'), isTrue);
    });
  });

  group('L Repository→external sensitive execution bypass', () {
    test('data layer must not construct Gateway/Entry', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/data'))) {
        final t = f.readAsStringSync();
        if (RegExp(r'ProductionLioGateway\s*\(').hasMatch(t) ||
            RegExp(r'LioSensitiveActionEntry\s*\(').hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('M Clinical/PHR export bypass', () {
    test('DELETE ≠ ARCHIVE and EXPORT ≠ SHARE in contracts', () {
      expect(LioLifecycleOpKind.delete != LioLifecycleOpKind.archive, isTrue);
      expect(LioLifecycleOpKind.export != LioLifecycleOpKind.share, isTrue);
      final text = File(
        'lib/core/orchestrator/lio_sensitive_lifecycle_contracts.dart',
      ).readAsStringSync();
      expect(text.contains('notImplemented'), isTrue);
      expect(text.contains('unsupportedOperation'), isTrue);
    });
  });

  group('N Emergency bypass', () {
    test('UI emergency uses Entry limited path', () {
      for (final path in [
        'lib/screens/home_screen.dart',
        'lib/screens/voice_control_screen.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text.contains('triggerEmergencyLimited'), isTrue, reason: path);
        expect(text.contains('context.read<EmergencyManager>'), isFalse,
            reason: path);
      }
    });
  });

  group('O second ProductionLioGateway', () {
    test('single class', () {
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

  group('P second LioSensitiveActionEntry', () {
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

  group('Q second Production Fabric', () {
    test('forProduction only composition/fabric', () {
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

  group('R second ProductionKnowledgeComposition', () {
    test('createRetriever only composition', () {
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

  group('S Fake/Stub inside lib/', () {
    test('no Fake/Stub lifecycle doubles', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final text = f.readAsStringSync();
        if (RegExp(
          r'class\s+(Fake|Stub)\w*(Lifecycle|LioGateway|SensitiveAction)\b',
        ).hasMatch(text)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
