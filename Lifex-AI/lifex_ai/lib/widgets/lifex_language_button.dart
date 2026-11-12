/// زر ترجمة الواجهة بين العربية والإنجليزية.
library lifex_ai.widgets.lifex_language_button;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import 'lifex_text.dart';

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
              minimumSize: const Size(36, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: StudioThemeController.instance.toggleLanguage,
            child: LifexText(
              context.nav(arabic ? 'nav.languageAr' : 'nav.languageEn'),
            ),
          ),
        );
      },
    );
  }
}
