/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: smart_vision_engine.dart
/// المسار: lib/features/vision/smart_vision_engine.dart
/// الوصف: المحرك الرئيسي الذي ينسّق بين كل محركات الرؤية الفرعية
/// (قراءة نصوص طبية، قراءة أدوية، قراءة شاشات أجهزة، تحليل جلد/جروح).
/// هذا الملف لا يحتوي منطق معالجة صور بذاته — فقط توجيه ونتيجة موحدة.
///
/// ⚠️ لا يُستخدم أي محرك هنا لإصدار تشخيص. النتائج دائماً استرشادية
/// وتحتاج تأكيداً بشرياً (المستخدم أو طبيب) قبل اتخاذ أي قرار.
/// =============================================================
library;

import '../../core/error_handler.dart';

/// أنواع المهام التي يمكن لمحرك الرؤية معالجتها.
enum VisionTaskType {
  medicalTextOcr, // قراءة تقرير/وصفة مطبوعة أو مخطوطة
  medicineLabelRead, // قراءة عبوة دواء
  medicalDeviceScreenRead, // قراءة شاشة جهاز طبي (ضغط، سكر...)
  skinAnalysis, // تحليل صورة جلد
  woundAnalysis, // تحليل صورة جرح
}

/// نتيجة موحّدة لأي مهمة رؤية، بغض النظر عن المحرك الفرعي الذي أنتجها.
class VisionResult {
  final bool success;
  final String extractedSummaryAr;
  final Map<String, dynamic> structuredData;
  final double confidence; // 0.0 - 1.0
  final String disclaimer;

  const VisionResult({
    required this.success,
    required this.extractedSummaryAr,
    this.structuredData = const {},
    this.confidence = 0.0,
    this.disclaimer =
        'هذه قراءة آلية استرشادية وقد تحتوي أخطاء. يُرجى التحقق من '
        'المعلومة بمقارنتها بالمصدر الأصلي أو استشارة مختص عند الشك.',
  });

  factory VisionResult.failure(String reasonAr) => VisionResult(
        success: false,
        extractedSummaryAr: reasonAr,
        confidence: 0.0,
      );
}

/// توقيع دالة معالج رؤية فرعي — يستقبل مسار/بيانات الصورة (كـ bytes أو
/// مسار ملف مؤقت، يُحدَّد لاحقاً حسب حزمة الكاميرا المُختارة) ويُرجع نتيجة.
typedef VisionTaskHandler = Future<VisionResult> Function(
  List<int> imageBytes,
  Map<String, dynamic> context,
);

/// المحرك الرئيسي للرؤية الذكية — نقطة الدخول الموحدة لكل مهام الكاميرا
/// الطبية في التطبيق.
class SmartVisionEngine {
  SmartVisionEngine._internal();
  static final SmartVisionEngine instance = SmartVisionEngine._internal();

  final Map<VisionTaskType, VisionTaskHandler> _handlers = {};

  /// تسجيل معالج فرعي لنوع مهمة معيّن. يُستدعى من كل محرك فرعي
  /// (medical_ocr_reader.dart، medicine_reader.dart...) عند التهيئة.
  void registerHandler(VisionTaskType type, VisionTaskHandler handler) {
    _handlers[type] = handler;
  }

  /// معالجة صورة عبر المحرك الفرعي المناسب لنوع المهمة.
  Future<VisionResult> process({
    required VisionTaskType type,
    required List<int> imageBytes,
    Map<String, dynamic>? context,
  }) async {
    final handler = _handlers[type];

    if (handler == null) {
      ErrorHandler.instance.report(
        'VISION_NO_HANDLER_REGISTERED',
        'لا يوجد معالج رؤية مسجّل لنوع المهمة: ${type.name}',
        sourceModule: 'smart_vision_engine',
        severity: ErrorSeverity.warning,
      );
      return VisionResult.failure('تعذر معالجة هذا النوع من الصور حالياً.');
    }

    if (imageBytes.isEmpty) {
      return VisionResult.failure('لم يتم استلام أي بيانات صورة صالحة.');
    }

    try {
      return await handler(imageBytes, context ?? {});
    } catch (e, stack) {
      ErrorHandler.instance.report(
        'VISION_PROCESSING_FAILED',
        'فشلت معالجة الصورة: $e',
        sourceModule: 'smart_vision_engine',
        severity: ErrorSeverity.error,
        exception: e,
        stackTrace: stack,
      );
      return VisionResult.failure('حدث خطأ أثناء تحليل الصورة. يُرجى إعادة المحاولة.');
    }
  }

  bool hasHandlerFor(VisionTaskType type) => _handlers.containsKey(type);
}
