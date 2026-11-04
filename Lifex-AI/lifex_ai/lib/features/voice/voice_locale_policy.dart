/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: voice_locale_policy.dart
/// لغة الاستماع والنطق: لغة الجهاز أولاً، ثم لغة المتحدث إن عُرفت.
/// =============================================================
library lifex_ai.features.voice.voice_locale_policy;

import 'package:flutter/widgets.dart';

import '../../core/app_locale_controller.dart';

class VoiceLocalePolicy {
  const VoiceLocalePolicy();

  Locale deviceLocale() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      return const Locale('ar');
    }
  }

  String engineIdFor(Locale locale) {
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }

  /// Voice recognition follows the app's explicit language choice; that
  /// choice is initialized from the phone locale on first launch.
  String preferredListenCode() =>
      AppLocaleController.instance.languageCode.isNotEmpty
          ? AppLocaleController.instance.languageCode
          : engineIdFor(deviceLocale());

  /// يختار أقرب لغة متاحة على محرّك الجهاز دون ادّعاء لغة غير مثبتة.
  String matchAvailable({
    required String preferred,
    required List<String> available,
  }) {
    if (available.isEmpty) return preferred;
    final device = preferredListenCode();
    final candidates = <String>[
      preferred,
      device,
      _languageOnly(preferred),
      _languageOnly(device),
      'ar_SA',
      'ar',
      'en_US',
      'en',
    ];
    for (final candidate in candidates) {
      final hit = _bestMatch(candidate, available);
      if (hit != null) return hit;
    }
    return available.first;
  }

  String speakCodeForText({
    required String text,
    String? recognizedLocaleId,
    required List<String> availableTts,
  }) {
    if (recognizedLocaleId != null && recognizedLocaleId.trim().isNotEmpty) {
      return matchAvailable(
        preferred: recognizedLocaleId.replaceAll('-', '_'),
        available: availableTts,
      );
    }
    final script = _scriptHint(text);
    return matchAvailable(
      preferred: script ?? preferredListenCode(),
      available: availableTts,
    );
  }

  String? _scriptHint(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar';
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) return 'ru';
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) return 'zh';
    if (RegExp(r'[\u3040-\u30FF]').hasMatch(text)) return 'ja';
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi';
    if (RegExp(r'[A-Za-z]').hasMatch(text)) return 'en';
    return null;
  }

  String _languageOnly(String code) =>
      code.replaceAll('-', '_').split('_').first;

  String? _bestMatch(String wanted, List<String> available) {
    final normalized = wanted.replaceAll('-', '_').toLowerCase();
    for (final item in available) {
      if (item.replaceAll('-', '_').toLowerCase() == normalized) return item;
    }
    final lang = _languageOnly(normalized);
    for (final item in available) {
      if (_languageOnly(item).toLowerCase() == lang) return item;
    }
    return null;
  }
}
