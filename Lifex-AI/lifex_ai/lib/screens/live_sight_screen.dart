/// Lifex-AI live assistive camera screen.
/// Frames are analyzed on-device while this screen is visible and consented.
library lifex_ai.screens.live_sight_screen;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/permission_transparency.dart';
import '../features/accessibility/live_camera_vision_engine.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class LiveSightScreen extends StatefulWidget {
  const LiveSightScreen({
    super.key,
    this.profileId = '',
    this.lensDirection = CameraLensDirection.back,
  });

  final String profileId;
  final CameraLensDirection lensDirection;

  @override
  State<LiveSightScreen> createState() => _LiveSightScreenState();
}

class _LiveSightScreenState extends State<LiveSightScreen> {
  final LiveCameraVisionEngine _vision = LiveCameraVisionEngine();
  CameraController? _lens;
  CameraDescription? _activeCamera;
  bool _consented = false;
  bool _processingFrame = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastSpoken;
  String _spokenAr =
      'الكاميرا مغلقة. بعد موافقتك سأحلل إطارات الكاميرا محلياً على الجهاز.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askConsentThenOpen();
    });
  }

  @override
  void dispose() {
    final lens = _lens;
    if (lens != null) {
      if (lens.value.isStreamingImages) {
        unawaited(lens.stopImageStream());
      }
      unawaited(lens.dispose());
    }
    unawaited(_vision.close());
    super.dispose();
  }

  Future<void> _askConsentThenOpen() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بث وتحليل حي على الجهاز'),
        content: const Text(
          'بعد موافقتك ستبقى الكاميرا تعمل ما دامت هذه الصفحة مفتوحة. '
          'سيحلل التطبيق الإطارات محلياً باستخدام ML Kit، ولن يرسل الصور إلى خادم. '
          'التعرف تصنيف عام للمشهد وليس قياس مسافة أو ضماناً لاكتشاف العوائق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أوافق على البث والتحليل'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.camera,
      granted: true,
    );
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _spokenAr = 'رفض النظام إذن الكاميرا. البث والتحليل متوقفان.');
      await _speakSafely(_spokenAr);
      return;
    }
    setState(() => _consented = true);
    await _attachLens();
  }

  Future<void> _attachLens() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _consented = false);
        await _announce('لا توجد كاميرا متاحة على هذا الجهاز.');
        return;
      }
      final matchingCameras = cameras.where(
        (item) => item.lensDirection == widget.lensDirection,
      );
      if (matchingCameras.isEmpty) {
        if (mounted) setState(() => _consented = false);
        await _announce(
          widget.lensDirection == CameraLensDirection.front
              ? 'لا توجد كاميرا أمامية متاحة على هذا الجهاز.'
              : 'لا توجد كاميرا خلفية متاحة على هذا الجهاز.',
        );
        return;
      }
      final chosen = matchingCameras.first;
      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _activeCamera = chosen;
      setState(() {
        _lens = controller;
        _spokenAr = 'الكاميرا جاهزة. أبدأ تحليل الإطارات محلياً الآن.';
      });
      await controller.startImageStream(_onCameraFrame);
      await _speakSafely(_spokenAr);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _consented = false;
        _spokenAr = 'تعذّر بدء تحليل الكاميرا الحي. تحقق من دعم صيغة الإطارات وإذن الكاميرا. $error';
      });
      await _speakSafely(_spokenAr);
    }
  }

  void _onCameraFrame(CameraImage frame) {
    if (!mounted || _processingFrame) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < const Duration(milliseconds: 850)) {
      return;
    }
    _lastFrameAt = now;
    unawaited(_analyzeFrame(frame));
  }

  Future<void> _analyzeFrame(CameraImage frame) async {
    if (_processingFrame) return;
    _processingFrame = true;
    try {
      final lens = _lens;
      final camera = _activeCamera;
      if (lens == null || camera == null || !lens.value.isInitialized) return;
      final description = await _vision.analyzeFrame(
        frame: frame,
        camera: camera,
        orientation: lens.value.deviceOrientation,
      );
      if (!mounted || description == null || description.isEmpty) return;
      setState(() => _spokenAr = description);

      final now = DateTime.now();
      final changed = description != _lastSpoken;
      final intervalElapsed =
          now.difference(_lastSpokenAt) >= const Duration(seconds: 3);
      if (changed && intervalElapsed) {
        _lastSpoken = description;
        _lastSpokenAt = now;
        await _speakSafely(description);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _spokenAr = 'تعذّر تحليل إطار الكاميرا. $error');
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _announce(String message) async {
    if (!mounted) return;
    setState(() => _spokenAr = message);
    await _speakSafely(message);
  }

  Future<void> _speakSafely(String message) async {
    try {
      await VoiceEngine.instance.speak(message);
    } catch (_) {
      // إبقاء الكاميرا والواجهة عاملتين حتى عند تعذّر محرّك النطق.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lens = _lens;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lensDirection == CameraLensDirection.front
            ? 'المساعد البصري — الكاميرا الأمامية'
            : 'المساعد البصري — الكاميرا الخلفية'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'التعرف البصري مساعد إضافي فقط. لا يحدد المسافات ولا يضمن كشف العوائق، ولا يغني عن العصا البيضاء أو وسائل السلامة المعتادة.',
          ),
          const SizedBox(height: 12),
          if (lens != null && lens.value.isInitialized)
            AspectRatio(
              aspectRatio: lens.value.aspectRatio,
              child: CameraPreview(lens),
            )
          else
            Container(
              height: 220,
              alignment: Alignment.center,
              color: Colors.black12,
              child: Text(
                _spokenAr,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _consented ? null : _askConsentThenOpen,
            icon: const Icon(Icons.videocam_outlined),
            label: Text(_consented ? 'التحليل الحي يعمل' : 'ابدأ البث والتحليل الحي'),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(_spokenAr, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
