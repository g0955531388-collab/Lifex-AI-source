import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/security/memory_secure_secret_store.dart';
import 'package:lifex_ai/core/security/secure_secret_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/profile/multi_profile_engine.dart';
import 'package:lifex_ai/features/profile/profile_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingSecrets implements SecureSecretStore {
  @override
  Future<void> deleteSecret(String key) async {}

  @override
  Future<String?> readSecret(String key) async =>
      throw StateError('keystore busy');

  @override
  Future<void> writeSecret(String key, String value) async =>
      throw StateError('keystore busy');
}

class _NoKeystore implements SecureSecretStore {
  @override
  Future<void> deleteSecret(String key) async {}

  @override
  Future<String?> readSecret(String key) async => null;

  @override
  Future<void> writeSecret(String key, String value) async {}
}

MultiProfileEngine engineWith(String name) {
  final engine = MultiProfileEngine(maxProfiles: 4);
  final profile = HealthProfile(
    profileId: 'p-$name',
    fullName: name,
    dateOfBirth: DateTime(1990, 1, 1),
  );
  profile.questionnaireData['note'] = 'حساسية البنسلين';
  engine.addProfile(profile, role: ProfileRole.primaryOwner);
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('الحفظ مشفّر: لا نص صريح، ولا اسم مقروء، والاستعادة سليمة', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecureSecretStore();
    final vault = ProfileVault(prefs, secrets: secrets);
    await vault.save(engineWith('غازي'));

    expect(prefs.getString(ProfileVault.storageKey), isNull);
    final sealed = prefs.getString(ProfileVault.encryptedKey)!;
    expect(sealed, startsWith('LIFEXHOB2.${ProfileVault.keyId}.'));
    expect(sealed.contains('غازي'), isFalse);
    expect(sealed.contains('البنسلين'), isFalse);
    expect(vault.encryptedAtRest, isTrue);

    final restored = MultiProfileEngine(maxProfiles: 4);
    await ProfileVault(prefs, secrets: secrets).loadInto(restored);
    expect(restored.activeProfile!.fullName, 'غازي');
    expect(restored.activeProfile!.questionnaireData['note'], 'حساسية البنسلين');
  });

  test('الترحيل من النص الصريح القديم دون فقد ثم حذفه', () async {
    final legacy = jsonEncode(engineWith('رباب').toJson());
    SharedPreferences.setMockInitialValues({ProfileVault.storageKey: legacy});
    final prefs = await SharedPreferences.getInstance();
    final vault = ProfileVault(prefs, secrets: MemorySecureSecretStore());
    final engine = MultiProfileEngine(maxProfiles: 4);
    await vault.loadInto(engine);

    expect(engine.activeProfile!.fullName, 'رباب');
    expect(vault.lastLoadOutcome, ProfileVaultLoadOutcome.migratedFromPlaintext);
    expect(prefs.getString(ProfileVault.storageKey), isNull);
    expect(prefs.getString(ProfileVault.encryptedKey), isNotNull);
  });

  test('نسخة معبوث بها تُنقل جانباً دون حذف، والتطبيق يكمل', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecureSecretStore();
    await ProfileVault(prefs, secrets: secrets).save(engineWith('أ'));
    final sealed = prefs.getString(ProfileVault.encryptedKey)!;
    final tampered = '${sealed.substring(0, sealed.length - 4)}AAAA';
    await prefs.setString(ProfileVault.encryptedKey, tampered);

    final vault = ProfileVault(prefs, secrets: secrets);
    await expectLater(
      vault.loadInto(MultiProfileEngine(maxProfiles: 4)),
      throwsA(isA<StateError>()),
    );
    expect(vault.lastLoadOutcome, ProfileVaultLoadOutcome.quarantinedUnreadable);
    final kept = prefs
        .getKeys()
        .where((k) => k.startsWith(ProfileVault.quarantinePrefix))
        .map(prefs.getString)
        .toList();
    expect(kept, [tampered]);
    await vault.save(engineWith('جديد'));
    expect(prefs.getString(ProfileVault.encryptedKey), isNotNull);
  });

  test('مفتاح مفقود (نقل لهاتف آخر) لا يحذف الملفات', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfileVault(prefs, secrets: MemorySecureSecretStore())
        .save(engineWith('ب'));
    final sealed = prefs.getString(ProfileVault.encryptedKey)!;

    final vault = ProfileVault(prefs, secrets: MemorySecureSecretStore());
    await expectLater(
      vault.loadInto(MultiProfileEngine(maxProfiles: 4)),
      throwsA(isA<StateError>()),
    );
    expect(
      prefs.getKeys().where((k) => k.startsWith(ProfileVault.quarantinePrefix)).map(prefs.getString),
      contains(sealed),
    );
  });

  test('تحميل لم يكتمل يمنع الكتابة فوق الملفات المشفّرة', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ProfileVault(prefs, secrets: MemorySecureSecretStore())
        .save(engineWith('ج'));
    final sealed = prefs.getString(ProfileVault.encryptedKey)!;

    final vault = ProfileVault(prefs, secrets: _ThrowingSecrets());
    await expectLater(
      vault.loadInto(MultiProfileEngine(maxProfiles: 4)),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      vault.save(MultiProfileEngine(maxProfiles: 4)),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString(ProfileVault.encryptedKey), sealed);
  });

  test('هاتف بلا Keystore يعمل كما كان، ويُعلَم أن التخزين غير مشفّر', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = ProfileVault(prefs, secrets: _NoKeystore());
    await vault.save(engineWith('د'));
    expect(vault.encryptedAtRest, isFalse);
    expect(prefs.getString(ProfileVault.storageKey), isNotNull);

    final restored = MultiProfileEngine(maxProfiles: 4);
    await ProfileVault(prefs, secrets: _NoKeystore()).loadInto(restored);
    expect(restored.activeProfile!.fullName, 'د');
  });
}
