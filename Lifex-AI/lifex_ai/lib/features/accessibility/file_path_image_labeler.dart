/// =============================================================
/// Lifex-AI — كاميرا المكفوفين
/// تصنيف إطار من مسار صورة. القائمة الفارغة تبقى فارغة.
/// =============================================================
library lifex_ai.features.accessibility.file_path_image_labeler;

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class FilePathImageLabeler {
  const FilePathImageLabeler();

  static const confidenceThreshold = 0.5;

  Future<List<String>> labelsFromPath(String path) async {
    if (path.trim().isEmpty) return const [];
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
    );
    try {
      final image = InputImage.fromFilePath(path);
      final labels = await labeler.processImage(image);
      return [for (final label in labels) label.label];
    } catch (_) {
      return const [];
    } finally {
      await labeler.close();
    }
  }
}
