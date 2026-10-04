/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس
/// الملف: platform_vibration_executor.dart
/// المسار: lib/features/energy/platform_vibration_executor.dart
/// الوصف: تنفيذ حقيقي لاهتزاز الجهاز عبر حزمة vibration.
/// يتيح تنبيه الطوارئ بدون تعطل التطبيق عند عدم توفر الاهتزاز.
/// =============================================================

import 'package:vibration/vibration.dart';

import '../accessibility/multi_sensory_alert_manager.dart';

class PlatformVibrationExecutor implements VibrationExecutor {
  PlatformVibrationExecutor({Vibration? vibration})
      : _vibration = vibration ?? Vibration();

  final Vibration _vibration;

  @override
  Future<void> vibrate({required List<int> patternMs}) async {
    try {
      final hasVibrator = await _vibration.hasVibrator();
      if (hasVibrator == false) {
        return;
      }

      final hasAmplitudeControl = await _vibration.hasAmplitudeControl();
      if (hasAmplitudeControl == true) {
        await _vibration.vibrate(amplitude: 255, duration: patternMs.isNotEmpty ? patternMs.first : 300);
        return;
      }

      await _vibration.vibrate(duration: patternMs.isNotEmpty ? patternMs.first : 300);
    } catch (_) {
      // لا نرمي أخطاء للمستخدم؛ نتحقق من الفشل بسلام.
    }
  }
}
