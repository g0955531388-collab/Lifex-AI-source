/// كشف أجسام محلي. تصنيف الصورة ليس كشفاً، وغياب النموذج ليس نتيجة وهمية.
library lifex_ai.features.accessibility.local_object_detector;

class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get hasBox =>
      right.isFinite &&
      left.isFinite &&
      bottom.isFinite &&
      top.isFinite &&
      right > left &&
      bottom > top;
}

class ObjectDetectionOutcome {
  const ObjectDetectionOutcome({
    required this.ran,
    required this.reasonAr,
    this.objects = const [],
  });

  final bool ran;
  final String reasonAr;
  final List<DetectedObject> objects;
}

/// لا يشغّل نموذجاً. إطارات الكاميرا لا تُمرَّر إلى نتيجة مخترعة.
class LocalObjectDetector {
  const LocalObjectDetector();

  static const notInstalledAr =
      'كاشف الأجسام غير محمّل. تصنيف الصورة ليس كشف أجسام، ولن أخترع جسماً أو مسافة.';

  ObjectDetectionOutcome run() => const ObjectDetectionOutcome(
        ran: false,
        reasonAr: notInstalledAr,
      );
}
