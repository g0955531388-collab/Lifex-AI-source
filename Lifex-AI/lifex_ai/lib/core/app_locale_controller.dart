/// Persistent Arabic/English locale selection for the application.
library lifex_ai.core.app_locale_controller;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class AppLocaleController extends ChangeNotifier with WidgetsBindingObserver {
  AppLocaleController._();
  static final AppLocaleController instance = AppLocaleController._();

  static const String _storageKey = 'lifex_app_language_v1';
  Locale _locale = const Locale('en');
  String _selection = 'system';
  bool _initialized = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isArabic => languageCode == 'ar';
  bool get usesSystemLanguage => _selection == 'system';

  Locale _localeForSystem() {
    final systemCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return Locale(systemCode.toLowerCase().startsWith('ar') ? 'ar' : 'en');
  }

  void _applyLocale(Locale locale) {
    _locale = locale;
    AppConfig.instance.updateFrom(
      defaultLanguage: locale.languageCode == 'ar'
          ? AppLanguage.arabic
          : AppLanguage.english,
    );
  }

  Future<void> initialize(SharedPreferences preferences) async {
    if (_initialized) return;
    _selection = preferences.getString(_storageKey) ?? 'system';
    if (_selection != 'system' && _selection != 'ar' && _selection != 'en') {
      _selection = 'system';
    }
    _applyLocale(
      _selection == 'system'
          ? _localeForSystem()
          : Locale(_selection),
    );
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (!_initialized || !usesSystemLanguage) return;
    final systemLocale = locales != null && locales.isNotEmpty
        ? locales.first
        : WidgetsBinding.instance.platformDispatcher.locale;
    _applyLocale(Locale(
      systemLocale.languageCode.toLowerCase().startsWith('ar') ? 'ar' : 'en',
    ));
    notifyListeners();
  }

  Future<void> setLanguage(String selection) async {
    final normalized = selection.toLowerCase() == 'system'
        ? 'system'
        : selection.toLowerCase().startsWith('ar')
            ? 'ar'
            : 'en';
    final nextLocale =
        normalized == 'system' ? _localeForSystem() : Locale(normalized);
    final changed = _selection != normalized ||
        _locale.languageCode != nextLocale.languageCode;
    _selection = normalized;
    _applyLocale(nextLocale);
    if (changed) notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_storageKey, normalized);
    if (!saved) {
      throw StateError('Could not persist application language preference');
    }
  }
}
