import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/file_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/in_memory_health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/persistent_health_observation_repository.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';

/// حراسة مسار HealthObservation persistent.
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

  group('UI → Repository/DB', () {
    test('screens must not touch HealthObservation repositories/stores', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(
          r'HealthObservationRepository|PersistentHealthObservationRepository|'
          r'InMemoryHealthObservationRepository|FileHealthObservationStore|'
          r'InMemoryHealthRepository\s*\(',
        ).hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Agent → Repository/DB', () {
    test('agent must not construct health observation stores', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/core/agent'))) {
        final t = f.readAsStringSync();
        if (RegExp(
          r'PersistentHealthObservationRepository|FileHealthObservationStore|'
          r'InMemoryHealthObservationRepository',
        ).hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('LIO → Repository/DB', () {
    test('gateway does not own or open health observation store', () {
      final gw = File('lib/core/orchestrator/lio_gateway.dart').readAsStringSync();
      expect(gw.contains('HealthObservationRepository'), isFalse);
      expect(gw.contains('FileHealthObservationStore'), isFalse);
      expect(gw.contains('saveObservation'), isFalse);
      expect(gw.contains('sqflite'), isFalse);
    });
  });

  group('duplicate owner', () {
    test('single PersistentHealthObservationRepository class + owner id', () {
      final hits = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        if (f.readAsStringSync().contains(
              'class PersistentHealthObservationRepository',
            )) {
          hits.add(norm(f.path));
        }
      }
      expect(hits, hasLength(1));
      expect(
        HealthObservationRepository.ownerId,
        'HealthObservationRepository',
      );
      expect(
        PersistentHealthObservationRepository.implementationId,
        'PersistentHealthObservationRepository',
      );
      expect(FileHealthObservationStore.storeName, 'FileHealthObservationStore');
    });
  });

  group('production forbids InMemory', () {
    test('composition source wires Persistent not InMemory', () {
      final text = File(
        'lib/core/lio/lifex_production_composition.dart',
      ).readAsStringSync();
      expect(text.contains('PersistentHealthObservationRepository'), isTrue);
      expect(text.contains('EncryptedHealthObservationStore'), isTrue);
      expect(text.contains('FileHealthObservationStore'), isTrue);
      expect(
        text.contains('InMemoryHealthObservationRepository('),
        isFalse,
      );
      expect(
        text.contains('InMemoryHealthRepository('),
        isFalse,
      );
      expect(
        RegExp(r'healthObservationStore\s*\?\?\s*FileHealthObservationStore\s*\(')
            .hasMatch(text),
        isFalse,
      );
    });

    test('AppContext does not create InMemory health observation owner', () {
      final text =
          File('lib/core/lio/lifex_app_context.dart').readAsStringSync();
      expect(text.contains('InMemoryHealthRepository('), isFalse);
      expect(text.contains('InMemoryHealthObservationRepository('), isFalse);
      expect(
        text.contains('production.healthObservationRepository'),
        isTrue,
      );
    });
  });

  group('Fake/Stub in lib/', () {
    test('no Fake/Stub health observation doubles in lib', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final t = f.readAsStringSync();
        if (RegExp(
          r'class\s+(Fake|Stub)\w*(HealthObservation|HealthRepository)\b',
        ).hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('LLM not SoT', () {
    test('AI modules must not implement HealthObservationRepository', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/features/ai'))) {
        final t = f.readAsStringSync();
        if (t.contains('implements HealthObservationRepository') ||
            t.contains('extends PersistentHealthObservationRepository')) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      expect(
        InMemoryHealthObservationRepository.testOnlyMarker,
        contains('TEST_ONLY'),
      );
      expect(
        LifexProductionComposition.compositionRootId,
        'LifexProductionComposition',
      );
    });
  });
}
