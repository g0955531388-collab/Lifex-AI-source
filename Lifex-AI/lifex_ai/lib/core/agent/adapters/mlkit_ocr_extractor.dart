/// تنفيذ OcrTextExtractor عبر Google ML Kit.
/// البايتات تُكتب لملف مؤقت ثم تُقرأ بـ InputImage.fromFilePath،
/// لأن التوقيع extractText(List<int>) لا يحمل العرض أو الارتفاع أو الصيغة.
/// النص الفارغ فشل قراءة، وليس نجاحاً بنص مخترع.
library lifex_ai.core.agent.adapters.mlkit_ocr_extractor;

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/vision/medical_ocr_reader.dart';

class MlKitOcrExtractor implements OcrTextExtractor {
  const MlKitOcrExtractor({this.script = TextRecognitionScript.latin});

  /// السكربتات في الحزمة المثبتة: لاتيني، صيني، ديفاناغاري، ياباني، كوري.
  /// لا يوجد سكربت عربي في هذا الإصدار.
  final TextRecognitionScript script;

  @override
  Future<String> extractText(List<int> imageBytes) async {
    if (imageBytes.isEmpty) return '';
    final extension = _knownImageExtension(imageBytes);
    if (extension == null) return '';

    File? tempFile;
    final recognizer = TextRecognizer(script: script);
    try {
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/lifex_ocr_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await tempFile.writeAsBytes(imageBytes, flush: true);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  static String? _knownImageExtension(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    return null;
  }
}
