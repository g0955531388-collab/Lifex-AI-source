import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/core/studio_theme.dart';

void main() {
  test('studio theme keeps the three appearances and no sample record', () {
    final dark = StudioTheme.dark();
    final light = StudioTheme.light();
    final contrast = StudioTheme.contrast();

    expect(dark.scaffoldBackgroundColor, const Color(0xFF020617));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
    expect(contrast.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(dark.colorScheme.primary, const Color(0xFF14B8A6));
    expect(dark.colorScheme.error, StudioTheme.rose);
    expect(dark.cardTheme.elevation, 0);
    expect(dark.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(AppConfig.instance.appearance, StudioAppearance.dark);
    expect(dark.toString().contains('pat-main'), isFalse);
  });
}
