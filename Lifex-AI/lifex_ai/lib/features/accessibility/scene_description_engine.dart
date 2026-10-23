/// =============================================================
/// Lifex-AI — مساعدة المكفوفين وضعاف البصر
/// الملف: scene_description_engine.dart
/// المسار: lib/features/accessibility/scene_description_engine.dart
/// الوصف: وصف عام للمشهد المحيط بالمستخدم عند الطلب (مثلاً عبر أمر
/// صوتي "صف لي المكان")، لفهم السياق العام للمكان بخلاف كشف العوائق
/// اللحظي المستمر.
/// =============================================================
library;

import 'assistive_vision_engine.dart';

/// عقد أي محرك وصف مشهد فعلي (رؤية حاسوبية + توليد نص وصفي).
abstract class SceneDescriptionModel {
  Future<String> describeScene(List<int> imageBytes);
}

/// محرك وصف المشهد.
class SceneDescriptionEngine {
  SceneDescriptionEngine({required this.model});

  final SceneDescriptionModel model;

  void registerWithAssistiveEngine(AssistiveVisionEngine engine) {
    engine.registerHandler(
      AssistiveFeatureType.sceneDescription,
      (imageInput, context) async {
        final imageBytes = imageInput as List<int>;
        return describe(imageBytes);
      },
    );
  }

  Future<AssistiveVisionResult> describe(List<int> imageBytes) async {
    final description = await model.describeScene(imageBytes);

    if (description.trim().isEmpty) {
      return const AssistiveVisionResult(
        success: false,
        spokenMessageAr: 'تعذّر وصف المشهد الحالي بوضوح. حاول تثبيت '
            'الكاميرا للحظة والمحاولة مرة أخرى.',
      );
    }

    return AssistiveVisionResult(success: true, spokenMessageAr: description);
  }
}
