/// زر ترجمة الواجهة بين العربية والإنجليزية.
library lifex_ai.widgets.lifex_language_button;

import 'package:flutter/material.dart';

import '../core/app_config.dart';

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
          label: lifexUi(
            'ترجمة الواجهة بين العربي والإنجليزي',
            'Translate the interface between Arabic and English',
          ),
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: StudioThemeController.instance.toggleLanguage,
            child: Text(arabic ? 'عربي | English' : 'Arabic | عربي'),
          ),
        );
      },
    );
  }
}
