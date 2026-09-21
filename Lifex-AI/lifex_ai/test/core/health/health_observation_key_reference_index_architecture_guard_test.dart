import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/encrypted_health_observation_store.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_lifecycle.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_reference_index.dart';
import 'package:lifex_ai/core/health_data/health_observation_key_vault.dart';
import 'package:lifex_ai/core/health_data/health_observation_repository.dart';
import 'package:lifex_ai/core/health_data/persistent_health_observation_repository.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/lifex_production_composition.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';

/// Architecture Guards A–Y for HealthObservation Key Reference Index.
/// Static file-scanning — same style as prior Lifex guards.
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

  bool mentions(String text, List<String> needles) =>
      needles.any(text.contains);

  final keyInfraNeedles = [
    'HealthObservationKeyReferenceIndex',
    'HealthObservationKeyLifecycle',
    'HealthObservationKeyVault',
    'EncryptedHealthObservationStore',
    'FlutterSecureSecretStore',
    'SecureSecretStore',
    'MemorySecureSecretStore',
  ];

  test('A UI → ReferenceIndex forbidden', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyReferenceIndex'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('B Agent → ReferenceIndex forbidden', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyReferenceIndex'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('C LIO → ReferenceIndex forbidden', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
      'lib/core/lio/lio_orchestrator.dart',
      'lib/core/lio/lifex_intelligence_fabric.dart',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyReferenceIndex'),
        isFalse,
        reason: path,
      );
    }
  });

  test('D UI → KeyLifecycle forbidden', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyLifecycle'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('E Agent → KeyLifecycle forbidden', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyLifecycle'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('F LIO → KeyLifecycle forbidden', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/lio/lio_orchestrator.dart',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyLifecycle'),
        isFalse,
        reason: path,
      );
    }
  });

  test('G UI → KeyVault forbidden', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyVault'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('H Agent → KeyVault forbidden', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      expect(
        f.readAsStringSync().contains('HealthObservationKeyVault'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('I LIO → KeyVault forbidden', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/lio/lio_orchestrator.dart',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyVault'),
        isFalse,
        reason: path,
      );
    }
  });

  test('J UI → SecureSecretStore forbidden', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      final t = f.readAsStringSync();
      expect(t.contains('SecureSecretStore'), isFalse, reason: f.path);
      expect(t.contains('FlutterSecureSecretStore'), isFalse, reason: f.path);
    }
  });

  test('K Agent → SecureSecretStore forbidden', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      final t = f.readAsStringSync();
      expect(t.contains('SecureSecretStore'), isFalse, reason: f.path);
      expect(t.contains('FlutterSecureSecretStore'), isFalse, reason: f.path);
    }
  });

  test('L LIO → SecureSecretStore forbidden', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
      'lib/core/lio/lio_orchestrator.dart',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('SecureSecretStore'),
        isFalse,
        reason: path,
      );
    }
  });

  test('M UI/Agent/LIO → EncryptedHealthObservationStore forbidden', () {
    for (final dir in [
      Directory('lib/screens'),
      Directory('lib/core/agent'),
    ]) {
      for (final f in dartFiles(dir)) {
        expect(
          f.readAsStringSync().contains('EncryptedHealthObservationStore'),
          isFalse,
          reason: f.path,
        );
      }
    }
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    ]) {
      expect(
        File(path).readAsStringSync().contains('EncryptedHealthObservationStore'),
        isFalse,
        reason: path,
      );
    }
  });

  test('N single ReferenceIndex abstraction (no duplicate)', () {
    final hits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f.readAsStringSync().contains(
        'abstract class HealthObservationKeyReferenceIndex',
      )) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(
      HealthObservationKeyReferenceIndex.indexId,
      'HealthObservationKeyReferenceIndex',
    );
  });

  test('O single EncryptedHealthObservationStore class', () {
    final hits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f
          .readAsStringSync()
          .contains('class EncryptedHealthObservationStore')) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(
      EncryptedHealthObservationStore.storeName,
      'EncryptedHealthObservationStore',
    );
  });

  test('P single KeyLifecycle class', () {
    final hits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f
          .readAsStringSync()
          .contains('class HealthObservationKeyLifecycle')) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
  });

  test('Q single KeyVault class', () {
    final hits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f.readAsStringSync().contains('class HealthObservationKeyVault')) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(HealthObservationKeyVault.vaultId, 'HealthObservationKeyVault');
  });

  test('R ReferenceIndex is not HealthObservation Canonical Owner', () {
    for (final f in dartFiles(Directory('lib/core/health_data'))) {
      final n = norm(f.path);
      if (!n.contains('key_reference_index')) continue;
      final t = f.readAsStringSync();
      expect(t.contains('implements HealthObservationRepository'), isFalse);
      expect(
        t.contains('abstract class HealthObservationRepository'),
        isFalse,
      );
    }
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
  });

  test('S no plaintext HealthObservation as production default store', () {
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

  test('T no embedded secrets/keys in ReferenceIndex source', () {
    final f = File(
      'lib/core/health_data/health_observation_key_reference_index.dart',
    );
    final t = f.readAsStringSync();
    expect(
      RegExp(
        r'''(?:dek|aesKey|encryptionKey|apiKey|secret)\s*=\s*['\"][A-Za-z0-9+/=_-]{16,}['\"]''',
        caseSensitive: false,
      ).hasMatch(t),
      isFalse,
    );
    expect(RegExp(r"'value'\s*:|'patientId'\s*:").hasMatch(t), isFalse);
  });

  test('U no Fake/Stub doubles inside lib/', () {
    final offenders = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      final t = f.readAsStringSync();
      if (RegExp(
        r'class\s+(Fake|Stub)\w*(KeyLifecycle|KeyVault|ReferenceIndex|Cipher|SecretStore)\b',
      ).hasMatch(t)) {
        offenders.add(norm(f.path));
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('V LLM is not Source of Truth', () {
    const canon = LifexLioCanon();
    const safety = KnowledgeEngineSafety();
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
    expect(safety.llmIsSourceOfTruth, isFalse);
  });

  test('W direct UI → Repository forbidden', () {
    for (final f in dartFiles(Directory('lib/screens'))) {
      final t = f.readAsStringSync();
      expect(
        t.contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
      expect(
        t.contains('PersistentHealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
      expect(mentions(t, keyInfraNeedles), isFalse, reason: f.path);
    }
  });

  test('X direct Agent → Repository forbidden', () {
    for (final f in dartFiles(Directory('lib/core/agent'))) {
      final t = f.readAsStringSync();
      expect(
        t.contains('PersistentHealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
      expect(
        t.contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('Y direct LIO → Repository forbidden', () {
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
      'lib/core/lio/lio_orchestrator.dart',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final t = f.readAsStringSync();
      expect(
        t.contains('PersistentHealthObservationRepository'),
        isFalse,
        reason: path,
      );
      expect(
        t.contains('implements HealthObservationRepository'),
        isFalse,
        reason: path,
      );
    }
    // Entry may import ApplicationService only — not Repository implementation.
    final entry = File(
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    ).readAsStringSync();
    expect(entry.contains('PersistentHealthObservationRepository'), isFalse);
    expect(entry.contains('EncryptedHealthObservationStore'), isFalse);
  });

  test('Ownership: Repository owner; Index=refs; Lifecycle=keys', () {
    expect(
      HealthObservationRepository.ownerId,
      'HealthObservationRepository',
    );
    expect(
      PersistentHealthObservationRepository.implementationId,
      'PersistentHealthObservationRepository',
    );
    expect(
      HealthObservationKeyReferenceIndex.indexId,
      'HealthObservationKeyReferenceIndex',
    );
    expect(
      HealthObservationKeyLifecycle.lifecycleId,
      'HealthObservationKeyLifecycle',
    );
    expect(
      LifexProductionComposition.compositionRootId,
      'LifexProductionComposition',
    );
  });
}
