/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: language_detector.dart
/// المسار: lib/features/voice/language_detector.dart
/// الوصف: اكتشاف لغة النص المُدخل لتوجيه بقية خط المعالجة (نطق، تحليل
/// أوامر) للغة الصحيحة تلقائياً.
///
/// ⚠️ توضيح نطاق: الكشف بنطاقات Unicode أدناه (_detectWithUnicodeHeuristic)
/// يميّز عربي/إنجليزي فقط بدقة معقولة، ولا يصلح لتمييز مئات اللغات
/// (فرنسي عن إسباني عن ألماني، مثلاً، كلها تستخدم نفس نطاق الحروف
/// اللاتينية). لدعم كشف لغة حقيقي لعشرات اللغات، يجب ربط [LanguageDetector]
/// بمزوّد فعلي مثل ML Kit Language Identification (حزمة
/// google_mlkit_language_id) عبر تنفيذ [MlBasedLanguageDetector] بدلاً
/// من الاعتماد على الكاشف البسيط الافتراضي وحده.
/// =============================================================
library;

/// اللغات القابلة للاكتشاف تلقائياً حالياً بالكاشف البسيط الافتراضي.
enum DetectedLanguage { arabic, english, unknown }

/// نتيجة اكتشاف اللغة مع درجة ثقة تقريبية.
class LanguageDetectionResult {
  final DetectedLanguage language;
  final double confidence;

  /// كود اللغة الفعلي بمعيار ISO 639-1 (مثل 'fr', 'es', 'de') — يُملأ
  /// فقط عند استخدام كاشف حقيقي متعدد اللغات (MlBasedLanguageDetector)؛
  /// يبقى null مع الكاشف البسيط الذي يكتشف عربي/إنجليزي فقط.
  final String? preciseLanguageCode;

  const LanguageDetectionResult({
    required this.language,
    required this.confidence,
    this.preciseLanguageCode,
  });
}

/// عقد أي محرك تعرّف لغة حقيقي متعدد اللغات (عشرات/مئات اللغات)، يُنفَّذ
/// عبر حزمة ML Kit Language Identification أو ما يعادلها.
abstract class MlBasedLanguageDetector {
  /// يُرجع كود اللغة الأكثر احتمالاً (ISO 639-1) ودرجة الثقة، أو null
  /// إن تعذّر التحديد بثقة كافية.
  Future<({String languageCode, double confidence})?> identifyLanguage(
    String text,
  );
}

/// كاشف اللغة المركزي — يحاول أولاً كاشفاً حقيقياً متعدد اللغات إن أُرفق
/// (عبر attachMlDetector)، ويرجع لمنطق Unicode البسيط (عربي/إنجليزي فقط)
/// كخط احتياطي دائماً متاح بلا إنترنت أو مكتبات إضافية.
class LanguageDetector {
  LanguageDetector._internal();
  static final LanguageDetector instance = LanguageDetector._internal();

  MlBasedLanguageDetector? _mlDetector;

  void attachMlDetector(MlBasedLanguageDetector detector) {
    _mlDetector = detector;
  }

  static final RegExp _arabicCharPattern = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _latinCharPattern = RegExp(r'[a-zA-Z]');

  /// اكتشاف لغة نص مُعطى. يحاول أولاً الكاشف الحقيقي متعدد اللغات إن
  /// وُجد، وإلا يرجع لمنطق Unicode البسيط (عربي/إنجليزي فقط).
  Future<LanguageDetectionResult> detect(String text) async {
    if (text.trim().isEmpty) {
      return const LanguageDetectionResult(
        language: DetectedLanguage.unknown,
        confidence: 0.0,
      );
    }

    if (_mlDetector != null) {
      final mlResult = await _mlDetector!.identifyLanguage(text);
      if (mlResult != null) {
        final isArabic = mlResult.languageCode == 'ar';
        final isEnglish = mlResult.languageCode == 'en';
        return LanguageDetectionResult(
          language: isArabic
              ? DetectedLanguage.arabic
              : isEnglish
                  ? DetectedLanguage.english
                  : DetectedLanguage.unknown,
          confidence: mlResult.confidence,
          preciseLanguageCode: mlResult.languageCode,
        );
      }
    }

    return _detectWithUnicodeHeuristic(text);
  }

  LanguageDetectionResult _detectWithUnicodeHeuristic(String text) {
    final arabicMatches = _arabicCharPattern.allMatches(text).length;
    final latinMatches = _latinCharPattern.allMatches(text).length;
    final totalRelevantChars = arabicMatches + latinMatches;

    if (totalRelevantChars == 0) {
      return const LanguageDetectionResult(
        language: DetectedLanguage.unknown,
        confidence: 0.0,
      );
    }

    if (arabicMatches >= latinMatches) {
      return LanguageDetectionResult(
        language: DetectedLanguage.arabic,
        confidence: arabicMatches / totalRelevantChars,
        preciseLanguageCode: 'ar',
      );
    }

    return LanguageDetectionResult(
      language: DetectedLanguage.english,
      confidence: latinMatches / totalRelevantChars,
      preciseLanguageCode: 'en',
    );
  }

  /// تحويل اللغة المكتشفة إلى كود محلي (Locale code) يُستخدم مع محركات
  /// النطق والتعرّف الصوتي. يُفضَّل استخدام
  /// [LanguageDetectionResult.preciseLanguageCode] مباشرة عند توفره
  /// (يدعم أي لغة)، وهذه الدالة احتياطية للحالات البسيطة عربي/إنجليزي فقط.
  String localeCodeFor(DetectedLanguage language) {
    switch (language) {
      case DetectedLanguage.arabic:
        return 'ar';
      case DetectedLanguage.english:
        return 'en';
      case DetectedLanguage.unknown:
        return 'ar'; // العربية هي اللغة الافتراضية للنظام
    }
  }
}
