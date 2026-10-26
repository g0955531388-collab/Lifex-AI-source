/// كاميرا SPOT مستقلة. العدسة الخلفية أولاً، مع تبديل إلى الأمامية.
/// التصنيف ليس تشخيصاً، وفراغ الإطار ليس طريقاً آمناً.
library lifex_ai.features.spot.spot_camera_page;

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accessibility/blind_assist_gate.dart';
import '../accessibility/blind_camera_speech.dart';
import '../accessibility/camera_stream_frame.dart';
import '../accessibility/gemini_live_link.dart';
import '../accessibility/visual_assist_floor.dart';
import '../camera_ai/scene/tts_announcer.dart';
import '../profile/active_profile_controller.dart';
import '../voice/voice_engine.dart';
import '../../widgets/blind_camera_rail.dart';
import 'spot_speech.dart';

class SpotCameraPage extends StatefulWidget {
  const SpotCameraPage({super.key});

  @override
  State<SpotCameraPage> createState() => _SpotCameraPageState();
}

class _SpotCameraPageState extends State<SpotCameraPage> {
  final CameraStreamReader _reader = CameraStreamReader();
  final TtsAnnouncer _announcer = TtsAnnouncer(voiceEngine: VoiceEngine.instance);
  final BlindAssistGate _gate = BlindAssistGate();
  CameraController? _camera;
  CameraLensDirection _facing = CameraLensDirection.back;
  String _language = 'en';
  String _line = '';
  var _ready = false;
  var _muted = false;
  var _reading = false;
  var _switching = false;
  var _closed = false;
  var _handedToOther = false;
  var _introSaid = false;
  Uint8List? _lastPacked;
  var _lastWidth = 0;
  var _lastHeight = 0;
  var _lastRotation = 0;

  @override
  void initState() {
    super.initState();
    VisualAssistFloorSwitch.listen(_onVisualFloor);
    VisualAssistFloorSwitch.take(VisualAssistFloor.spot);
    unawaited(_start());
  }

  void _onVisualFloor(VisualAssistFloor floor) {
    if (floor == VisualAssistFloor.spot || _handedToOther) return;
    _handedToOther = true;
    _closed = true;
    GeminiBlindLink.release();
    final camera = _camera;
    _camera = null;
    unawaited(camera?.dispose());
    unawaited(VoiceEngine.instance.interruptIfSpeaking());
    handOffVisualAssist(context, mounted: () => mounted);
  }

