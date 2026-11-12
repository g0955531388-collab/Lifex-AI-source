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

/// Canonical Architecture Guards for HealthObservation Key Reference Index.
/// Path: test/core/health/ — sole guard file for Reference Index rules (A–R).
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

  final lioPaths = [
    'lib/core/orchestrator/lio_gateway.dart',
    'lib/core/orchestrator/lio_sensitive_action_entry.dart',
    'lib/core/orchestrator/lio_gateway_contracts.dart',
    'lib/core/lio/lio_orchestrator.dart',
    'lib/core/lio/lifex_intelligence_fabric.dart',
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
    for (final path in lioPaths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyReferenceIndex'),
        isFalse,
        reason: path,
      );
    }
  });

  test('D UI/Agent/LIO → KeyLifecycle forbidden', () {
    for (final dir in [Directory('lib/screens'), Directory('lib/core/agent')]) {
      for (final f in dartFiles(dir)) {
        expect(
          f.readAsStringSync().contains('HealthObservationKeyLifecycle'),
          isFalse,
          reason: f.path,
        );
      }
    }
    for (final path in lioPaths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyLifecycle'),
        isFalse,
        reason: path,
      );
    }
  });

  test('E UI/Agent/LIO → KeyVault forbidden', () {
    for (final dir in [Directory('lib/screens'), Directory('lib/core/agent')]) {
      for (final f in dartFiles(dir)) {
        expect(
          f.readAsStringSync().contains('HealthObservationKeyVault'),
          isFalse,
          reason: f.path,
        );
      }
    }
    for (final path in lioPaths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('HealthObservationKeyVault'),
        isFalse,
        reason: path,
      );
    }
  });

  test('F UI/Agent/LIO → SecureSecretStore forbidden', () {
    for (final dir in [Directory('lib/screens'), Directory('lib/core/agent')]) {
      for (final f in dartFiles(dir)) {
        final t = f.readAsStringSync();
        expect(t.contains('SecureSecretStore'), isFalse, reason: f.path);
        expect(t.contains('FlutterSecureSecretStore'), isFalse, reason: f.path);
        expect(t.contains('MemorySecureSecretStore'), isFalse, reason: f.path);
      }
    }
    for (final path in lioPaths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('SecureSecretStore'),
        isFalse,
        reason: path,
      );
    }
  });

  test('G UI/Agent/LIO → EncryptedHealthObservationStore forbidden', () {
    for (final dir in [Directory('lib/screens'), Directory('lib/core/agent')]) {
      for (final f in dartFiles(dir)) {
        expect(
          f.readAsStringSync().contains('EncryptedHealthObservationStore'),
          isFalse,
          reason: f.path,
        );
      }
    }
    for (final path in lioPaths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      expect(
        f.readAsStringSync().contains('EncryptedHealthObservationStore'),
        isFalse,
        reason: path,
      );
    }
  });

  test('H UI/Agent/LIO → Repository forbidden', () {
    for (final dir in [Directory('lib/screens'), Directory('lib/core/agent')]) {
      for (final f in dartFiles(dir)) {
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
    }
    for (final path in [
      'lib/core/orchestrator/lio_gateway.dart',
      'lib/core/orchestrator/lio_gateway_contracts.dart',
      'lib/core/lio/lio_orchestrator.dart',
      'lib/core/orchestrator/lio_sensitive_action_entry.dart',
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
  });

  test('I duplicate ReferenceIndex forbidden', () {
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

  test('J duplicate Encrypted Store forbidden', () {
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

  test('K duplicate KeyLifecycle forbidden', () {
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

  test('L duplicate KeyVault forbidden', () {
    final hits = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f.readAsStringSync().contains('class HealthObservationKeyVault')) {
        hits.add(norm(f.path));
      }
    }
    expect(hits, hasLength(1));
    expect(HealthObservationKeyVault.vaultId, 'HealthObservationKeyVault');
  });

  test('M ReferenceIndex is not Canonical Owner', () {
    for (final f in dartFiles(Directory('lib/core/health_data'))) {
      final n = norm(f.path);
      if (!n.contains('key_reference_index')) continue;
      final t = f.readAsStringSync();
      expect(t.contains('implements HealthObservationRepository'), isFalse);
      expect(
        RegExp(r"'value'\s*:|'unit'\s*:|'patientId'\s*:").hasMatch(t),
        isFalse,
        reason: n,
      );
    }
  });

  test('N plaintext HealthObservation production persistence forbidden', () {
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

  test('O secrets/keys inside ReferenceIndex source forbidden', () {
    final t = File(
      'lib/core/health_data/health_observation_key_reference_index.dart',
    ).readAsStringSync();
    expect(
      RegExp(
        r'''(?:dek|aesKey|encryptionKey|apiKey|secret)\s*=\s*['\"][A-Za-z0-9+/=_-]{16,}['\"]''',
        caseSensitive: false,
      ).hasMatch(t),
      isFalse,
    );
  });

  test('P Fake/Stub inside lib/ forbidden', () {
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

  test('Q LLM ≠ Source of Truth', () {
    const canon = LifexLioCanon();
    const safety = KnowledgeEngineSafety();
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
    expect(safety.llmIsSourceOfTruth, isFalse);
  });

  test('R HealthObservationRepository is sole Canonical Owner', () {
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
    // AI features must not implement the repository.
    for (final f in dartFiles(Directory('lib/features/ai'))) {
      expect(
        f.readAsStringSync().contains('implements HealthObservationRepository'),
        isFalse,
        reason: f.path,
      );
    }
    final owners = <String>[];
    for (final f in dartFiles(Directory('lib'))) {
      if (f.readAsStringSync().contains('implements HealthObservationRepository')) {
        owners.add(norm(f.path));
      }
    }
    expect(
      owners.where((p) => p.contains('persistent_health_observation')).length,
      1,
    );
  });
}
