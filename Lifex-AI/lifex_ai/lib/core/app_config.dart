/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: app_config.dart
/// المسار: lib/core/app_config.dart
/// الوصف: إعدادات النظام العامة القابلة للتغيير أثناء التشغيل
/// (بيئة التشغيل، اللغة الافتراضية، إعدادات الخصوصية العامة...).
/// =============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lifex_locale.dart';
import 'studio_theme.dart';

/// بيئات التشغيل الممكنة للتطبيق.
enum AppEnvironment { development, staging, production }

/// اللغات المدعومة حالياً داخل التطبيق.
enum AppLanguage { arabic, english }

/// إعدادات عامة قابلة للتعديل من قبل المستخدم أو المدير.
///
/// هذا الكلاس Singleton يحمل الإعدادات في الذاكرة أثناء التشغيل.
/// لغة الجهاز هي الأصل. زر الترجمة يحفظ اختيار العربية أو الإنجليزية.
class AppConfig {
  AppConfig._internal();
  static final AppConfig instance = AppConfig._internal();

  AppEnvironment environment = AppEnvironment.development;

  /// اختيار زر الترجمة. يبقى فارغاً حتى يضغط المستخدم الزر.
  AppLanguage? explicitLanguage;

  static const explicitLanguageKey = 'lifex_explicit_language_v1';

  /// اللغة الحاكمة: الاختيار المحفوظ، وإلا لغة الجهاز، وإلا الإنجليزية.
  AppLanguage get defaultLanguage {
    final explicit = explicitLanguage == null
        ? null
        : explicitLanguage == AppLanguage.arabic
            ? 'ar'
            : 'en';
    final resolved = resolveLifexLanguageCode(
      explicitCode: explicit,
      deviceCode: _deviceLanguageCode(),
    );
    return resolved == 'ar' ? AppLanguage.arabic : AppLanguage.english;
  }

  String _deviceLanguageCode() {
    try {
      return PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {
      return 'en';
    }
  }

  Future<void> loadExplicitLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(explicitLanguageKey);
    if (raw == 'ar') {
      explicitLanguage = AppLanguage.arabic;
    } else if (raw == 'en') {
      explicitLanguage = AppLanguage.english;
    } else {
      explicitLanguage = null;
    }
  }

  Future<void> saveExplicitLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final chosen = explicitLanguage;
    if (chosen == null) {
      await prefs.remove(explicitLanguageKey);
    } else {
      await prefs.setString(
        explicitLanguageKey,
        chosen == AppLanguage.arabic ? 'ar' : 'en',
      );
    }
  }

  /// هل الوضع الليلي مفعّل؟ يبقى متوافقاً مع المظهر الداكن.
  bool darkModeEnabled = true;

  /// مظهر الاستوديو: ليلي، نهاري، أو تباين عالٍ. بلا بيانات عرض.
  StudioAppearance appearance = StudioAppearance.dark;

  /// هل يُسمح بجمع بيانات استخدام مجهولة الهوية لتحسين النظام؟
  bool anonymousAnalyticsEnabled = false;

  /// هل الوضع الصوتي (قراءة تلقائية للتنبيهات) مفعّل افتراضياً؟
  bool voiceGuidanceEnabledByDefault = true;

  /// الأوامر التي تسمع الميكروفون. إيقافها لا يوقف النطق.
  bool voiceCommandsEnabled = true;

  /// هل يُسمح بالعمل بدون اتصال إنترنت (Offline-first)؟
  bool offlineModeSupported = true;

  /// الحد الأقصى لعدد الملفات الصحية داخل الحساب الواحد (نظام الحسابات
  /// المتعددة للعائلة).
  int maxFamilyProfilesPerAccount = 8;

  /// مدة صلاحية جلسة تسجيل الدخول قبل طلب إعادة التحقق (بالدقائق).
  int sessionTimeoutMinutes = 30;

  /// تحديث مجموعة من الإعدادات دفعة واحدة.
  void updateFrom({
    AppEnvironment? environment,
    AppLanguage? defaultLanguage,
    bool followDeviceLanguage = false,
    bool? darkModeEnabled,
    StudioAppearance? appearance,
    bool? anonymousAnalyticsEnabled,
    bool? voiceGuidanceEnabledByDefault,
    bool? voiceCommandsEnabled,
    bool? offlineModeSupported,
    int? maxFamilyProfilesPerAccount,
    int? sessionTimeoutMinutes,
  }) {
    if (environment != null) this.environment = environment;
    if (followDeviceLanguage) {
      explicitLanguage = null;
    } else if (defaultLanguage != null) {
      explicitLanguage = defaultLanguage;
    }
    if (darkModeEnabled != null) {
      this.darkModeEnabled = darkModeEnabled;
      if (appearance == null) {
        this.appearance =
            darkModeEnabled ? StudioAppearance.dark : StudioAppearance.light;
      }
    }
    if (appearance != null) {
      this.appearance = appearance;
      this.darkModeEnabled = appearance == StudioAppearance.dark;
    }
    if (anonymousAnalyticsEnabled != null) {
      this.anonymousAnalyticsEnabled = anonymousAnalyticsEnabled;
    }
    if (voiceGuidanceEnabledByDefault != null) {
      this.voiceGuidanceEnabledByDefault = voiceGuidanceEnabledByDefault;
    }
    if (voiceCommandsEnabled != null) {
      this.voiceCommandsEnabled = voiceCommandsEnabled;
    }
    if (offlineModeSupported != null) {
      this.offlineModeSupported = offlineModeSupported;
    }
    if (maxFamilyProfilesPerAccount != null) {
      this.maxFamilyProfilesPerAccount = maxFamilyProfilesPerAccount;
    }
    if (sessionTimeoutMinutes != null) {
      this.sessionTimeoutMinutes = sessionTimeoutMinutes;
    }
  }

  Map<String, dynamic> toJson() => {
        'environment': environment.name,
        'defaultLanguage': defaultLanguage.name,
        'explicitLanguage': explicitLanguage?.name,
        'darkModeEnabled': darkModeEnabled,
        'appearance': appearance.name,
        'anonymousAnalyticsEnabled': anonymousAnalyticsEnabled,
        'voiceGuidanceEnabledByDefault': voiceGuidanceEnabledByDefault,
        'voiceCommandsEnabled': voiceCommandsEnabled,
        'offlineModeSupported': offlineModeSupported,
        'maxFamilyProfilesPerAccount': maxFamilyProfilesPerAccount,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
      };
}

class StudioThemeController extends ChangeNotifier {
  StudioThemeController._();

  static final StudioThemeController instance = StudioThemeController._();

  void setAppearance(StudioAppearance value) {
    AppConfig.instance.appearance = value;
    notifyListeners();
  }

  void cycleAppearance() {
    final next = switch (AppConfig.instance.appearance) {
      StudioAppearance.dark => StudioAppearance.light,
      StudioAppearance.light => StudioAppearance.contrast,
      StudioAppearance.contrast => StudioAppearance.dark,
    };
    setAppearance(next);
  }

  void toggleLanguage() {
    final current = AppConfig.instance.defaultLanguage;
    AppConfig.instance.explicitLanguage = current == AppLanguage.arabic
        ? AppLanguage.english
        : AppLanguage.arabic;
    unawaited(AppConfig.instance.saveExplicitLanguage());
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

/// عبارة واجهة بالعربية أو الإنجليزية حسب اللغة الحاكمة.
String lifexUi(String arabic, String english) =>
    AppConfig.instance.defaultLanguage == AppLanguage.english ? english : arabic;
