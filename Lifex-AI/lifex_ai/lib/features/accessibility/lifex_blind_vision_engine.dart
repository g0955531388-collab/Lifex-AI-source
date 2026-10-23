/// تحليل مشهد المكفوفين. المحلي أولاً، والسحابة بموافقة، وبلا مفتاح في التطبيق.
library lifex_ai.features.accessibility.lifex_blind_vision_engine;

import 'dart:typed_data';

import '../../core/error_handler.dart';
import 'blind_scene_brief.dart';

/// نتيجة كشف حقيقية من نموذج الرؤية المحلي.
class BlindVisionResult {
  const BlindVisionResult({
    required this.description,
    required this.hasReliableDetection,
  });

  final String description;
  final bool hasReliableDetection;
}

/// يجب تنفيذ هذه الواجهة باستخدام نموذج محلي فعلي.
abstract interface class LocalVisionAnalyzer {
  Future<BlindVisionResult> analyze(Uint8List imageBytes);
}

/// تنفيذ اختياري عبر خادم موثوق يتصل بخدمة الرؤية السحابية.
/// لا تضع مفتاح Gemini السري داخل تطبيق Android.
abstract interface class CloudVisionAnalyzer {
  Future<String?> analyze(Uint8List imageBytes, String prompt);
}

/// لا نموذج كشف محمّل. البايتات لا تُحوَّل إلى أجسام.
class NoModelLocalVisionAnalyzer implements LocalVisionAnalyzer {
  const NoModelLocalVisionAnalyzer();

  @override
  Future<BlindVisionResult> analyze(Uint8List imageBytes) async {
    return const BlindVisionResult(
      description: '',
      hasReliableDetection: false,
    );
  }
}

/// لا خادم موثوق ولا مفتاح. الصورة لا تغادر الجهاز.
class ClosedCloudVisionAnalyzer implements CloudVisionAnalyzer {
  const ClosedCloudVisionAnalyzer();

  @override
  Future<String?> analyze(Uint8List imageBytes, String prompt) async {
    return null;
  }
}

class LifexBlindVisionEngine {
  LifexBlindVisionEngine({
    required this.localAnalyzer,
    this.cloudAnalyzer,
  });

  final LocalVisionAnalyzer localAnalyzer;
  final CloudVisionAnalyzer? cloudAnalyzer;

  static const String defaultPrompt =
      'صف بالعربية العناصر الواضحة في الصورة التي يحتاج '
      'المستخدم الكفيف إلى معرفتها. اذكر الأشخاص والأبواب '
      'والدرج والسيارات والعوائق الظاهرة. لا تخترع مسافة '
      'أو حركة أو اتجاهاً آمناً، ولا تستنتج هوية الأشخاص. '
      'اجعل الوصف مختصراً ومناسباً للنطق الصوتي.';

  static const noImageAr = 'لم تصل صورة صالحة للتحليل.';

  static const unsureAr =
      'لم أتمكن من تحديد المشهد بثقة. حرّك الكاميرا ببطء أو أعد المحاولة.';

  static const localUnavailableAr =
      'مصنّف الصورة المحلي لم يعد نتيجة على هذا الإطار. لن أخترع مشهداً.';

  /// الأولوية للمحلل المحلي. تُستخدم السحابة فقط عند السماح بذلك.
  Future<String> analyzeScene({
    required Uint8List imageBytes,
    bool allowCloud = false,
    String userPrompt = '',
  }) async {
    if (imageBytes.isEmpty) {
      return noImageAr;
    }
    try {
      final localResult = await localAnalyzer.analyze(imageBytes);
      if (localResult.hasReliableDetection &&
          localResult.description.trim().isNotEmpty) {
        return localResult.description.trim();
      }
    } catch (error, stackTrace) {
      ErrorHandler.instance.report(
        'BLIND_LOCAL_VISION_FAILED',
        'فشل المحلل المحلي. لم يُحسب ذلك كشفاً.',
        sourceModule: 'lifex_blind_vision_engine',
        severity: ErrorSeverity.warning,
        exception: error,
        stackTrace: stackTrace,
      );
    }
    if (allowCloud && cloudAnalyzer != null) {
      try {
        final prompt = userPrompt.trim().isEmpty
            ? defaultPrompt
            : userPrompt.trim();
        final cloudResult =
            await cloudAnalyzer!.analyze(imageBytes, prompt);
        if (cloudResult != null && cloudResult.trim().isNotEmpty) {
          return cloudResult.trim();
        }
      } catch (error, stackTrace) {
        ErrorHandler.instance.report(
          'BLIND_CLOUD_VISION_FAILED',
          'فشل المسار السحابي. الصورة لم تُعد مشهداً مؤكداً.',
          sourceModule: 'lifex_blind_vision_engine',
          severity: ErrorSeverity.warning,
          exception: error,
          stackTrace: stackTrace,
        );
      }
    }
    return unsureAr;
  }

  /// تصنيف إطار حي. البايتات الخام لا تُرسل، لأن تنسيق الكاميرا ليس صورة مشفّرة.
  /// [NoModelLocalVisionAnalyzer] يبقى الاحتياط لعقد البايتات، لا لنتيجة هذا المسار.
  Future<String> analyzeClassifiedFrame({
    required bool modelRan,
    required Iterable<SceneHit> hits,
    bool reportUnavailable = true,
  }) async {
    if (!modelRan) {
      if (reportUnavailable) {
        ErrorHandler.instance.report(
          'LOCAL_MODEL_UNAVAILABLE',
          'مصنّف الصورة المثبت لم يعد نتيجة. لم يُحسب ذلك كشفاً.',
          sourceModule: 'lifex_blind_vision_engine',
          severity: ErrorSeverity.warning,
        );
      }
      return localUnavailableAr;
    }
    return BlindSceneBrief.classificationSpeech(hits);
  }
}
