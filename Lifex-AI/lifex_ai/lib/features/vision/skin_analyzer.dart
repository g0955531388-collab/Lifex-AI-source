/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: skin_analyzer.dart
/// المسار: lib/features/vision/skin_analyzer.dart
/// الوصف: محرك متابعة صور الجلد بمرور الوقت (مثلاً شامة أو طفح جلدي)
/// عبر تسجيل صور دورية ورصد التغيرات الظاهرة (اللون، الحجم التقريبي).
///
/// ⚠️ هذا المحرك لا يشخّص أي حالة جلدية (بما فيها سرطان الجلد) إطلاقاً.
/// أقصى ما يفعله هو رصد "وجود تغيّر ملحوظ" وتوجيه المستخدم لطبيب جلدية.
/// أي صياغة توحي بتشخيص هنا تخالف سياسات المتاجر الصحية وتُرفض عمداً.
/// =============================================================
library;

import 'smart_vision_engine.dart';

/// عقد بسيط لأي محرك تحليل صورة فعلي (رؤية حاسوبية) يُستخدم خلف
/// الكواليس لاستخراج خصائص بصرية أولية من صورة الجلد.
abstract class SkinImageFeatureExtractor {
  /// يُرجع خصائص مبسّطة: مساحة تقريبية بالبكسل، ولون سائد كنص Hex.
  Future<SkinImageFeatures> extractFeatures(List<int> imageBytes);
}

class SkinImageFeatures {
  final double approximateAreaPixels;
  final String dominantColorHex;

  const SkinImageFeatures({
    required this.approximateAreaPixels,
    required this.dominantColorHex,
  });
}

/// سجل صورة جلد واحد ضمن تتبّع زمني لنفس المنطقة.
class SkinSnapshotRecord {
  final DateTime capturedAt;
  final SkinImageFeatures features;

  const SkinSnapshotRecord({
    required this.capturedAt,
    required this.features,
  });
}

/// محرك تحليل ومتابعة صور الجلد عبر الزمن لنفس المنطقة على الجسم.
class SkinAnalyzer {
  SkinAnalyzer({required this.featureExtractor});

  final SkinImageFeatureExtractor featureExtractor;

  /// سجل اللقطات لكل "منطقة متابعة" (areaId يحدده المستخدم، مثلاً
  /// "شامة الذراع اليمنى")، يُخزَّن هنا في الذاكرة فقط؛ التخزين الدائم
  /// يُضاف لاحقاً في طبقة بيانات منفصلة.
  final Map<String, List<SkinSnapshotRecord>> _snapshotsByArea = {};

  void registerWithVisionEngine(SmartVisionEngine engine) {
    engine.registerHandler(
      VisionTaskType.skinAnalysis,
      (imageBytes, context) {
        final areaId = context['areaId'] as String? ?? 'default_area';
        return analyzeAndTrack(areaId: areaId, imageBytes: imageBytes);
      },
    );
  }

  /// تحليل صورة جديدة لمنطقة معيّنة ومقارنتها بآخر لقطة مسجّلة لنفس
  /// المنطقة، إن وُجدت.
  Future<VisionResult> analyzeAndTrack({
    required String areaId,
    required List<int> imageBytes,
  }) async {
    final features = await featureExtractor.extractFeatures(imageBytes);
    final history = _snapshotsByArea.putIfAbsent(areaId, () => []);

    SkinSnapshotRecord? previous = history.isNotEmpty ? history.last : null;

    history.add(SkinSnapshotRecord(
      capturedAt: DateTime.now(),
      features: features,
    ));

    if (previous == null) {
      return VisionResult(
        success: true,
        extractedSummaryAr:
            'تم تسجيل أول لقطة متابعة لهذه المنطقة. ستتم مقارنة أي صورة '
            'قادمة بها لرصد أي تغيّر ملحوظ بمرور الوقت.',
        structuredData: {
          'areaId': areaId,
          'snapshotIndex': 0,
        },
        confidence: 1.0,
      );
    }

    final areaChangeRatio = _relativeChange(
      previous.features.approximateAreaPixels,
      features.approximateAreaPixels,
    );
    final colorChanged =
        previous.features.dominantColorHex != features.dominantColorHex;

    final notableChange = areaChangeRatio > 0.2 || colorChanged;

    final summary = notableChange
        ? 'تم رصد تغيّر ملحوظ في المظهر العام للمنطقة مقارنة باللقطة '
            'السابقة (${previous.capturedAt.toLocal()}). يُنصح بمراجعة '
            'طبيب جلدية لتقييم الحالة.'
        : 'لم يُرصد تغيّر كبير مقارنة باللقطة السابقة. تابع المراقبة '
            'الدورية كالمعتاد.';

    return VisionResult(
      success: true,
      extractedSummaryAr: summary,
      structuredData: {
        'areaId': areaId,
        'snapshotIndex': history.length - 1,
        'areaChangeRatio': areaChangeRatio,
        'colorChanged': colorChanged,
        'notableChange': notableChange,
      },
      confidence: 0.5,
      disclaimer:
          'هذا رصد آلي لتغيّرات بصرية بسيطة فقط وليس تشخيصاً لأي حالة '
          'جلدية، بما في ذلك الأورام الجلدية. أي تغيّر في شامة أو بقعة '
          'جلدية يستحق دائماً تقييماً من طبيب جلدية مختص بغض النظر عن '
          'نتيجة هذا التحليل.',
    );
  }

  double _relativeChange(double oldValue, double newValue) {
    if (oldValue == 0) return newValue == 0 ? 0.0 : 1.0;
    return (newValue - oldValue).abs() / oldValue;
  }

  /// استرجاع كامل السجل الزمني لمنطقة متابعة معيّنة (لعرضها في واجهة
  /// "الجدول الزمني" مثلاً).
  List<SkinSnapshotRecord> historyFor(String areaId) =>
      List.unmodifiable(_snapshotsByArea[areaId] ?? const []);
}
