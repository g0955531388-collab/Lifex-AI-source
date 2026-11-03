/// Persistent Arabic/English locale selection for the application.
library lifex_ai.core.app_locale_controller;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();
  static final AppLocaleController instance = AppLocaleController._();

  static const String _storageKey = 'lifex_app_language_v1';
  Locale _locale = const Locale('en');
  bool _initialized = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isArabic => languageCode == 'ar';

  Future<void> initialize(SharedPreferences preferences) async {
    if (_initialized) return;
    final saved = preferences.getString(_storageKey);
    final systemCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final selected = saved ?? (systemCode == 'ar' ? 'ar' : 'en');
    _locale = Locale(selected == 'ar' ? 'ar' : 'en');
    AppConfig.instance.updateFrom(
      defaultLanguage: isArabic ? AppLanguage.arabic : AppLanguage.english,
    );
    _initialized = true;
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = languageCode.toLowerCase().startsWith('ar') ? 'ar' : 'en';
    if (_locale.languageCode == normalized) return;
    _locale = Locale(normalized);
    AppConfig.instance.updateFrom(
      defaultLanguage:
          normalized == 'ar' ? AppLanguage.arabic : AppLanguage.english,
    );
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_storageKey, normalized);
    if (!saved) {
      throw StateError('Could not persist application language preference');
    }
  }
}
