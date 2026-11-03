import 'dart:io';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// ML Kit base image labels are scene categories, not boxes, depth or
/// safety-certified obstacle detection.
class LiveCameraVisionEngine {
  LiveCameraVisionEngine()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  final ImageLabeler _labeler;
  bool _closed = false;

  static const Map<String, String> _arabicLabels = {
    'person': 'شخص', 'people': 'أشخاص', 'car': 'سيارة',
    'vehicle': 'مركبة', 'bicycle': 'دراجة', 'motorcycle': 'دراجة نارية',
    'bus': 'حافلة', 'truck': 'شاحنة', 'door': 'باب', 'stairs': 'درج',
    'staircase': 'سلم', 'chair': 'كرسي', 'table': 'طاولة',
    'couch': 'أريكة', 'furniture': 'أثاث', 'dog': 'كلب', 'cat': 'قط',
    'animal': 'حيوان', 'tree': 'شجرة', 'plant': 'نبات',
    'building': 'مبنى', 'street': 'شارع', 'road': 'طريق',
    'sidewalk': 'رصيف', 'traffic light': 'إشارة مرور',
    'bottle': 'زجاجة', 'cup': 'كوب', 'bag': 'حقيبة',
    'phone': 'هاتف', 'computer': 'حاسوب', 'screen': 'شاشة',
    'book': 'كتاب', 'food': 'طعام',
  };

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImage(CameraImage image, CameraDescription camera,
      DeviceOrientation orientation) {
    final int degrees;
    if (Platform.isAndroid) {
      final compensation = _orientations[orientation];
      if (compensation == null) return null;
      degrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360;
    } else {
      degrees = camera.sensorOrientation;
    }
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<String?> analyzeFrame({
    required CameraImage frame,
    required CameraDescription camera,
    required DeviceOrientation orientation,
  }) async {
    if (_closed) return null;
    final input = _inputImage(frame, camera, orientation);
    if (input == null) return 'صيغة إطار الكاميرا غير مدعومة للتحليل على هذا الجهاز.';
    final labels = await _labeler.processImage(input);
    if (labels.isEmpty) return null;
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    final descriptions = labels.where((item) => item.confidence >= 0.5)
        .take(3).map((item) {
      final raw = item.label.trim();
      final translated = _arabicLabels[raw.toLowerCase()] ?? raw;
      return '$translated، ثقة ${(item.confidence * 100).round()} بالمئة';
    }).toList(growable: false);
    if (descriptions.isEmpty) return null;
    return 'أتعرف في المشهد على: ${descriptions.join('، ')}.';
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _labeler.close();
  }
}
