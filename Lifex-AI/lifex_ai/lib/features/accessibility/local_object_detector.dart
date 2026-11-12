/// كشف أجسام محلي بصناديق عبر ML Kit (النموذج الأساسي المدمج في المكتبة).
/// الاسم من المصنّف على قصّ كل صندوق، وما لا يُسمّى بثقة يُقال «غير معروف».
library lifex_ai.features.accessibility.local_object_detector;

import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart'
    as odt;

import 'box_geometry.dart';

class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.place = BoxPlace.center,
    this.known = true,
  });

  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final BoxPlace place;

  /// كاذب حين لم يسمِّه المصنّف ولا الكاشف بثقة.
  final bool known;

  bool get hasBox =>
      right.isFinite &&
      left.isFinite &&
      bottom.isFinite &&
      top.isFinite &&
      right > left &&
      bottom > top;
}

class ObjectDetectionOutcome {
  const ObjectDetectionOutcome({
    required this.ran,
    required this.reasonAr,
    this.objects = const [],
  });

  final bool ran;
  final String reasonAr;
  final List<DetectedObject> objects;
}

/// تشغيل فعلي للكاشف على إطار صناعي عند الإقلاع. وجود المكتبة وحده لا يكفي.
class LocalModelCheck {
  const LocalModelCheck({required this.ran, this.reason = ''});

  final bool ran;
  final String reason;

  bool get loaded => ran;
}

typedef CropNamer = Future<List<({String label, double confidence})>> Function(
  InputImage crop,
);

class LocalObjectDetector {
  LocalObjectDetector({CropNamer? namer}) : _namer = namer;

  /// العتبة الافتراضية الموثقة لمصنّف ML Kit. لم تُقيَّم بعد على هاتف.
  static const nameFloor = 0.5;

  /// أكبر عدد صناديق يُسمّى في الإطار الواحد، للحفاظ على زمن الإطار.
  static const maxNamed = 3;

  static LocalModelCheck? lastCheck;

  static const notInstalledAr =
      'كاشف الأجسام غير محمّل. تصنيف الصورة ليس كشف أجسام، ولن أخترع جسماً أو مسافة.';

  static const notInstalledEn =
      'The object detector is not loaded. Image classification is not object detection, and I will not invent an object or a distance.';

  static const unsupportedFrameAr =
      'هذا الإطار ليس بتنسيق يمكن قصّه. لم يُسمَّ أي صندوق.';

