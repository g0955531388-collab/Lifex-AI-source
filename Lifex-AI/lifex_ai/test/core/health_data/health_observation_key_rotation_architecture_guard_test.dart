import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';

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

  test('UI/Agent/LIO must not touch key lifecycle or secret store', () {
    for (final path in [
      'lib/screens',
      'lib/core/agent',
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    ]) {
      final files =
          path.endsWith('.dart') ? [File(path)] : dartFiles(Directory(path));
      for (final f in files) {
        final t = f.readAsStringSync();
        expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
            reason: f.path);
        expect(t.contains('FlutterSecureSecretStore'), isFalse,
            reason: f.path);
        expect(t.contains('rotateKeys('), isFalse, reason: f.path);
      }
    }
  });

  test('single encrypted store + lifecycle; no plaintext production default', () {
    final text = File(
      'lib/core/lio/lifex_production_composition.dart',
    ).readAsStringSync();
    expect(text.contains('EncryptedHealthObservationStore'), isTrue);
    expect(text.contains('FlutterSecureSecretStore'), isTrue);
    expect(text.contains('MemorySecureSecretStore()'), isFalse);
    expect(
      RegExp(r'healthObservationStore\s*\?\?\s*FileHealthObservationStore\s*\(')
          .hasMatch(text),
      isFalse,
    );

    final lifeHits = <String>[];
    final encHits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      if (t.contains('class HealthObservationKeyLifecycle')) {
        lifeHits.add(norm(f.path));
      }
      if (t.contains('class EncryptedHealthObservationStore')) {
        encHits.add(norm(f.path));
      }
    }
    expect(lifeHits, hasLength(1));
    expect(encHits, hasLength(1));
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
    expect(EncryptedHealthObservationStore.storeName,
        'EncryptedHealthObservationStore');
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
  });

  test('no hardcoded DEK material in health/security sources', () {
    final offenders = <String>[];
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
          offenders.add(norm(f.path));
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no Fake key lifecycle doubles; AI not owner', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      if (RegExp(
        r'class\s+(Fake|Stub)\w*(KeyLifecycle|KeyVault|Cipher)\b',
      ).hasMatch(t)) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    for (final f in dartFiles(Directory('lib/features/ai'))) {
      expect(
        f.readAsStringSync().contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
    }
  });
}