  Future<void> _onRail(BlindRailZone zone) async {
    final step = _gate.press(zone);
    if (step != BlindAssistStep.open) {
      if (mounted && !_closed) setState(() {});
      final ask = switch (zone) {
        BlindRailZone.spot => SpotSpeech.armAsk(_language),
        BlindRailZone.front => BlindAssistGate.frontAskAr,
        BlindRailZone.assistant => BlindAssistGate.assistantAskAr,
      };
      await _say(ask);
      return;
    }
    if (zone == BlindRailZone.spot) {
      _gate.reset();
      if (mounted) setState(() {});
      await _say(SpotSpeech.alreadyOpen(_language));
      return;
    }
    if (zone == BlindRailZone.front) {
      await _toggleLens();
      return;
    }
    final opener = VisualAssistFloorSwitch.legacyPage;
    if (opener == null || !mounted || _closed) return;
    final profileId = context.read<ActiveProfileController>().activeProfileId ?? '';
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => opener(profileId)),
    );
  }

  Future<void> _start() async {
    await GeminiBlindLink.hold();
    _language = SpotSpeech.deviceLanguage();
    if (_closed) return;
    await _openFacing(CameraLensDirection.back);
  }

  Future<void> _openFacing(CameraLensDirection wanted) async {
    try {
      final cameras = await availableCameras();
      if (_closed) return;
      CameraDescription? chosen;
      CameraDescription? fallback;
      for (final camera in cameras) {
        if (camera.lensDirection == wanted) {
          chosen = camera;
          break;
        }
        fallback ??= camera;
      }
      final missingWanted = chosen == null;
      chosen ??= fallback;
      if (chosen == null) {
        await _say(BlindCameraSpeech.noLens(_language));
        return;
      }
      _facing = chosen.lensDirection;
      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _camera = controller;
      await controller.initialize();
      if (_closed || !mounted) {
        await controller.dispose();
        if (identical(_camera, controller)) _camera = null;
        return;
      }
      setState(() => _ready = true);
      await controller.startImageStream(_onImage);
      if (!_introSaid) {
        _introSaid = true;
        await _say(SpotSpeech.intro(_language));
      }
      if (_closed) return;
      if (missingWanted) {
        await _say(
          '${BlindCameraSpeech.noLens(_language)} ${SpotSpeech.lensFacing(_facing == CameraLensDirection.back, _language)}',
        );
      } else {
        await _say(
          SpotSpeech.lensFacing(_facing == CameraLensDirection.back, _language),
        );
      }
    } catch (_) {
      if (_closed) return;
      await _say(BlindCameraSpeech.lensFailed(_language));
    }
  }

  Future<void> _toggleLens() async {
    if (_switching || _closed) return;
    _switching = true;
    _ready = false;
    _lastPacked = null;
    if (mounted) setState(() {});
    final next = _facing == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final current = _camera;
    _camera = null;
    try {
      if (current != null) {
        if (current.value.isStreamingImages) {
          await current.stopImageStream();
        }
        await current.dispose();
      }
      if (_closed) return;
      await _openFacing(next);
    } finally {
      _switching = false;
    }
  }

  void _onImage(CameraImage image) {
    if (_closed || _muted || _reading || _switching) return;
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
    final camera = _camera?.description;
    _lastPacked = packed;
    _lastWidth = image.width;
    _lastHeight = image.height;
    _lastRotation = camera?.sensorOrientation ?? 0;
    _reading = true;
    unawaited(_speakFrame(
      packed,
      _lastWidth,
      _lastHeight,
      _lastRotation,
      includeText: false,
    ));
  }

  Future<void> _speakFrame(
    Uint8List bytes,
    int width,
    int height,
    int rotation, {
    required bool includeText,
  }) async {
    _reading = true;
    try {
      final image = CameraStreamFrame.fromPackedNv21(
        bytes: bytes,
        width: width,
        height: height,
        rotationDegrees: rotation,
      );
      if (image == null) return;
      final reading = await _reader.read(
        image,
        includeScene: !includeText,
        includeText: includeText,
      );
      if (_closed || _muted) return;
      final phrase = includeText
          ? SpotSpeech.textRead(reading.text, _language)
          : SpotSpeech.scene(reading.labels, _language);
      await _say(phrase);
    } finally {
      _reading = false;
    }
  }

  Future<void> _say(String phrase) async {
    final text = phrase.trim();
    if (text.isEmpty || _closed) return;
    if (mounted) setState(() => _line = text);
    await _announcer.announce(text);
  }

  Future<void> _readText() async {
    final bytes = _lastPacked;
    if (bytes == null) {
      await _say(SpotSpeech.textRead('', _language));
      return;
    }
    await _speakFrame(
      bytes,
      _lastWidth,
      _lastHeight,
      _lastRotation,
      includeText: true,
    );
  }

  @override
  void dispose() {
    _closed = true;
    VisualAssistFloorSwitch.unlisten(_onVisualFloor);
    GeminiBlindLink.release();
    final camera = _camera;
    _camera = null;
    unawaited(camera?.dispose());
    unawaited(_reader.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final preview = _ready && camera != null && camera.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SPOT'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlindCameraRail(
            armedZone: _gate.armedZone,
            onZone: (zone) => unawaited(_onRail(zone)),
          ),
          Expanded(
            child: Column(
        children: [
          Expanded(
            child: preview
                ? CameraPreview(camera)
                : const Center(
                    child: Icon(Icons.videocam_outlined, color: Colors.white, size: 72),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _line,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _switching ? null : () => unawaited(_toggleLens()),
                  icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
                  tooltip: SpotSpeech.switchLens(_language),
                ),
                IconButton(
                  onPressed: () => setState(() => _muted = !_muted),
                  icon: Icon(
                    _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                    color: Colors.white,
                  ),
                  tooltip: _muted ? 'muted' : 'speaking',
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _reading ? null : () => unawaited(_readText()),
                  child: Text(
                    _language == 'ar'
                        ? 'اقرأ النص'
                        : _language == 'fr'
                            ? 'Lire le texte'
                            : 'Read text',
                  ),
                ),
              ],
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}
