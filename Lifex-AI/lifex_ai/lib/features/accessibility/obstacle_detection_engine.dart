/// =============================================================
/// Lifex-AI — مساعدة المكفوفين وضعاف البصر
/// الملف: obstacle_detection_engine.dart
/// المسار: lib/features/accessibility/obstacle_detection_engine.dart
/// الوصف: كشف العوائق القريبة من مسار المستخدم وتصنيفها (أشخاص، حيوانات،
/// سيارات، أبواب، درج، حفر، مياه واقفة)، مع تنبيه صوتي فوري للأقرب خطراً.
///
/// ⚠️ هذا النظام يعتمد على كاميرا الهاتف العادية فقط (بلا مستشعر عمق
/// مخصص LiDAR)، لذا تقدير المسافة **تقريبي** وليس دقيقاً بالسنتيمتر.
/// يجب أن يبقى المستخدم يستخدم العصا البيضاء أو أي وسيلة سلامة أساسية
/// دائماً بالتوازي مع هذه الأداة.
///
/// ⚠️ استبعاد متعمَّد ومهم: هذا النظام **لا يكشف** الحريق أو الدخان أو
/// الأسلاك الكهربائية الحية، لأن كاميرا الموبايل العادية بلا حسّاس
/// حراري (Thermal) لا تستطيع تمييز سلك كهربائي "حي" عن سلك مقطوع بصرياً،
/// ولا تستطيع كشف حريق مبكر بثقة كافية قبل ظهور دخان/لهب واضحين للعين
/// المجردة أصلاً. ادّعاء القدرة على كشف هذه المخاطر قد يعطي المستخدم
/// ثقة زائفة تعرّضه لخطر جسدي حقيقي. لحماية حقيقية من هذه المخاطر، يُنصح
/// دائماً باستخدام كاشف دخان منزلي معتمد وفاحص كهربائي مؤهل بدلاً من أي
/// تطبيق كاميرا.
/// =============================================================
library;

import 'assistive_vision_engine.dart';

enum ObstacleUrgency { far, approaching, immediate }

/// فئات العوائق القابلة للكشف بثقة بصرية معقولة عبر كاميرا موبايل عادية
/// فقط. أي فئة غير مذكورة هنا عمداً (حريق/دخان/أسلاك كهربائية) مستبعدة
/// لعدم إمكانية كشفها بأمان كافٍ بهذه التقنية — راجع التوضيح أعلى الملف.
enum ObstacleCategory {
  person,
  animal,
  vehicle,
  door,
  stairsDown,
  stairsUp,
  hole,
  standingWater,
  furniture,
  other,
}

class DetectedObstacle {
  final String labelAr; // مثال: "شخص"، "كرسي"، "درجة سلّم لأسفل"
  final ObstacleCategory category;
  final ObstacleUrgency urgency;
  final String relativeDirectionAr; // "أمامك مباشرة"، "على يمينك"...

  const DetectedObstacle({
    required this.labelAr,
    required this.category,
    required this.urgency,
    required this.relativeDirectionAr,
  });
}

/// عقد أي محرك رؤية حاسوبية فعلي يكتشف العوائق من إطار كاميرا حي.
abstract class ObstacleDetectionModel {
  Future<List<DetectedObstacle>> detectObstacles(List<int> frameBytes);
}

/// محرك كشف العوائق.
class ObstacleDetectionEngine {
  ObstacleDetectionEngine({required this.model});

  final ObstacleDetectionModel model;

  void registerWithAssistiveEngine(AssistiveVisionEngine engine) {
    engine.registerHandler(
      AssistiveFeatureType.obstacleDetection,
      (frameInput, context) async {
        final frameBytes = frameInput as List<int>;
        return analyzeFrame(frameBytes);
      },
    );
  }

  Future<AssistiveVisionResult> analyzeFrame(List<int> frameBytes) async {
    final obstacles = await model.detectObstacles(frameBytes);

    if (obstacles.isEmpty) {
      return const AssistiveVisionResult(
        success: true,
        spokenMessageAr: 'الطريق يبدو خالياً من العوائق الظاهرة أمامك.',
      );
    }

    // درج لأسفل وحفر ومياه واقفة تُعطى أولوية أعلى دائماً حتى لو صُنِّفت
    // "approaching" فقط، لأن نتيجة الخطأ فيها (سقوط) أخطر من تجاهل شخص
    // أو غرض ثابت.
    const highRiskCategories = {
      ObstacleCategory.stairsDown,
      ObstacleCategory.hole,
      ObstacleCategory.standingWater,
    };

    final sorted = List<DetectedObstacle>.from(obstacles)
      ..sort((a, b) {
        final aBoosted = highRiskCategories.contains(a.category);
        final bBoosted = highRiskCategories.contains(b.category);
        if (aBoosted != bBoosted) return aBoosted ? -1 : 1;
        return b.urgency.index.compareTo(a.urgency.index);
      });

    final mostUrgent = sorted.first;

    final urgencyPhrase = mostUrgent.urgency == ObstacleUrgency.immediate
        ? 'تنبيه: '
        : mostUrgent.urgency == ObstacleUrgency.approaching
            ? 'انتبه، '
            : '';

    final message = '$urgencyPhrase${mostUrgent.labelAr} '
        '${mostUrgent.relativeDirectionAr}.';

    return AssistiveVisionResult(success: true, spokenMessageAr: message);
  }
}
