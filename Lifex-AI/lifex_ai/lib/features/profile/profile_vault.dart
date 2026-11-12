/// =============================================================
/// Lifex-AI — الهوية الصحية
/// الملف: profile_vault.dart
/// حفظ الملفات الصحية على الجهاز مشفّرة AES-256-GCM، والمفتاح في Keystore.
/// =============================================================
library lifex_ai.features.profile.profile_vault;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_constants.dart';
import '../../core/health_data/health_observation_cipher.dart';
import '../../core/security/flutter_secure_secret_store.dart';
import '../../core/security/secure_secret_store.dart';
import 'multi_profile_engine.dart';

/// ما جرى عند التحميل، ليُبلَّغ عنه دون أن يُخفى.
enum ProfileVaultLoadOutcome {
  empty,
  decrypted,
  migratedFromPlaintext,
  plaintextKeptEncryptionUnavailable,
  quarantinedUnreadable,
}

class ProfileVault {
  ProfileVault(
    this.prefs, {
    SecureSecretStore? secrets,
    AesGcmHealthObservationCipher? cipher,
  })  : _secrets = secrets ?? FlutterSecureSecretStore(),
        _cipher = cipher ?? AesGcmHealthObservationCipher();

  final SharedPreferences prefs;
  final SecureSecretStore _secrets;
  final AesGcmHealthObservationCipher _cipher;

  /// النص الصريح القديم. يُحذف فقط بعد التحقق من النسخة المشفّرة.
  static const storageKey = '${AppConstants.storageKeyActiveProfileId}_bundle';
  static const encryptedKey = '${storageKey}_enc_v1';
  static const quarantinePrefix = '${storageKey}_unreadable_';
  static const keySecretName = 'lifex_profile_vault_key_v1';
  static const keyId = 'pv1';

  Future<void> _queue = Future<void>.value();
  ProfileVaultLoadOutcome? lastLoadOutcome;

  /// false إن تعذّر مفتاح الجهاز ولم توجد نسخة مشفّرة، فبقي الحفظ كما كان نصاً.
  bool encryptedAtRest = true;

  /// تحميل لم يكتمل يمنع الحفظ، حتى لا يكتب محرك فارغ فوق ملفات لم تُقرأ.
  bool _saveBlocked = false;

  Future<void> loadInto(MultiProfileEngine engine) =>
      _serial(() => _loadInto(engine));

  Future<void> save(MultiProfileEngine engine) =>
      _serial(() => _save(engine));

  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _loadInto(MultiProfileEngine engine) async {
    _saveBlocked = true;
    final sealed = prefs.getString(encryptedKey);
    if (sealed != null && sealed.isNotEmpty) {
      final key = await _readKey();
      String? clear;
      if (key != null) {
        try {
          clear = await _cipher.decrypt(envelope: sealed, keyBytes: key);
        } on HealthObservationCipherException {
          clear = null;
        }
      }
      if (clear == null) {
        await _quarantine(sealed);
        _saveBlocked = false;
        lastLoadOutcome = ProfileVaultLoadOutcome.quarantinedUnreadable;
        throw StateError(
          'PROFILE_VAULT_UNREADABLE: الملفات المشفّرة لم تُفتح بمفتاح هذا الجهاز. '
          'نُقلت جانباً دون حذف.',
        );
      }
      engine.restoreFromJson(jsonDecode(clear) as Map<String, dynamic>);
      await prefs.remove(storageKey);
      encryptedAtRest = true;
      _saveBlocked = false;
      lastLoadOutcome = ProfileVaultLoadOutcome.decrypted;
      return;
    }
    final plain = prefs.getString(storageKey);
    if (plain == null || plain.isEmpty) {
      _saveBlocked = false;
      lastLoadOutcome = ProfileVaultLoadOutcome.empty;
      return;
    }
    engine.restoreFromJson(jsonDecode(plain) as Map<String, dynamic>);
    _saveBlocked = false;
    try {
      await _seal(plain);
      encryptedAtRest = true;
      lastLoadOutcome = ProfileVaultLoadOutcome.migratedFromPlaintext;
    } on Object {
      encryptedAtRest = false;
      lastLoadOutcome =
          ProfileVaultLoadOutcome.plaintextKeptEncryptionUnavailable;
    }
  }

  Future<void> _save(MultiProfileEngine engine) async {
    if (_saveBlocked) {
      throw StateError(
        'PROFILE_VAULT_SAVE_BLOCKED: لم يكتمل تحميل الملفات، فلا يُكتب فوقها.',
      );
    }
    final clear = jsonEncode(engine.toJson());
    try {
      await _seal(clear);
      encryptedAtRest = true;
    } on Object {
      final hasSealed = (prefs.getString(encryptedKey) ?? '').isNotEmpty;
      if (hasSealed) rethrow;
      await prefs.setString(storageKey, clear);
      encryptedAtRest = false;
    }
  }

  /// يكتب النسخة المشفّرة ثم يفكّها ويقارن قبل حذف أي نص صريح.
  Future<void> _seal(String clear) async {
    final key = await _readOrCreateKey();
    final sealed = await _cipher.encrypt(
      plaintext: clear,
      keyBytes: key,
      keyId: keyId,
    );
    final check = await _cipher.decrypt(envelope: sealed, keyBytes: key);
    if (check != clear) {
      throw StateError('PROFILE_VAULT_VERIFY_FAILED: لم يُحذف النص الصريح.');
    }
    final written = await prefs.setString(encryptedKey, sealed);
    if (!written || prefs.getString(encryptedKey) != sealed) {
      throw StateError('PROFILE_VAULT_WRITE_FAILED: لم يُحذف النص الصريح.');
    }
    await prefs.remove(storageKey);
  }

  Future<void> _quarantine(String sealed) async {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    await prefs.setString('$quarantinePrefix$stamp', sealed);
    await prefs.remove(encryptedKey);
  }

  Future<Uint8List?> _readKey() async {
    final stored = await _secrets.readSecret(keySecretName);
    if (stored == null || stored.isEmpty) return null;
    try {
      final bytes = base64Url.decode(stored);
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  Future<Uint8List> _readOrCreateKey() async {
    final existing = await _readKey();
    if (existing != null) return existing;
    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secrets.writeSecret(keySecretName, base64Url.encode(key));
    final back = await _readKey();
    if (back == null) {
      throw StateError('PROFILE_VAULT_KEY_UNAVAILABLE: تعذّر حفظ مفتاح التشفير.');
    }
    return back;
  }
}