  static String unavailableLine(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar') ? notInstalledAr : notInstalledEn;

  final CropNamer? _namer;
  odt.ObjectDetector? _detector;
  ImageLabeler? _labeler;

  static odt.ObjectDetector _create() => odt.ObjectDetector(
        options: odt.ObjectDetectorOptions(
          mode: odt.DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

  /// يشغّل الكاشف على إطار رمادي صغير. الفشل يعني أن النموذج لا يعمل هنا.
  static Future<LocalModelCheck> checkModel() async {
    odt.ObjectDetector? probe;
    LocalModelCheck check;
    try {
      probe = _create();
      const side = 64;
      final bytes = Uint8List(side * side + (side ~/ 2) * (side ~/ 2) * 2)
        ..fillRange(0, side * side, 128)
        ..fillRange(side * side, side * side + side * side ~/ 2, 128);
      await probe.processImage(
        InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: const Size(side * 1.0, side * 1.0),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: side,
          ),
        ),
      );
      check = const LocalModelCheck(ran: true);
    } catch (error) {
      check = LocalModelCheck(ran: false, reason: '$error');
    } finally {
      try {
        await probe?.close();
      } catch (_) {}
    }
    lastCheck = check;
    return check;
  }

  Future<List<({String label, double confidence})>> _nameCrop(
    InputImage crop,
  ) async {
    final namer = _namer;
    if (namer != null) return namer(crop);
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: nameFloor),
    );
    final found = await _labeler!.processImage(crop);
    return [
      for (final label in found)
        (label: label.label, confidence: label.confidence),
    ];
  }

  /// يكشف الصناديق ثم يسمّي أكبرها من قصّ الإطار نفسه.
  Future<ObjectDetectionOutcome> detect(
    InputImage input, {
    bool mirrored = false,
    Future<List<odt.DetectedObject>> Function(InputImage image)? findBoxes,
  }) async {
    final metadata = input.metadata;
    final bytes = input.bytes;
    if (metadata == null || bytes == null) {
      return const ObjectDetectionOutcome(ran: false, reasonAr: unsupportedFrameAr);
    }
    List<odt.DetectedObject> boxes;
    try {
      if (findBoxes != null) {
        boxes = await findBoxes(input);
      } else {
        _detector ??= _create();
        boxes = await _detector!.processImage(input);
      }
    } catch (_) {
      return const ObjectDetectionOutcome(ran: false, reasonAr: notInstalledAr);
    }
    final sensorWidth = metadata.size.width.round();
    final sensorHeight = metadata.size.height.round();
    final rotation = metadata.rotation.rawValue;
    final frameWidth = uprightWidth(
      sensorWidth: sensorWidth,
      sensorHeight: sensorHeight,
      rotationDegrees: rotation,
    );
    final canCrop = metadata.format == InputImageFormat.nv21 &&
        metadata.bytesPerRow == sensorWidth;
    final ranked = [...boxes]..sort((a, b) {
        final areaA = a.boundingBox.width * a.boundingBox.height;
        final areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB.compareTo(areaA);
      });
    final objects = <DetectedObject>[];
    for (final box in ranked.take(maxNamed)) {
      final rect = box.boundingBox;
      final upright = BoxRect(rect.left, rect.top, rect.right, rect.bottom);
      final place = placeOf(upright, frameWidth, mirrored: mirrored);
      var label = '';
      var confidence = 0.0;
      if (canCrop) {
        final sensor = uprightToSensor(
          upright,
          sensorWidth: sensorWidth,
          sensorHeight: sensorHeight,
          rotationDegrees: rotation,
        );
        final crop = sensor == null
            ? null
            : cropNv21(
                bytes,
                width: sensorWidth,
                height: sensorHeight,
                sensorRect: sensor,
              );
        if (crop != null) {
          try {
            final names = await _nameCrop(
              InputImage.fromBytes(
                bytes: crop.bytes,
                metadata: InputImageMetadata(
                  size: Size(crop.width.toDouble(), crop.height.toDouble()),
                  rotation: metadata.rotation,
                  format: InputImageFormat.nv21,
                  bytesPerRow: crop.width,
                ),
              ),
            );
            final best = [...names]
              ..sort((a, b) => b.confidence.compareTo(a.confidence));
            if (best.isNotEmpty && best.first.confidence >= nameFloor) {
              label = best.first.label;
              confidence = best.first.confidence;
            }
          } catch (_) {}
        }
      }
      if (label.isEmpty) {
        final coarse = [...box.labels]
          ..sort((a, b) => b.confidence.compareTo(a.confidence));
        if (coarse.isNotEmpty && coarse.first.confidence >= nameFloor) {
          label = coarse.first.text;
          confidence = coarse.first.confidence;
        }
      }
      objects.add(DetectedObject(
        label: label,
        confidence: confidence,
        left: upright.left,
        top: upright.top,
        right: upright.right,
        bottom: upright.bottom,
        place: place,
        known: label.isNotEmpty,
      ));
    }
    return ObjectDetectionOutcome(ran: true, reasonAr: '', objects: objects);
  }

  /// للمستدعين القدامى بلا إطار: لا نتيجة مخترعة.
  ObjectDetectionOutcome run() => const ObjectDetectionOutcome(
        ran: false,
        reasonAr: notInstalledAr,
      );

  Future<void> close() async {
    await _detector?.close();
    await _labeler?.close();
    _detector = null;
    _labeler = null;
  }
}
