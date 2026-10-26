/// =============================================================
/// Lifex-AI — كاميرا المكفوفين
/// إطار البث الحي يُقرأ من الذاكرة. اللقطة المتتالية ليست البث.
/// الإطار الذي لا يُعرف تنسيقه يبقى بلا مشهد.
/// =============================================================
library lifex_ai.features.accessibility.camera_stream_frame;

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'blind_scene_brief.dart';
import 'file_path_image_labeler.dart';

class CameraStreamReading {
  const CameraStreamReading({
    required this.labels,
    required this.text,
    this.barcodes = const [],
    this.hits = const [],
    this.sceneRan = false,
  });

  final List<String> labels;
  final String text;
  final List<String> barcodes;
  final List<SceneHit> hits;

  /// صحيح فقط بعد عودة processImage، ولو كانت القائمة فارغة.
  final bool sceneRan;
}

class CameraStreamFrame {
  const CameraStreamFrame._();

  /// ينسخ بايتات الإطار فوراً. أندرويد: NV21 جاهز، أو YUV بثلاث طبقات يُحزَم NV21.
  /// iOS: BGRA بمستوى واحد.
  static InputImage? toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required bool android,
  }) {
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final raw = image.format.raw;
    if (rotation == null || raw is! int) return null;
    final format = InputImageFormatValue.fromRawValue(raw);
    if (format == null) return null;
    if (!android) {
      if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
        return null;
      }
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(plane.bytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
    if (format == InputImageFormat.nv21 && image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(plane.bytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
    final yuv = format == InputImageFormat.yuv_420_888 ||
        format == InputImageFormat.nv21 ||
        format == InputImageFormat.yuv420;
    if (!yuv || image.planes.length < 3) return null;
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    final packed = packNv21(
      width: image.width,
      height: image.height,
      yBytes: y.bytes,
      yRowStride: y.bytesPerRow,
      uBytes: u.bytes,
      uRowStride: u.bytesPerRow,
      uPixelStride: u.bytesPerPixel ?? 1,
      vBytes: v.bytes,
      vRowStride: v.bytesPerRow,
      vPixelStride: v.bytesPerPixel ?? 1,
    );
    if (packed == null) return null;
    return InputImage.fromBytes(
      bytes: packed,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  /// يحزم Y و U و V في NV21 متراص. الإطار الناقص يبقى بلا صورة.
  static Uint8List? packNv21({
    required int width,
    required int height,
    required Uint8List yBytes,
    required int yRowStride,
    required Uint8List uBytes,
    required int uRowStride,
    required int uPixelStride,
    required Uint8List vBytes,
    required int vRowStride,
    required int vPixelStride,
  }) {
    if (width < 2 || height < 2) return null;
    if (uPixelStride < 1 || vPixelStride < 1) return null;
    if (yRowStride < width || uRowStride < 1 || vRowStride < 1) return null;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final out = Uint8List(width * height + uvWidth * uvHeight * 2);
    for (var row = 0; row < height; row++) {
      final start = row * yRowStride;
      if (start < 0 || start + width > yBytes.length) return null;
      out.setRange(row * width, row * width + width, yBytes, start);
    }
    var chroma = width * height;
    for (var row = 0; row < uvHeight; row++) {
      for (var col = 0; col < uvWidth; col++) {
        final vIndex = row * vRowStride + col * vPixelStride;
        final uIndex = row * uRowStride + col * uPixelStride;
        if (vIndex >= vBytes.length || uIndex >= uBytes.length) return null;
        out[chroma++] = vBytes[vIndex];
        out[chroma++] = uBytes[uIndex];
      }
    }
    return out;
  }

  /// NV21 متراص جاهز. الاتجاه غير المعروف يبقي الإطار بلا صورة.
  static InputImage? fromPackedNv21({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rotationDegrees,
  }) {
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    if (rotation == null || width < 2 || height < 2) return null;
    if (bytes.length < width * height) return null;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      ),
    );
  }
}

class CameraStreamReader {
  ImageLabeler? _labeler;
  TextRecognizer? _text;
  BarcodeScanner? _barcode;

  Future<CameraStreamReading> read(
    InputImage image, {
    required bool includeScene,
    required bool includeText,
    bool includeBarcode = false,
  }) async {
    try {
      final labels = <String>[];
      final hits = <SceneHit>[];
      final barcodes = <String>[];
      var text = '';
      var sceneRan = false;
      if (includeScene) {
        _labeler ??= ImageLabeler(
          options: ImageLabelerOptions(
            confidenceThreshold: FilePathImageLabeler.confidenceThreshold,
          ),
        );
        final found = await _labeler!.processImage(image);
        sceneRan = true;
        for (final label in found) {
          hits.add(SceneHit(label.label, label.confidence));
          labels.add(label.label);
        }
      }
      if (includeText) {
        _text ??= TextRecognizer(script: TextRecognitionScript.latin);
        final recognized = await _text!.processImage(image);
        text = recognized.text;
      }
      if (includeBarcode) {
        _barcode ??= BarcodeScanner();
        final found = await _barcode!.processImage(image);
        for (final code in found) {
          final value = code.rawValue?.trim() ?? '';
          if (value.isNotEmpty) barcodes.add(value);
        }
      }
      return CameraStreamReading(
        labels: labels,
        text: text,
        barcodes: barcodes,
        hits: hits,
        sceneRan: sceneRan,
      );
    } catch (_) {
      return const CameraStreamReading(labels: [], text: '');
    }
  }

  Future<void> close() async {
    await _labeler?.close();
    await _text?.close();
    await _barcode?.close();
    _labeler = null;
    _text = null;
    _barcode = null;
  }
}
