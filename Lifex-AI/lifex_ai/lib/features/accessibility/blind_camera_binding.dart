/// =============================================================
/// Lifex-AI — كاميرا المكفوفين
/// يربط التصنيف وقراءة النص بالمحرك القائم. بلا عائق مخترع وبلا فئة عملة.
/// =============================================================
library lifex_ai.features.accessibility.blind_camera_binding;

import '../vision/file_path_ocr_extractor.dart';
import 'assistive_vision_engine.dart';
import 'blind_camera_speech.dart';
import 'file_path_image_labeler.dart';
import 'text_and_currency_reader.dart';

typedef BlindPathLabels = Future<List<String>> Function(String path);
typedef BlindPathText = Future<String> Function(String path);

class BlindCameraBinding {
  const BlindCameraBinding._();

  static void register(
    AssistiveVisionEngine engine, {
    BlindPathLabels? labelsFromPath,
    BlindPathText? textFromPath,
  }) {
    final labels = labelsFromPath ?? const FilePathImageLabeler().labelsFromPath;
    final text = textFromPath ?? const FilePathOcrExtractor().extractFromPath;
    engine.registerHandler(
      AssistiveFeatureType.sceneDescription,
      (_, context) => _scene(labels, text, context),
    );
    engine.registerHandler(
      AssistiveFeatureType.textAndCurrencyReading,
      (_, context) => _text(text, context),
    );
  }

  static Future<AssistiveVisionResult> _scene(
    BlindPathLabels labelsFromPath,
    BlindPathText textFromPath,
    Map<String, dynamic> context,
  ) async {
    final path = '${context['imagePath'] ?? ''}'.trim();
    if (path.isEmpty) {
      return AssistiveVisionResult.failure(BlindCameraSpeech.noPathAr);
    }
    final found = await labelsFromPath(path);
    final languageCode = '${context['languageCode'] ?? 'ar'}';
    final includeText = context['includeText'] != false;
    final includeScene = context['includeScene'] != false;
    if (context['live'] == true) {
      final text = includeText ? await textFromPath(path) : '';
      return AssistiveVisionResult(
        success: BlindCameraSpeech.hasReading(labels: found, text: text),
        spokenMessageAr: BlindCameraSpeech.liveFrom(
          labels: found,
          text: text,
          languageCode: languageCode,
          includeScene: includeScene,
          includeText: includeText,
        ),
      );
    }
    return AssistiveVisionResult(
      success: BlindCameraSpeech.hasScene(found),
      spokenMessageAr: BlindCameraSpeech.sceneFromLabels(
        found,
        languageCode: languageCode,
      ),
    );
  }

  static Future<AssistiveVisionResult> _text(
    BlindPathText textFromPath,
    Map<String, dynamic> context,
  ) async {
    final target = context['targetType'];
    if (target == ReadingTargetType.currencyNote) {
      return AssistiveVisionResult.failure(BlindCameraSpeech.noCurrencyAr);
    }
    final path = '${context['imagePath'] ?? ''}'.trim();
    if (path.isEmpty) {
      return AssistiveVisionResult.failure(BlindCameraSpeech.noPathAr);
    }
    final text = await textFromPath(path);
    final languageCode = '${context['languageCode'] ?? 'ar'}';
    return AssistiveVisionResult(
      success: text.trim().isNotEmpty,
      spokenMessageAr: BlindCameraSpeech.textFromRaw(
        text,
        languageCode: languageCode,
      ),
    );
  }
}
