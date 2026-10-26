/// طبقة لغة واحدة لأزرار التنقل.
/// أسماء كتب الطب، والمحتوى المرجعي العام، وأرقام الهواتف، والمبالغ
/// تبقى كما أدخلها المصدر ولا تدخل هذا الملف.
library lifex_ai.core.i18n.lifex_i18n;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class LifexI18nCatalog {
  const LifexI18nCatalog({required this.ar, required this.en});

  final Map<String, String> ar;
  final Map<String, String> en;

  static Future<LifexI18nCatalog> load() async {
    return LifexI18nCatalog(
      ar: _decode(await rootBundle.loadString('assets/i18n/ar.json')),
      en: _decode(await rootBundle.loadString('assets/i18n/en.json')),
    );
  }

  static Map<String, String> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.map((key, value) => MapEntry('$key', '$value'));
  }
}

class LifexI18n extends InheritedWidget {
  const LifexI18n({
    super.key,
    required this.catalog,
    required this.languageCode,
    required super.child,
  });

  final LifexI18nCatalog catalog;
  final String languageCode;

  static LifexI18n? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LifexI18n>();
  }

  String t(String key) {
    final table = languageCode.startsWith('ar') ? catalog.ar : catalog.en;
    return table[key] ?? catalog.en[key] ?? key;
  }

  @override
  bool updateShouldNotify(LifexI18n oldWidget) {
    return languageCode != oldWidget.languageCode ||
        catalog != oldWidget.catalog;
  }
}

extension LifexNavContext on BuildContext {
  String nav(String key) => LifexI18n.maybeOf(this)?.t(key) ?? key;
}
