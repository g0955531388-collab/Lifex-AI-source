/// زر ترجمة الواجهة بين العربية والإنجليزية.
library lifex_ai.widgets.lifex_language_button;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';

class LifexLanguageButton extends StatelessWidget {
  const LifexLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioThemeController.instance,
      builder: (context, _) {
        final arabic =
            AppConfig.instance.defaultLanguage != AppLanguage.english;
        return Semantics(
          button: true,
          label: context.nav('nav.languageHint'),
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: StudioThemeController.instance.toggleLanguage,
            child: Text(
              context.nav(arabic ? 'nav.languageAr' : 'nav.languageEn'),
            ),
          ),
        );
      },
    );
  }
}
