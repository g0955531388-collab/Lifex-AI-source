/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس
/// الملف: platform_vibration_executor.dart
/// المسار: lib/features/energy/platform_vibration_executor.dart
/// الوصف: تنفيذ حقيقي لاهتزاز الجهاز عبر حزمة vibration: ^1.8.4
/// يتيح تنبيه الطوارئ بدون تعطل التطبيق عند عدم توفر الاهتزاز.
/// =============================================================

import 'package:vibration/vibration.dart';
import '../accessibility/multi_sensory_alert_manager.dart';

class PlatformVibrationExecutor implements VibrationExecutor {
  @override
  Future<void> vibrate({required List<int> patternMs}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        return;
      }

      if (patternMs.isEmpty) {
        await Vibration.vibrate(duration: 300);
      } else {
        // استخدام النمط الأول من القائمة كمدة البث
        await Vibration.vibrate(duration: patternMs.first);
      }
    } catch (_) {
      // لا نرمي أخطاء للمستخدم؛ نتحقق من الفشل بسلام
    }
  }
}
