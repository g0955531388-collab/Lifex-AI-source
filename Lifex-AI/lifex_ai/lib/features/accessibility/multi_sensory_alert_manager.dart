/// =============================================================
/// Lifex-AI — إمكانية الوصول
/// الملف: multi_sensory_alert_manager.dart
/// المسار: lib/features/accessibility/multi_sensory_alert_manager.dart
/// الوصف: يضمن أن أي تنبيه حرج (طوارئ، تنبيه صحي) يصل للمستخدم عبر
/// أكثر من حاسة دائماً — صوت + اهتزاز + ومضة بصرية على الشاشة — وليس
/// صوتاً فقط. هذا ضروري للمستخدمين الصم أو ضعاف السمع الذين لن يسمعوا
/// أي تنبيه صوتي مهما كانت أهميته.
///
/// ⚠️ فجوة أمان مهمة: كل التنبيهات في النظام حالياً (health_alert_
/// dispatcher.dart, emergency_message_manager.dart) صوتية أو نصية فقط.
/// هذا الملف يضيف طبقة إلزامية فوقها لضمان وصول أي تنبيه "طوارئ" أو
/// "حرج" عبر الاهتزاز والومضة البصرية دائماً، بغض النظر عن قدرة
/// المستخدم على السمع.
/// =============================================================
library;

enum AlertSeverityForSenses { informational, important, critical }

/// عقد أي منفّذ اهتزاز فعلي (سيُربط لاحقاً بحزمة مثل vibration).
abstract class VibrationExecutor {
  Future<void> vibrate({required List<int> patternMs});
}

/// عقد أي منفّذ ومضة بصرية فعلية (مثلاً وميض الشاشة بالكامل بلون
/// تحذيري، أو وميض الفلاش الخلفي للجهاز).
abstract class VisualFlashExecutor {
  Future<void> flashScreen({required int repeatCount});
  Future<void> flashCameraLight({required int repeatCount});
}

/// مدير التنبيهات متعددة الحواس.
class MultiSensoryAlertManager {
  MultiSensoryAlertManager({
    required this.vibrationExecutor,
    required this.visualFlashExecutor,
  });

  final VibrationExecutor vibrationExecutor;
  final VisualFlashExecutor visualFlashExecutor;

  /// أنماط اهتزاز مختلفة حسب الخطورة — نمط "الطوارئ" أطول وأكثر إلحاحاً
  /// بشكل واضح مقارنة بتنبيه عادي.
  static const Map<AlertSeverityForSenses, List<int>> _vibrationPatterns = {
    AlertSeverityForSenses.informational: [200],
    AlertSeverityForSenses.important: [200, 100, 200],
    AlertSeverityForSenses.critical: [400, 100, 400, 100, 400, 100, 400],
  };

  /// إطلاق تنبيه كامل عبر كل الحواس المتاحة دفعة واحدة. تُستدعى هذه
  /// الدالة من health_alert_dispatcher.dart وemergency_manager.dart عند
  /// أي حدث طوارئ، بالتوازي مع التنبيه الصوتي العادي (وليس بديلاً عنه).
  Future<void> triggerAlert(AlertSeverityForSenses severity) async {
    final pattern = _vibrationPatterns[severity] ?? [200];
    await vibrationExecutor.vibrate(patternMs: pattern);

    if (severity == AlertSeverityForSenses.critical) {
      // للحالات الحرجة فقط: ومضة شاشة واضحة قد يلاحظها شخص قريب من
      // المستخدم حتى لو المستخدم نفسه لم ينتبه فوراً.
      await visualFlashExecutor.flashScreen(repeatCount: 5);
    } else if (severity == AlertSeverityForSenses.important) {
      await visualFlashExecutor.flashScreen(repeatCount: 2);
    }
  }
}
