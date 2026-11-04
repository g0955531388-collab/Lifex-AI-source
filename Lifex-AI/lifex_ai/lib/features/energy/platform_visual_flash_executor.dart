/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس — ومضة الكاميرا
/// الملف: platform_visual_flash_executor.dart
/// الوصف: تنفيذ حقيقي لومضة فلاش الكاميرا الخلفي.
/// =============================================================

import 'package:camera/camera.dart';

import '../accessibility/multi_sensory_alert_manager.dart';

class PlatformVisualFlashExecutor implements VisualFlashExecutor {
  PlatformVisualFlashExecutor({CameraController? controller})
      : _cameraController = controller;

  CameraController? _cameraController;

  @override
  Future<void> flashScreen({required int repeatCount}) async {
    // Screen flash is a UI overlay responsibility, not camera responsibility.
    // Implemented at UI layer in emergency screens.
    return;
  }

  @override
  Future<void> flashCameraLight({required int repeatCount}) async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }

      // Turn flash on for the specified repeat count.
      for (int i = 0; i < repeatCount; i++) {
        await _cameraController!.setFlashMode(FlashMode.torch);
        await Future.delayed(const Duration(milliseconds: 200));
        await _cameraController!.setFlashMode(FlashMode.off);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {
      // Gracefully fail if camera is unavailable or torch not supported.
    }
  }

  /// Initialize with a camera controller (optional).
  void setController(CameraController controller) {
    _cameraController = controller;
  }

  /// Clean up camera resources.
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
  }
}
