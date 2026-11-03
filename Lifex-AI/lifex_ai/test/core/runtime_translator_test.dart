import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/core/i18n/lifex_runtime_translator.dart';
import 'package:lifex_ai/widgets/lifex_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _arabic = RegExp(r'[\u0600-\u06FF]');
final _slot = RegExp(r'\{\d+\}');

/// ملفات محتوى لا تُترجم: كتب، مرجع طبي، محلل أوامر عربية، وجمل الكفيف المقفلة.
const exemptPaths = [
  'lib/data/',
  'lib/l10n/generated/',
  'medical',
  'pharmacopoeia',
  '_book',
  'command_parser',
  'spoken_blood_type',
  'blind_camera_speech',
];

Map<String, String> _table() {
  final raw = File('assets/i18n/ui_en.json').readAsStringSync();
  return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
}

void main() {
  test('no-missing-keys: every entry has English with the same slots', () {
    final table = _table();
    expect(table.length, greaterThan(2000));
    for (final entry in table.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(_arabic.hasMatch(entry.value), isFalse, reason: entry.key);
      final keySlots = _slot.allMatches(entry.key).map((m) => m[0]).toSet();
      final valueSlots = _slot.allMatches(entry.value).map((m) => m[0]).toSet();
      expect(valueSlots, keySlots, reason: entry.key);
    }
  });

  test('zero-arabic-leak: no raw Text and every Arabic LifexText literal has English', () {
    final table = _table();
    final literal = RegExp(
      r"LifexText\(\s*'([^'\\$]*)'\s*[,)]",
      multiLine: true,
    );
    final rawText = RegExp(r'(^|[^\w.])Text\(');
    final leaks = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('lib/widgets/lifex_text.dart')) continue;
      final source = file.readAsStringSync();
      for (final line in source.split('\n')) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (rawText.hasMatch(line)) leaks.add('$path raw Text: $trimmed');
      }
      if (exemptPaths.any(path.contains)) continue;
      for (final match in literal.allMatches(source)) {
        final value = match.group(1)!;
        if (!_arabic.hasMatch(value)) continue;
        if (!table.containsKey(value)) leaks.add('$path untranslated: $value');
      }
    }
    expect(leaks, isEmpty, reason: leaks.take(20).join('\n'));
  });

  group('runtime switching', () {
    late AppLanguage? saved;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      saved = AppConfig.instance.explicitLanguage;
      LifexRuntimeTranslator.instance.load(const {
        'مواعيدي': 'My appointments',
        'الزمرة {0}': 'Blood group {0}',
        'حالة {0} و {1}': 'State {1} and {0}',
        'نشط': 'Active',
      });
    });

    tearDown(() {
      AppConfig.instance.explicitLanguage = saved;
      LifexRuntimeTranslator.instance.load(const {});
    });

    test('Arabic stays Arabic and English follows the table', () {
      AppConfig.instance.explicitLanguage = AppLanguage.arabic;
      expect(tr('مواعيدي'), 'مواعيدي');
      AppConfig.instance.explicitLanguage = AppLanguage.english;
      expect(tr('مواعيدي'), 'My appointments');
      expect(tr('الزمرة O+'), 'Blood group O+');
      expect(tr('حالة نشط و 3'), 'State 3 and Active');
      expect(tr('نص غير موجود'), 'نص غير موجود');
      expect(tr<String?>(null), isNull);
    });

    testWidgets('the language button turns an open const text to English',
        (tester) async {
      AppConfig.instance.explicitLanguage = AppLanguage.arabic;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: StudioThemeController.instance,
          builder: (context, _) => const MaterialApp(
            home: Scaffold(body: LifexText('مواعيدي')),
          ),
        ),
      );
      expect(find.text('مواعيدي'), findsOneWidget);
      StudioThemeController.instance.toggleLanguage();
      await tester.pump();
      await tester.pump();
      expect(find.text('My appointments'), findsOneWidget);
    });
  });

  group('phone language', () {
    late AppLanguage? saved;

    setUp(() => saved = AppConfig.instance.explicitLanguage);
    tearDown(() {
      AppConfig.instance.explicitLanguage = saved;
      AppConfig.instance.explicitDeviceCode = null;
    });

    test('a saved choice without the phone stamp gives way to the phone', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.explicitLanguageKey: 'ar',
      });
      await AppConfig.instance.loadExplicitLanguage();
      expect(AppConfig.instance.explicitLanguage, isNull);
    });

    test('a choice made on another phone language gives way', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.explicitLanguageKey: 'ar',
        AppConfig.explicitDeviceKey: 'zz',
      });
      await AppConfig.instance.loadExplicitLanguage();
      expect(AppConfig.instance.explicitLanguage, isNull);
    });

    test('a choice made on the current phone language stays', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.explicitLanguageKey: 'ar',
        AppConfig.explicitDeviceKey: AppConfig.instance.deviceLanguageCode(),
      });
      await AppConfig.instance.loadExplicitLanguage();
      expect(AppConfig.instance.explicitLanguage, AppLanguage.arabic);
    });

    test('changing the phone language drops a stale button choice', () {
      SharedPreferences.setMockInitialValues({});
      AppConfig.instance.explicitLanguage = AppLanguage.arabic;
      AppConfig.instance.explicitDeviceCode = 'zz';
      StudioThemeController.instance.followDeviceLanguage();
      expect(AppConfig.instance.explicitLanguage, isNull);
    });
  });
}
