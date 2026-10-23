/// =============================================================
/// Lifex-AI — الهوية الصحية
/// الملف: profile_vault.dart
/// حفظ الملفات الصحية على الجهاز عبر SharedPreferences.
/// =============================================================
library lifex_ai.features.profile.profile_vault;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_constants.dart';
import 'multi_profile_engine.dart';

class ProfileVault {
  ProfileVault(this.prefs);

  final SharedPreferences prefs;
  static const storageKey = '${AppConstants.storageKeyActiveProfileId}_bundle';

  Future<void> loadInto(MultiProfileEngine engine) async {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    engine.restoreFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(MultiProfileEngine engine) async {
    await prefs.setString(storageKey, jsonEncode(engine.toJson()));
  }
}
