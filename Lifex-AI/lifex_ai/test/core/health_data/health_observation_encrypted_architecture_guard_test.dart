import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/in_memory_health_observation_repository.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/security/memory_secure_secret_store.dart';

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
    test('screens must not touch encrypted health stores', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib/screens'))) {
        final t = f.readAsStringSync();
        if (RegExp(
          r'EncryptedHealthObservationStore|HealthObservationKeyVault|'
          r'PersistentHealthObservationRepository|FileHealthObservationStore',
        ).hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Agent / LIO → Repository/DB', () {
    test('agent and gateway do not open health encryption store', () {
      for (final path in [
        'lib/core/agent',
        'lib/core/orchestrator/lio_gateway.dart',
      ]) {
        final files = path.endsWith('.dart')
            ? [File(path)]
            : dartFiles(Directory(path));
        for (final f in files) {
          final t = f.readAsStringSync();
          expect(t.contains('EncryptedHealthObservationStore'), isFalse,
              reason: f.path);
          expect(t.contains('HealthObservationKeyVault'), isFalse,
              reason: f.path);
        }
      }
    });
  });

  group('plaintext production persistence forbidden', () {
    test('composition defaults to EncryptedHealthObservationStore', () {
      final text = File(
        'lib/core/lio/lifex_production_composition.dart',
      ).readAsStringSync();
      expect(text.contains('EncryptedHealthObservationStore'), isTrue);
      expect(text.contains('FlutterSecureSecretStore'), isTrue);
      expect(
        RegExp(r'healthObservationStore\s*\?\?\s*FileHealthObservationStore\s*\(')
            .hasMatch(text),
        isFalse,
      );
      expect(text.contains('MemorySecureSecretStore()'), isFalse);
    });
  });

  group('duplicate owner / secrets in source', () {
    test('single owner + no hardcoded DEK material', () {
      final ownerHits = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        if (f
            .readAsStringSync()
            .contains('class PersistentHealthObservationRepository')) {
          ownerHits.add(norm(f.path));
        }
      }
      expect(ownerHits, hasLength(1));
      expect(
        HealthObservationRepository.ownerId,
        'HealthObservationRepository',
      );
      expect(
        EncryptedHealthObservationStore.storeName,
        'EncryptedHealthObservationStore',
      );
      expect(HealthObservationKeyVault.keyRotationSupported, isTrue);

      final secretOffenders = <String>[];
      for (final dir in [
        Directory('lib/core/health_data'),
        Directory('lib/core/security'),
      ]) {
        for (final f in dartFiles(dir)) {
          final t = f.readAsStringSync();
          if (RegExp(
            r'''(?:dek|aesKey|encryptionKey)\s*=\s*['\"][A-Za-z0-9+/=_-]{16,}['\"]''',
            caseSensitive: false,
          ).hasMatch(t)) {
            secretOffenders.add(norm(f.path));
          }
        }
      }
      expect(secretOffenders, isEmpty, reason: secretOffenders.join('\n'));
      expect(
        InMemoryHealthObservationRepository.testOnlyMarker,
        contains('TEST_ONLY'),
      );
      expect(
        MemorySecureSecretStore.testOnlyMarker,
        contains('TEST_ONLY'),
      );
      expect(
        LifexProductionComposition.compositionRootId,
        'LifexProductionComposition',
      );
    });
  });

  group('Fake/Stub / LLM SoT', () {
    test('no Fake health cipher doubles; AI not repository owner', () {
      final offenders = <String>[];
      for (final f in dartFiles(Directory('lib'))) {
        final t = f.readAsStringSync();
        if (RegExp(
          r'class\s+(Fake|Stub)\w*(HealthObservation|Cipher|KeyVault)\b',
        ).hasMatch(t)) {
          offenders.add(norm(f.path));
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      for (final f in dartFiles(Directory('lib/features/ai'))) {
        final t = f.readAsStringSync();
        expect(t.contains('implements HealthObservationRepository'), isFalse,
            reason: f.path);
      }
    });
  });
}
