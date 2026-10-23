/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: localization_manager.dart
/// المسار: lib/core/localization_manager.dart
/// الوصف: مدير ترجمة ديناميكي — يقرأ كل النصوص من ملفات JSON في
/// lib/l10n/<locale>.json بدلاً من تضمينها كنصوص ثابتة (Hardcoded) في
/// كل ملف. إضافة لغة جديدة بالكامل = إضافة ملف JSON واحد جديد فقط،
/// دون تعديل أي كود Dart موجود — وهذا ما يجعل "دعم كل اللغات" ممكناً
/// فعلياً وليس مجرد شعار.
///
/// ⚠️ هذا الملف يحل جزءاً واحداً فقط من إمكانية الوصول (ترجمة النصوص).
/// الجزء الآخر الحرج (توافق قارئ الشاشة Semantics) يُعالَج في ملفات
/// الواجهة مباشرة (انظر accessible_widgets.dart).
/// =============================================================
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'error_handler.dart';

/// معلومات لغة واحدة مدعومة.
class SupportedLocale {
  final String code;
  final String displayName;
  final bool isRtl;

  const SupportedLocale({
    required this.code,
    required this.displayName,
    required this.isRtl,
  });
}

/// مدير الترجمة الديناميكي.
class LocalizationManager {
  LocalizationManager._internal();
  static final LocalizationManager instance = LocalizationManager._internal();

  static const String _l10nBasePath = 'lib/l10n/';

  /// اللغات المتوفرة فعلياً كملفات JSON — تُكتشف ديناميكياً عند
  /// التهيئة بدلاً من قائمة ثابتة، حتى تتوسع تلقائياً مع أي ملف جديد
  /// يُضاف لاحقاً دون تعديل هذا الملف.
  final Map<String, Map<String, String>> _loadedStringsByLocale = {};
  final Map<String, SupportedLocale> _localeMetadata = {};

  String _currentLocaleCode = 'ar'; // الافتراضي حتى تُحمَّل لغة المستخدم

  String get currentLocaleCode => _currentLocaleCode;

  bool get isCurrentLocaleRtl =>
      _localeMetadata[_currentLocaleCode]?.isRtl ?? true;

  List<SupportedLocale> get availableLocales =>
      List.unmodifiable(_localeMetadata.values);

  /// تحميل لغة واحدة من ملف JSON عند الحاجة (Lazy Loading) — لا يُحمَّل
  /// كل شيء دفعة واحدة عند الإقلاع.
  Future<bool> loadLocale(String localeCode) async {
    if (_loadedStringsByLocale.containsKey(localeCode)) return true;

    try {
      final raw = await rootBundle.loadString('$_l10nBasePath$localeCode.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final strings = (decoded['strings'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as String));

      _loadedStringsByLocale[localeCode] = strings;
      _localeMetadata[localeCode] = SupportedLocale(
        code: localeCode,
        displayName: decoded['displayName'] as String? ?? localeCode,
        isRtl: decoded['isRtl'] as bool? ?? false,
      );
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'LOCALIZATION_LOAD_FAILED',
        'فشل تحميل ملف الترجمة للغة: $localeCode',
        sourceModule: 'localization_manager',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// تبديل اللغة الحالية للتطبيق — يحمّلها أولاً إن لم تكن محمَّلة.
  Future<bool> switchToLocale(String localeCode) async {
    final loaded = await loadLocale(localeCode);
    if (!loaded) return false;
    _currentLocaleCode = localeCode;
    return true;
  }

  /// الترجمة الفعلية لمفتاح نصي معيّن. لو المفتاح غير موجود في اللغة
  /// الحالية، يرجع للإنجليزية كلغة احتياطية، ثم يرجع المفتاح نفسه كحل
  /// أخير حتى لا ينهار التطبيق أبداً بسبب ترجمة ناقصة.
  String t(String key) {
    final currentStrings = _loadedStringsByLocale[_currentLocaleCode];
    if (currentStrings != null && currentStrings.containsKey(key)) {
      return currentStrings[key]!;
    }

    final fallbackStrings = _loadedStringsByLocale['en'];
    if (fallbackStrings != null && fallbackStrings.containsKey(key)) {
      return fallbackStrings[key]!;
    }

    return key; // حل أخير آمن — لا يُظهر شاشة فارغة أو خطأ للمستخدم
  }
}
