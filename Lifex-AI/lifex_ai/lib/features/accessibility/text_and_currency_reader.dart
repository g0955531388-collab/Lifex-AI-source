/// =============================================================
/// Lifex-AI — مساعدة المكفوفين وضعاف البصر
/// الملف: text_and_currency_reader.dart
/// المسار: lib/features/accessibility/text_and_currency_reader.dart
/// الوصف: قراءة أي نص عام (لافتة، رسالة، منتج) أو التعرّف على فئة
/// عملة ورقية بصوت عالٍ. مستقل عن medical_ocr_reader.dart المخصص
/// للنصوص الطبية فقط.
/// =============================================================
library;

import 'assistive_vision_engine.dart';

enum ReadingTargetType { generalText, currencyNote }

/// عقد أي محرك تعرّف بصري فعلي للنصوص والعملات.
abstract class TextAndCurrencyModel {
  Future<String?> extractGeneralText(List<int> imageBytes);
  Future<String?> identifyCurrencyNote(List<int> imageBytes);
}

/// محرك قراءة النصوص والعملات.
class TextAndCurrencyReader {
  TextAndCurrencyReader({required this.model});

  final TextAndCurrencyModel model;

  void registerWithAssistiveEngine(AssistiveVisionEngine engine) {
    engine.registerHandler(
      AssistiveFeatureType.textAndCurrencyReading,
      (imageInput, context) async {
        final imageBytes = imageInput as List<int>;
        final targetType =
            context['targetType'] as ReadingTargetType? ?? ReadingTargetType.generalText;
        return read(imageBytes, targetType);
      },
    );
  }

  Future<AssistiveVisionResult> read(
    List<int> imageBytes,
    ReadingTargetType targetType,
  ) async {
    if (targetType == ReadingTargetType.currencyNote) {
      final currencyLabel = await model.identifyCurrencyNote(imageBytes);
      if (currencyLabel == null) {
        return const AssistiveVisionResult(
          success: false,
          spokenMessageAr: 'تعذّر التعرّف على فئة العملة. حاول تثبيت '
              'الورقة النقدية بشكل أوضح أمام الكاميرا.',
        );
      }
      return AssistiveVisionResult(
        success: true,
        spokenMessageAr: 'هذه ورقة نقدية فئة $currencyLabel.',
      );
    }

    final text = await model.extractGeneralText(imageBytes);
    if (text == null || text.trim().isEmpty) {
      return const AssistiveVisionResult(
        success: false,
        spokenMessageAr: 'لم يتم العثور على نص واضح في الصورة.',
      );
    }

    return AssistiveVisionResult(success: true, spokenMessageAr: text);
  }
}
