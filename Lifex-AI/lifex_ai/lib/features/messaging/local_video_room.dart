/// غرفة فيديو على هذا الجهاز. المعاينة محلية.
/// الصورة لا تُرسل إلى هاتف آخر في هذا البناء.
library lifex_ai.features.messaging.local_video_room;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LocalVideoRoomPage extends StatefulWidget {
  const LocalVideoRoomPage({
    super.key,
    required this.title,
    required this.names,
    required this.note,
  });

  final String title;
  final List<String> names;
  final String note;

  @override
  State<LocalVideoRoomPage> createState() => _LocalVideoRoomPageState();
}

class _LocalVideoRoomPageState extends State<LocalVideoRoomPage> {
  CameraController? _camera;
  var _muted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_openCamera());
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;
      var chosen = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          chosen = camera;
          break;
        }
      }
      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      if (mounted) setState(() => _camera = null);
    }
  }

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ready
                ? CameraPreview(camera)
                : const Center(child: Icon(Icons.videocam_off_outlined, size: 72)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(widget.note),
          ),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: [
                for (final name in widget.names)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: Icon(_muted ? Icons.mic_off : Icons.mic),
                      label: Text(name),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  onPressed: () => setState(() => _muted = !_muted),
                  icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                ),
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
