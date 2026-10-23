/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: file_path_ocr_extractor.dart
/// يقرأ نص وثيقة من مسار صورة التقطها المستخدم. النص الفارغ فشل قراءة.
/// =============================================================
library lifex_ai.features.vision.file_path_ocr_extractor;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FilePathOcrExtractor {
  const FilePathOcrExtractor();

  Future<String> extractFromPath(String path) async {
    if (path.trim().isEmpty) return '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(image);
      return result.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
