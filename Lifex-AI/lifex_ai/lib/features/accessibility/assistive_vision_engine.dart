/// =============================================================
/// Lifex-AI — مساعدة المكفوفين وضعاف البصر
/// الملف: assistive_vision_engine.dart
/// المسار: lib/features/accessibility/assistive_vision_engine.dart
/// الوصف: المحرك المركزي الموجّه لكل ميزات المساعدة البصرية — وصف
/// المشهد، كشف العوائق، قراءة النصوص والعملات، والتعلّم الشخصي. يعمل
/// بالتكامل مع voice_engine.dart (للنطق الفوري) وsmart_vision_engine.dart
/// (كبنية معالجة صور عامة)، دون تكرار منطقهما.
///
/// ⚠️ حد أمان جوهري: هذه الأداة **مساعدة إضافية** ولا تُغني أبداً عن
/// العصا البيضاء أو كلب الإرشاد أو التدريب على التنقل الآمن. يجب أن
/// تُعرض هذه الرسالة للمستخدم بوضوح عند أول استخدام، وألا تُقدَّم الأداة
/// أبداً كبديل كامل عن وسائل السلامة المعتادة، خصوصاً في الشارع وعبور
/// الطرق.
/// =============================================================
library;

import '../../core/error_handler.dart';

enum AssistiveFeatureType {
  sceneDescription,
  obstacleDetection,
  textAndCurrencyReading,
  personalizedRecognition,
}

/// نتيجة موحّدة لأي ميزة مساعدة بصرية — تُصاغ دائماً كنص جاهز للنطق
/// الفوري عبر voice_engine.dart.
class AssistiveVisionResult {
  final bool success;
  final String spokenMessageAr;
  final String safetyDisclaimer;

  const AssistiveVisionResult({
    required this.success,
    required this.spokenMessageAr,
    this.safetyDisclaimer =
        'هذه أداة مساعدة إضافية ولا تغني عن العصا البيضاء أو كلب الإرشاد '
        'أو الحذر المعتاد، خصوصاً عند عبور الطرق.',
  });

  factory AssistiveVisionResult.failure(String reasonAr) =>
      AssistiveVisionResult(success: false, spokenMessageAr: reasonAr);
}

typedef AssistiveFeatureHandler = Future<AssistiveVisionResult> Function(
  Object imageOrFrameInput,
  Map<String, dynamic> context,
);

/// المحرك المركزي لمساعدة المكفوفين وضعاف البصر.
class AssistiveVisionEngine {
  AssistiveVisionEngine._internal();
  static final AssistiveVisionEngine instance =
      AssistiveVisionEngine._internal();

  final Map<AssistiveFeatureType, AssistiveFeatureHandler> _handlers = {};

  void registerHandler(
    AssistiveFeatureType type,
    AssistiveFeatureHandler handler,
  ) {
    _handlers[type] = handler;
  }

  /// معالجة إطار كاميرا واحد عبر الميزة المطلوبة، مع رجوع فوري بنتيجة
  /// جاهزة للنطق الصوتي.
  Future<AssistiveVisionResult> process({
    required Object imageOrFrameInput,
    required AssistiveFeatureType type,
    Map<String, dynamic>? context,
  }) async {
    final handler = _handlers[type];
    if (handler == null) {
      ErrorHandler.instance.report(
        'ASSISTIVE_VISION_NO_HANDLER',
        'لا يوجد محرك فرعي مسجَّل لميزة: ${type.name}',
        sourceModule: 'assistive_vision_engine',
        severity: ErrorSeverity.warning,
      );
      return AssistiveVisionResult.failure(
        'هذه الميزة غير متاحة حالياً.',
      );
    }

    try {
      return await handler(imageOrFrameInput, context ?? {});
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'ASSISTIVE_VISION_PROCESSING_FAILED',
        'فشلت معالجة إطار الكاميرا لميزة ${type.name}.',
        sourceModule: 'assistive_vision_engine',
        exception: e,
        stackTrace: stackTrace,
      );
      return AssistiveVisionResult.failure(
        'تعذّرت معالجة الصورة. حاول توجيه الكاميرا مرة أخرى.',
      );
    }
  }
}
