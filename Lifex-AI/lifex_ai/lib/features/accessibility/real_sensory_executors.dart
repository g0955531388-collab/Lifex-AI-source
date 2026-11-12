/// اهتزاز عبر حزمة vibration، وومضة شاشة حمراء عبر Overlay.
/// فلاش الكاميرا الخلفي يبقى صامتاً لأن torch_light غير مضافة.
library lifex_ai.features.accessibility.real_sensory_executors;

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../core/error_handler.dart';
import 'multi_sensory_alert_manager.dart';

class VibrationPackageExecutor implements VibrationExecutor {
  @override
  Future<void> vibrate({required List<int> patternMs}) async {
    try {
      if (!await Vibration.hasVibrator()) return;
      if (patternMs.isEmpty) {
        await Vibration.vibrate(duration: 200);
        return;
      }
      // أندرويد يقرأ الخانة الأولى انتظاراً. الصفر يُبقي أول مدة اهتزازاً.
      final timings = <int>[0, ...patternMs];
      if (await Vibration.hasAmplitudeControl()) {
        await Vibration.vibrate(
          pattern: timings,
          intensities: [
            for (var i = 0; i < timings.length; i++) i.isOdd ? 255 : 0,
          ],
        );
      } else {
        await Vibration.vibrate(pattern: timings);
      }
    } catch (error, stackTrace) {
      ErrorHandler.instance.report(
        'VIBRATION_FAILED',
        'تعذّر اهتزاز الجهاز.',
        sourceModule: 'real_sensory_executors',
        severity: ErrorSeverity.warning,
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class ScreenFlashExecutor implements VisualFlashExecutor {
  ScreenFlashExecutor({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  static const Color _alertColor = Color(0xFFD50000);
  static const Duration _flashOn = Duration(milliseconds: 250);
  static const Duration _flashOff = Duration(milliseconds: 250);

  @override
  Future<void> flashScreen({required int repeatCount}) async {
    final context = navigatorKey.currentContext;
    if (context == null || repeatCount <= 0) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    for (var i = 0; i < repeatCount; i++) {
      final entry = OverlayEntry(
        builder: (_) => const IgnorePointer(
          child: ColoredBox(color: _alertColor),
        ),
      );
      overlay.insert(entry);
      await Future<void>.delayed(_flashOn);
      if (entry.mounted) entry.remove();
      if (i < repeatCount - 1) {
        await Future<void>.delayed(_flashOff);
      }
    }
  }

  @override
  Future<void> flashCameraLight({required int repeatCount}) async {
    // torch_light غير مضافة. لا ومضة خلفية ولا استثناء.
  }
}
