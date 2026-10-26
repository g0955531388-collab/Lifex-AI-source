/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: voice_locale_policy.dart
/// لغة الاستماع والنطق: لغة الجهاز أولاً، ثم لغة المتحدث إن عُرفت.
/// =============================================================
library lifex_ai.features.voice.voice_locale_policy;

import 'package:flutter/widgets.dart';

class RecognitionChoice {
  const RecognitionChoice({this.localeId, this.refusalAr});

  final String? localeId;
  final String? refusalAr;

  bool get accepted => localeId != null && (refusalAr == null || refusalAr!.isEmpty);
}

class VoiceLocalePolicy {
  const VoiceLocalePolicy();

  Locale deviceLocale() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      return const Locale('en');
    }
  }

  String engineIdFor(Locale locale) {
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }

  String preferredListenCode() => engineIdFor(deviceLocale());

  /// لغة التطبيق أولاً، ثم لغة الجهاز إن لم تتوفر على محرك التعرف.
  /// اكتشاف لغة الكلام تلقائياً غير مضمون إذا لم يدعمه المحرك.
  String listenCode({String? appLanguage}) {
    final chosen = appLanguage?.trim();
    if (chosen != null && chosen.isNotEmpty) return chosen;
    return preferredListenCode();
  }

  /// اختيار لغة التعرف. النطق العربي لا يُحتسب تعرّفاً إذا لم تُثبَّت حزمة اللغة.
  RecognitionChoice chooseRecognition({
    required String preferred,
    required List<String> available,
  }) {
    if (available.isEmpty) {
      return RecognitionChoice(localeId: preferred);
    }
    final localeId = matchAvailable(preferred: preferred, available: available);
    if (_languageOnly(localeId).toLowerCase() !=
        _languageOnly(preferred).toLowerCase()) {
      final shown = available.take(3).join('، ');
      return RecognitionChoice(
        refusalAr:
            'التعرف على «${_languageOnly(preferred)}» غير مثبت في محرك الكلام. '
            'النطق بهذه اللغة لا يعني أن التعرف متاح. المتاح: $shown.',
      );
    }
    return RecognitionChoice(localeId: localeId);
  }

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
    String? appLanguage,
    String? recognizedLocaleId,
    required List<String> availableTts,
  }) {
    final governing = appLanguage?.trim() ?? '';
    if (governing.isNotEmpty) {
      return matchAvailable(
        preferred: preferredTtsTag(governing),
        available: availableTts,
      );
    }
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

  /// ar-SA و en-US عند توفر الحزمة. إن غابت، يختار أقرب لغة مثبتة.
  String preferredTtsTag(String languageCode) {
    final code = languageCode.trim().toLowerCase();
    if (code.startsWith('ar')) return 'ar_SA';
    if (code.startsWith('en')) return 'en_US';
    return code.replaceAll('-', '_');
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
