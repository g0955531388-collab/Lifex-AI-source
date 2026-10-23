/// =============================================================
/// Lifex-AI — خدمات الترجمة
/// الملف: translation_service.dart
/// المسار: lib/services/translation/translation_service.dart
/// الوصف: يوفّر ترجمة نصوص ديناميكية لأي لغة يدعمها مزوّد ترجمة سحابي
/// (Google Translate/DeepL)، بدلاً من كتابة ملفات ARB يدوياً لكل لغة —
/// وهو المسار الواقعي الوحيد لدعم عشرات أو مئات اللغات فعلياً.
///
/// ⚠️ فرق مهم: نصوص الواجهة الثابتة (أزرار، عناوين) تبقى مُترجمة يدوياً
/// عبر ARB (نظام flutter_localizations) لأنها قليلة العدد وتحتاج دقة
/// عالية. هذا الملف مخصص للمحتوى الديناميكي فقط (ردود الذكاء الاصطناعي،
/// نصوص طبية طويلة، محتوى يتغيّر باستمرار) الذي يستحيل ترجمته يدوياً
/// مسبقاً لكل لغة ممكنة.
/// =============================================================
library lifex_ai.services.translation.translation_service;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/error_handler.dart';

class TranslationResult {
  final bool success;
  final String? translatedText;
  final String? errorMessageAr;

  const TranslationResult.success(this.translatedText)
      : success = true,
        errorMessageAr = null;

  const TranslationResult.failure(this.errorMessageAr)
      : success = false,
        translatedText = null;
}

/// عقد أي مزوّد ترجمة سحابي فعلي.
abstract class TranslationProvider {
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode, // null = اكتشاف تلقائي
  });
}

/// تنفيذ توضيحي لخدمة ترجمة Google Cloud Translation — يتطلب مفتاح API
/// حقيقي مرتبط بمشروع Google Cloud قبل الاستخدام الفعلي.
class GoogleTranslationProvider implements TranslationProvider {
  GoogleTranslationProvider({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  static const String _endpoint =
      'https://translation.googleapis.com/language/translate/v2';

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    if (apiKey.trim().isEmpty || apiKey.contains('placeholder')) {
      return const TranslationResult.failure(
        'الترجمة السحابية غير موصولة. النص يبقى كما كُتب.',
      );
    }
    try {
      final response = await _httpClient.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        body: {
          'q': text,
          'target': targetLanguageCode,
          if (sourceLanguageCode != null) 'source': sourceLanguageCode,
        },
      );

      if (response.statusCode != 200) {
        return const TranslationResult.failure('تعذّرت الترجمة حالياً.');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = decoded['data']?['translations']?[0]?['translatedText']
          as String?;

      if (translated == null) {
        return const TranslationResult.failure('لم تُرجع الخدمة ترجمة صالحة.');
      }

      return TranslationResult.success(translated);
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'TRANSLATION_FAILED',
        'فشلت عملية الترجمة الديناميكية.',
        sourceModule: 'translation_service',
        exception: e,
        stackTrace: stackTrace,
      );
      return const TranslationResult.failure('حدث خطأ أثناء الترجمة.');
    }
  }
}

/// خدمة الترجمة المركزية — تُستخدم من أي وحدة تحتاج ترجمة محتوى ديناميكي
/// (مثلاً ترجمة رد الذكاء الاصطناعي للغة المستخدم المفضّلة).
class TranslationService {
  TranslationService({required this.provider});

  final TranslationProvider provider;

  /// ذاكرة تخزين مؤقت بسيطة لتفادي ترجمة نفس النص مرتين (توفير تكلفة
  /// واستهلاك بيانات، مهم خصوصاً لمستخدمي الإنترنت المحدود).
  final Map<String, String> _cache = {};

  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
  }) async {
    final cacheKey = '$targetLanguageCode::$text';
    if (_cache.containsKey(cacheKey)) {
      return TranslationResult.success(_cache[cacheKey]);
    }

    final result = await provider.translate(
      text: text,
      targetLanguageCode: targetLanguageCode,
    );

    if (result.success && result.translatedText != null) {
      _cache[cacheKey] = result.translatedText!;
    }

    return result;
  }
}
