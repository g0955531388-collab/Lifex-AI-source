import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_reference_index.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
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

  bool touchesKeyInfra(String text) {
    return text.contains('HealthObservationKeyLifecycle') ||
        text.contains('HealthObservationKeyVault') ||
        text.contains('HealthObservationKeyReferenceIndex') ||
        text.contains('FlutterSecureSecretStore') ||
        text.contains('SecureSecretStore') ||
        text.contains('EncryptedHealthObservationStore') ||
        text.contains('PersistentHealthObservationRepository') ||
        RegExp(r'\bHealthObservationRepository\b').hasMatch(text);
  }

  test('UI must not reach ReferenceIndex / key infra / repository', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      final t = f.readAsStringSync();
      expect(t.contains('HealthObservationKeyReferenceIndex'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyVault'), isFalse, reason: f.path);
      expect(t.contains('FlutterSecureSecretStore'), isFalse, reason: f.path);
      expect(t.contains('EncryptedHealthObservationStore'), isFalse,
          reason: f.path);
      expect(
        t.contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('Agent must not reach ReferenceIndex / key infra / repository', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      final t = f.readAsStringSync();
      expect(touchesKeyInfra(t) && t.contains('HealthObservationKey'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyReferenceIndex'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyVault'), isFalse, reason: f.path);
    }
  });

  test('LIO must not reach ReferenceIndex / KeyLifecycle / KeyVault / store',
      () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
    ]) {
      final t = File(path).readAsStringSync();
      expect(t.contains('HealthObservationKeyReferenceIndex'), isFalse,
          reason: path);
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
          reason: path);
      expect(t.contains('HealthObservationKeyVault'), isFalse, reason: path);
      expect(t.contains('SecureSecretStore'), isFalse, reason: path);
      expect(t.contains('EncryptedHealthObservationStore'), isFalse,
          reason: path);
    }
  });

  test('single ReferenceIndex abstraction; not a HealthObservation owner', () {
    final abstracts = <String>[];
    final owners = <String>[];
    final encrypted = <String>[];
    final lifecycles = <String>[];
    final vaults = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      final n = norm(f.path);
      if (t.contains('abstract class HealthObservationKeyReferenceIndex')) {
        abstracts.add(n);
      }
      if (t.contains('implements HealthObservationRepository')) {
        owners.add(n);
      }
      if (t.contains('class EncryptedHealthObservationStore')) {
        encrypted.add(n);
      }
      if (t.contains('class HealthObservationKeyLifecycle')) {
        lifecycles.add(n);
      }
      if (t.contains('class HealthObservationKeyVault')) vaults.add(n);
      // Index must not claim repository ownership.
      if (n.contains('key_reference_index') &&
          t.contains('implements HealthObservationRepository')) {
        fail('ReferenceIndex must not own HealthObservation: $n');
      }
      if (n.contains('key_reference_index')) {
        expect(
          t.contains('implements HealthObservationRepository'),
          isFalse,
          reason: n,
        );
        expect(
          RegExp(
            r'''(?:dek|aesKey|encryptionKey)\s*=\s*['\"][A-Za-z0-9+/=_-]{16,}['\"]''',
            caseSensitive: false,
          ).hasMatch(t),
          isFalse,
          reason: n,
        );
        // Must not persist observation clinical fields in index JSON schema.
        expect(
          RegExp(r"'value'\s*:|'unit'\s*:|'patientId'\s*:").hasMatch(t),
          isFalse,
          reason: n,
        );
      }
    }
    expect(abstracts, hasLength(1));
    expect(encrypted, hasLength(1));
    expect(lifecycles, hasLength(1));
    expect(vaults, hasLength(1));
    expect(
      owners.where((p) => p.contains('persistent_health_observation')).length,
      1,
    );
    expect(
      HealthObservationKeyReferenceIndex.indexId,
      'HealthObservationKeyReferenceIndex',
    );
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
    expect(HealthObservationKeyVault.vaultId, 'HealthObservationKeyVault');
    expect(
      EncryptedHealthObservationStore.storeName,
      'EncryptedHealthObservationStore',
    );
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
  });

  test('no Fake/Stub key or index doubles in lib/; LLM ≠ SoT', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      if (RegExp(
        r'class\s+(Fake|Stub)\w*(KeyLifecycle|KeyVault|ReferenceIndex|Cipher)\b',
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

  test('no plaintext HealthObservation persistence as production default', () {
    final text = File(
      'lib/core/lio/lifex_production_composition.dart',
    ).readAsStringSync();
    expect(text.contains('EncryptedHealthObservationStore'), isTrue);
    expect(
      RegExp(r'healthObservationStore\s*\?\?\s*FileHealthObservationStore\s*\(')
          .hasMatch(text),
      isFalse,
    );
  });
}
