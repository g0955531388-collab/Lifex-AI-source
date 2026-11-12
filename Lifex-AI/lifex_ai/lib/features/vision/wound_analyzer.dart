/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: wound_analyzer.dart
/// المسار: lib/features/vision/wound_analyzer.dart
/// الوصف: محرك متابعة صور الجروح بعد العمليات أو الإصابات، لرصد مؤشرات
/// بصرية عامة (احمرار، تورم ظاهري، تغيّر المساحة) قد تستدعي مراجعة طبية.
///
/// ⚠️ لا يشخّص هذا المحرك التهاباً أو عدوى؛ فقط يرصد مؤشرات بصرية ويوجّه
/// دائماً لمراجعة طبية عند أي مؤشر مقلق. القرار الطبي النهائي للطبيب فقط.
/// =============================================================
library;

import 'smart_vision_engine.dart';

/// عقد لمحرك تحليل صورة جرح فعلي (رؤية حاسوبية) خلف الكواليس.
abstract class WoundImageFeatureExtractor {
  Future<WoundImageFeatures> extractFeatures(List<int> imageBytes);
}

class WoundImageFeatures {
  final double approximateAreaPixels;

  /// نسبة تقريبية (0.0 - 1.0) من مساحة الجرح تحمل احمراراً واضحاً.
  final double rednessRatio;

  /// هل يظهر إفراز/سائل واضح في الصورة (يُستدل عليه من نمط لوني معيّن)؟
  final bool visibleDischarge;

  const WoundImageFeatures({
    required this.approximateAreaPixels,
    required this.rednessRatio,
    required this.visibleDischarge,
  });
}

/// سجل صورة جرح واحد ضمن تتبّع زمني لنفس الجرح.
class WoundSnapshotRecord {
  final DateTime capturedAt;
  final WoundImageFeatures features;

  const WoundSnapshotRecord({
    required this.capturedAt,
    required this.features,
  });
}

/// محرك تحليل ومتابعة صور الجروح عبر الزمن.
class WoundAnalyzer {
  WoundAnalyzer({required this.featureExtractor});

  final WoundImageFeatureExtractor featureExtractor;

  final Map<String, List<WoundSnapshotRecord>> _snapshotsByWound = {};

  /// عتبات بسيطة لاعتبار مؤشر بصري "مقلقاً" ويستدعي تنبيهاً أوضح.
  static const double _concerningRednessRatio = 0.35;

  void registerWithVisionEngine(SmartVisionEngine engine) {
    engine.registerHandler(
      VisionTaskType.woundAnalysis,
      (imageBytes, context) {
        final woundId = context['woundId'] as String? ?? 'default_wound';
        return analyzeAndTrack(woundId: woundId, imageBytes: imageBytes);
      },
    );
  }

  Future<VisionResult> analyzeAndTrack({
    required String woundId,
    required List<int> imageBytes,
  }) async {
    final features = await featureExtractor.extractFeatures(imageBytes);
    final history = _snapshotsByWound.putIfAbsent(woundId, () => []);

    final previous = history.isNotEmpty ? history.last : null;

    history.add(WoundSnapshotRecord(
      capturedAt: DateTime.now(),
      features: features,
    ));

    final isConcerning = features.rednessRatio >= _concerningRednessRatio ||
        features.visibleDischarge;

    String healingTrendAr = 'هذه أول لقطة مسجّلة لهذا الجرح.';
    if (previous != null) {
      final areaShrinking =
          features.approximateAreaPixels < previous.features.approximateAreaPixels;
      healingTrendAr = areaShrinking
          ? 'مساحة الجرح الظاهرة تبدو أصغر مقارنة بآخر تسجيل، وهو مؤشر '
              'عام مطمئن، لكنه لا يغني عن المتابعة الطبية المعتادة.'
          : 'مساحة الجرح الظاهرة لم تصغر مقارنة بآخر تسجيل. يُفضّل '
              'مراجعة الطبيب المتابع للتأكد من سير الشفاء بشكل طبيعي.';
    }

    final summary = isConcerning
        ? '⚠️ رُصدت مؤشرات بصرية قد تستدعي انتباهاً (احمرار واضح و/أو '
            'إفراز ظاهر). يُنصح بمراجعة الطبيب أو الممرض المتابع في '
            'أقرب وقت مناسب.'
        : healingTrendAr;

    return VisionResult(
      success: true,
      extractedSummaryAr: summary,
      structuredData: {
        'woundId': woundId,
        'snapshotIndex': history.length - 1,
        'rednessRatio': features.rednessRatio,
        'visibleDischarge': features.visibleDischarge,
        'isConcerning': isConcerning,
      },
      confidence: 0.5,
      disclaimer:
          'هذا رصد آلي لمؤشرات بصرية عامة فقط وليس تشخيصاً لالتهاب أو '
          'عدوى الجرح. أي ألم متزايد أو حمّى أو إفراز بلون أو رائحة '
          'غير معتادة يستدعي التواصل الفوري مع الطبيب أو الطوارئ بغض '
          'النظر عن نتيجة هذا التحليل.',
    );
  }

  List<WoundSnapshotRecord> historyFor(String woundId) =>
      List.unmodifiable(_snapshotsByWound[woundId] ?? const []);
}
