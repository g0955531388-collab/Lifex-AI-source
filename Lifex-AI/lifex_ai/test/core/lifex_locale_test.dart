import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lifex_locale.dart';

void main() {
  test('the phone language is the system language', () {
    expect(
      resolveLifexLanguageCode(explicitCode: null, deviceCode: 'en'),
      'en',
    );
    expect(
      resolveLifexLanguageCode(explicitCode: null, deviceCode: 'ar'),
      'ar',
    );
    expect(
      resolveLifexLanguageCode(explicitCode: null, deviceCode: 'ar_SY'),
      'ar',
    );
    expect(
      resolveLifexLanguageCode(explicitCode: 'en', deviceCode: 'ar'),
      'en',
    );
    expect(
      resolveLifexLanguageCode(explicitCode: 'ar', deviceCode: 'en'),
      'ar',
    );
  });

  test('an untranslated phone language is announced in English', () {
    expect(
      lifexUntranslatedLanguageNotice(deviceCode: 'fr'),
      'This language is not available yet. English is being used.',
    );
    expect(
      lifexUntranslatedLanguageNotice(deviceCode: 'ar'),
      isNull,
    );
  });

  test('an untranslated phone language falls back to English', () {
    for (final code in ['fr', 'de', 'es', 'tr', 'zh', 'ja', 'hi']) {
      expect(
        resolveLifexLanguageCode(explicitCode: null, deviceCode: code),
        'en',
        reason: code,
      );
    }
  });
}
