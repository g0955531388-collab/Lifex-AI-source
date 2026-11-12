import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/core/studio_theme.dart';
import 'package:lifex_ai/core/i18n/lifex_i18n.dart';
import 'package:lifex_ai/widgets/lifex_language_button.dart';

void main() {
  testWidgets('زر اللغة يبدّل نص الصفحة المفتوحة', (tester) async {
    final prior = AppConfig.instance.explicitLanguage;
    AppConfig.instance.explicitLanguage = AppLanguage.arabic;
    addTearDown(() {
      AppConfig.instance.explicitLanguage = prior;
    });
    const catalog = LifexI18nCatalog(
      ar: {
        'nav.languageAr': 'English',
        'nav.languageEn': 'العربية',
        'nav.languageHint': 'لغة',
      },
      en: {
        'nav.languageAr': 'English',
        'nav.languageEn': 'العربية',
        'nav.languageHint': 'Language',
      },
    );

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: StudioThemeController.instance,
        builder: (context, _) {
          final code =
              AppConfig.instance.defaultLanguage == AppLanguage.arabic
                  ? 'ar'
                  : 'en';
          return LifexI18n(
            catalog: catalog,
            languageCode: code,
            child: MaterialApp(
              locale: Locale(code),
              home: const _HeldPage(),
            ),
          );
        },
      ),
    );

    expect(find.text('ملف عربي'), findsOneWidget);
    await tester.tap(find.byType(LifexLanguageButton));
    await tester.pump();
    await tester.pump();
    expect(find.text('English file'), findsOneWidget);
    expect(AppConfig.instance.explicitLanguage, AppLanguage.english);
  });

  test('حفظ المظهر لا يمسح اختيار اللغة', () {
    final prior = AppConfig.instance.explicitLanguage;
    final appearance = AppConfig.instance.appearance;
    addTearDown(() {
      AppConfig.instance.explicitLanguage = prior;
      AppConfig.instance.appearance = appearance;
    });
    AppConfig.instance.explicitLanguage = AppLanguage.english;
    AppConfig.instance.updateFrom(appearance: StudioAppearance.light);
    expect(AppConfig.instance.explicitLanguage, AppLanguage.english);
    expect(AppConfig.instance.defaultLanguage, AppLanguage.english);
  });
}

class _HeldPage extends StatefulWidget {
  const _HeldPage();

  @override
  State<_HeldPage> createState() => _HeldPageState();
}

class _HeldPageState extends State<_HeldPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(lifexUi('ملف عربي', 'English file')),
      floatingActionButton: const LifexLanguageButton(),
    );
  }
}
