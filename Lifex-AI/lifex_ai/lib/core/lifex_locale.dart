/// لغة الجهاز هي الأصل. زر الترجمة يحفظ اختياراً صريحاً بين العربية والإنجليزية.
/// اللغة غير المترجمة تسقط إلى الإنجليزية في كل الشاشات.
library lifex_ai.core.lifex_locale;

/// [explicitCode] إن كان ar أو en يغلب لغة الجهاز.
String resolveLifexLanguageCode({
  required String? explicitCode,
  required String deviceCode,
}) {
  final explicit = explicitCode?.trim().toLowerCase() ?? '';
  if (explicit.startsWith('ar')) return 'ar';
  if (explicit.startsWith('en')) return 'en';
  final device = deviceCode.trim().toLowerCase();
  if (device.startsWith('ar')) return 'ar';
  return 'en';
}

/// جملة واحدة عندما لغة الجهاز ليست عربية ولا إنجليزية.
String? lifexUntranslatedLanguageNotice({
  required String deviceCode,
}) {
  final device = deviceCode.trim().toLowerCase();
  if (device.isEmpty || device.startsWith('ar') || device.startsWith('en')) {
    return null;
  }
  return 'This language is not available yet. English is being used.';
}
