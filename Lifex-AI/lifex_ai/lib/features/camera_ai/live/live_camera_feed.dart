/// بث الكاميرا الخلفية. التحويل إلى NV21 يستخدم حزم Lifex الذي يحترم
/// خطوة البكسل. الإطاران في الثانية حد أعلى للتحليل لا للعرض.
library lifex_ai.features.camera_ai.live.live_camera_feed;

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../accessibility/camera_stream_frame.dart';

class AnalyzableFrame {
  const AnalyzableFrame({
    required this.nv21Bytes,
    required this.width,
    required this.height,
    required this.rotationDegrees,
  });

  final Uint8List nv21Bytes;
  final int width;
  final int height;
  final int rotationDegrees;
}

abstract class LiveCameraFeed {
  Stream<AnalyzableFrame> get frames;
  Future<void> start({Duration? throttle});
  Future<void> stop();
  Future<void> dispose();
}

class CameraPackageFeed implements LiveCameraFeed {
  CameraPackageFeed({
    this.resolution = ResolutionPreset.medium,
    this.throttle = const Duration(milliseconds: 500),
  });

  final ResolutionPreset resolution;
  final Duration throttle;

  CameraController? _controller;
  final _frames = StreamController<AnalyzableFrame>.broadcast();
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  var _open = false;

  @override
  Stream<AnalyzableFrame> get frames => _frames.stream;

  @override
  Future<void> start({Duration? throttle}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    CameraDescription camera = cameras.first;
    for (final candidate in cameras) {
      if (candidate.lensDirection == CameraLensDirection.back) {
        camera = candidate;
        break;
      }
    }
    final controller = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();
    _open = true;
    await controller.startImageStream((image) {
      if (!_open || _frames.isClosed) return;
      final now = DateTime.now();
      final minInterval = throttle ?? this.throttle;
      if (now.difference(_lastFrameAt) < minInterval) return;
      final planes = image.planes;
      if (planes.length < 3) return;
      final y = planes[0];
      final u = planes[1];
      final v = planes[2];
      final packed = CameraStreamFrame.packNv21(
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
      if (packed == null) return;
      _lastFrameAt = now;
      _frames.add(AnalyzableFrame(
        nv21Bytes: packed,
        width: image.width,
        height: image.height,
        rotationDegrees: camera.sensorOrientation,
      ));
    });
  }

  @override
  Future<void> stop() async {
    _open = false;
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller?.dispose();
    _controller = null;
    if (!_frames.isClosed) await _frames.close();
  }
}
