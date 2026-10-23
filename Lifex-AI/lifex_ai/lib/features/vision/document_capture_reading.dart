/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: document_capture_reading.dart
/// نص الوثيقة كما قرأه المحرك. الفراغ يبقى فراغاً. ليس تشخيصاً.
/// =============================================================
library lifex_ai.features.vision.document_capture_reading;

class DocumentCaptureReading {
  const DocumentCaptureReading({
    required this.storedAr,
    required this.read,
  });

  final String storedAr;
  final bool read;

  static const disclaimerAr =
      'النص المقروء من الوثيقة قد يخطئ. ليس تشخيصاً ولا نتيجة مختبر.';

  static const unreadAr =
      'لم يُقرأ نص واضح من الوثيقة. لن يُخترع محتوى.';

  factory DocumentCaptureReading.compose(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const DocumentCaptureReading(storedAr: unreadAr, read: false);
    }
    return DocumentCaptureReading(
      storedAr: 'نص مقروء من الوثيقة:\n$text\n$disclaimerAr',
      read: true,
    );
  }
}
