/// =============================================================
/// Lifex-AI — التصوير الطبي والأشعة
/// الملف: imaging_ai_comparison_engine.dart
/// المسار: lib/features/medical_imaging/imaging_ai_comparison_engine.dart
/// الوصف: مقارنة بصرية أولية بين صورتين لنفس المنطقة عبر الزمن، لرصد
/// وجود تغيّر ظاهر فقط — وليس تفسيراً إشعاعياً للصورة.
///
/// ⚠️ لا يقرأ هذا المحرك الصورة إشعاعياً ولا يشخّص أي حالة؛ فقط يقارن
/// خصائص بصرية عامة (سطوع/تباين تقريبي) بين لقطتين ويحيل التفسير الفعلي
/// دائماً لطبيب الأشعة المختص.
/// =============================================================
library;

import 'patient_imaging_archive.dart';

class ImageComparisonFeatures {
  final double averageBrightness;
  final double contrastEstimate;

  const ImageComparisonFeatures({
    required this.averageBrightness,
    required this.contrastEstimate,
  });
}

abstract class ImagingFeatureExtractor {
  Future<ImageComparisonFeatures> extractFeatures(String storageReference);
}

class ImagingComparisonResult {
  final bool hasNotableDifference;
  final String summaryAr;
  final String disclaimer;

  const ImagingComparisonResult({
    required this.hasNotableDifference,
    required this.summaryAr,
    this.disclaimer =
        'هذه مقارنة بصرية عامة تلقائية فقط ولا تُعد قراءة إشعاعية أو '
        'تشخيصاً. يجب أن يُقيَّم أي فحص تصويري من قِبل طبيب أشعة مختص.',
  });
}

/// محرك مقارنة الصور الطبية عبر الزمن.
class ImagingAiComparisonEngine {
  ImagingAiComparisonEngine({required this.featureExtractor});

  final ImagingFeatureExtractor featureExtractor;

  static const double _brightnessChangeThreshold = 0.15;

  Future<ImagingComparisonResult> compareTwoRecords(
    PatientImagingRecord older,
    PatientImagingRecord newer,
  ) async {
    final oldFeatures =
        await featureExtractor.extractFeatures(older.storageReference);
    final newFeatures =
        await featureExtractor.extractFeatures(newer.storageReference);

    final brightnessDiff =
        (newFeatures.averageBrightness - oldFeatures.averageBrightness).abs();

    final notable = brightnessDiff >= _brightnessChangeThreshold;

    return ImagingComparisonResult(
      hasNotableDifference: notable,
      summaryAr: notable
          ? 'رُصد فرق بصري ملحوظ بين الصورتين. يُنصح بمراجعة طبيب الأشعة '
              'لتقييم دلالة هذا الفرق سريرياً.'
          : 'لا يوجد فرق بصري كبير ظاهر بين الصورتين بناءً على هذه المقارنة '
              'الأولية.',
    );
  }
}
