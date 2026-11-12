import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_retention_policy.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/security/secure_secret_store.dart';

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

  bool importsOrRefsKeyInfra(String text) {
    return text.contains('HealthObservationKeyLifecycle') ||
        text.contains('HealthObservationKeyVault') ||
        text.contains('HealthObservationKeyRetentionPolicy') ||
        text.contains('FlutterSecureSecretStore') ||
        text.contains('SecureSecretStore') ||
        RegExp(r'\bMemorySecureSecretStore\b').hasMatch(text);
  }

  test('UI must not reach KeyLifecycle / KeyVault / SecureSecretStore', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      final t = f.readAsStringSync();
      expect(importsOrRefsKeyInfra(t), isFalse, reason: f.path);
      expect(t.contains('rotateKeys('), isFalse, reason: f.path);
      expect(t.contains('attemptPurgeKey'), isFalse, reason: f.path);
    }
  });

  test('Agent must not reach KeyLifecycle / KeyVault', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      final t = f.readAsStringSync();
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
          reason: f.path);
      expect(t.contains('HealthObservationKeyVault'), isFalse, reason: f.path);
      expect(t.contains('FlutterSecureSecretStore'), isFalse, reason: f.path);
    }
  });

  test('LIO must not reach KeyLifecycle / KeyVault / SecureSecretStore', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
    ]) {
      final t = File(path).readAsStringSync();
      expect(t.contains('HealthObservationKeyLifecycle'), isFalse,
          reason: path);
      expect(t.contains('HealthObservationKeyVault'), isFalse, reason: path);
      expect(t.contains('SecureSecretStore'), isFalse, reason: path);
      expect(t.contains('HealthObservationKeyRetentionPolicy'), isFalse,
          reason: path);
    }
  });

  test('no duplicate SecureSecretStore / KeyVault / encrypted store', () {
    final secretImpls = <String>[];
    final vaults = <String>[];
    final encrypted = <String>[];
    final lifecycles = <String>[];
    final policies = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      final n = norm(f.path);
      if (RegExp(r'class\s+\w+\s+implements\s+SecureSecretStore\b')
          .hasMatch(t)) {
        secretImpls.add(n);
      }
      if (t.contains('class HealthObservationKeyVault')) vaults.add(n);
      if (t.contains('class EncryptedHealthObservationStore')) {
        encrypted.add(n);
      }
      if (t.contains('class HealthObservationKeyLifecycle')) {
        lifecycles.add(n);
      }
      if (t.contains('class HealthObservationKeyRetentionPolicy')) {
        policies.add(n);
      }
    }
    expect(vaults, hasLength(1));
    expect(encrypted, hasLength(1));
    expect(lifecycles, hasLength(1));
    expect(policies, hasLength(1));
    // Flutter + Memory (test/dev) only — no third production vault path.
    expect(
      secretImpls.any((p) => p.contains('flutter_secure_secret_store')),
      isTrue,
    );
    expect(
      secretImpls.any((p) => p.contains('memory_secure_secret_store')),
      isTrue,
    );
    expect(secretImpls.length, lessThanOrEqualTo(2));
    expect(SecureSecretStore, isNotNull);
  });

  test('no plaintext HealthObservation persistence as production default', () {
    final text = File(
      'lib/core/lio/lifex_production_composition.dart',
    ).readAsStringSync();
    expect(text.contains('EncryptedHealthObservationStore'), isTrue);
    expect(text.contains('FlutterSecureSecretStore'), isTrue);
    expect(text.contains('HealthObservationKeyVault'), isTrue);
    expect(text.contains('MemorySecureSecretStore()'), isFalse);
    expect(
      RegExp(r'healthObservationStore\s*\?\?\s*FileHealthObservationStore\s*\(')
          .hasMatch(text),
      isFalse,
    );
  });

  test('no Fake/Stub key doubles in lib/; no secrets in source', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      if (RegExp(
        r'class\s+(Fake|Stub)\w*(KeyLifecycle|KeyVault|Cipher|Retention)\b',
      ).hasMatch(t)) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));

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
  });

  test('LLM is not source of truth for health observations', () {
    for (final f in dartFiles(Directory('lib/features/ai'))) {
      expect(
        f.readAsStringSync().contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('canonical owner and policy identifiers', () {
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
    expect(
      HealthObservationKeyRetentionPolicy.policyId,
      'HealthObservationKeyRetentionPolicy',
    );
    expect(
      EncryptedHealthObservationStore.storeName,
      'EncryptedHealthObservationStore',
    );
    expect(HealthObservationKeyVault.keyRotationSupported, isTrue);
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
  });
}
