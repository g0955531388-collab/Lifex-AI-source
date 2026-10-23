/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: layered_lens_studio_screen.dart
/// تقريب العدسة الخلفية بما يسمح به العتاد. لقطة للملف. بلا تشخيص.
/// =============================================================
library lifex_ai.screens.layered_lens_studio_screen;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/permission_transparency.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/voice_engine.dart';

class LayeredLensStudioScreen extends StatefulWidget {
  const LayeredLensStudioScreen({super.key});

  @override
  State<LayeredLensStudioScreen> createState() =>
      _LayeredLensStudioScreenState();
}

class _LayeredLensStudioScreenState extends State<LayeredLensStudioScreen> {
  CameraController? _lens;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _minExposure = 0;
  double _maxExposure = 0;
  double _exposure = 0;
  bool _torchAvailable = false;
  bool _torchOn = false;
  bool _busy = false;
  bool _voiceOn = true;
  String _status = 'عدسة واحدة للتقريب. اللقطة تُحفظ في الملف. ليست تشخيص جلد.';
  String? _shotPath;

  bool get _ready {
    final lens = _lens;
    return lens != null && lens.value.isInitialized;
  }

  bool get _canZoom => _maxZoom > _minZoom + 0.05;

  bool get _canExpose => _maxExposure > _minExposure;

  @override
  void dispose() {
    final lens = _lens;
    _lens = null;
    if (lens != null) unawaited(lens.dispose());
    super.dispose();
  }

  Future<void> _say(String line) async {
    if (!mounted) return;
    setState(() => _status = line);
    if (!_voiceOn) return;
    await VoiceEngine.instance.speak(line);
  }

  Future<void> _open() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقريب العدسة'),
        content: const Text(
          'تفتح العدسة الخلفية أمامك للتقريب والتقاط لقطة في الملف. '
          'ليست تشخيص جلد، ولا تُركّب صورة من شريحتين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أوافق'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.camera,
      granted: true,
    );
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (permission.isPermanentlyDenied) {
      await _say('إذن الكاميرا مرفوض من إعدادات الجهاز. سأفتح الإعدادات.');
      await openAppSettings();
      return;
    }
    if (!permission.isGranted) {
      await _say('رُفض إذن الكاميرا. التقريب متوقف.');
      return;
    }
    try {
      final found = await availableCameras();
      if (!mounted) return;
      final rear = found
          .where((item) => item.lensDirection == CameraLensDirection.back)
          .toList();
      if (rear.isEmpty) {
        await _say('لا توجد عدسة خلفية على هذا الجهاز.');
        return;
      }
      final lens = await _start(rear.first);
      final minZoom = await lens.getMinZoomLevel();
      final maxZoom = await lens.getMaxZoomLevel();
      final zoom = minZoom;
      await lens.setZoomLevel(zoom);
      var minExposure = 0.0;
      var maxExposure = 0.0;
      try {
        minExposure = await lens.getMinExposureOffset();
        maxExposure = await lens.getMaxExposureOffset();
      } catch (_) {}
      var torch = false;
      try {
        await lens.setFlashMode(FlashMode.off);
        torch = true;
      } catch (_) {}
      if (!mounted) {
        await lens.dispose();
        return;
      }
      final previous = _lens;
      setState(() {
        _lens = lens;
        _minZoom = minZoom;
        _maxZoom = maxZoom < minZoom ? minZoom : maxZoom;
        _zoom = zoom;
        _minExposure = minExposure;
        _maxExposure = maxExposure;
        _exposure = 0;
        _torchAvailable = torch;
        _torchOn = false;
      });
      if (previous != null) unawaited(previous.dispose());
      final ceiling = _maxZoom.toStringAsFixed(1);
      await _say(
        _canZoom
            ? 'العدسة مفتوحة. التقريب من 1 حتى $ceiling×. قرّب ثم التقط.'
            : 'العدسة مفتوحة. هذا الجهاز بلا تقريب بصري. اللقطة بالحجم الذي تتيحه العدسة.',
      );
    } catch (error) {
      if (!mounted) return;
      await _say('تعذّر فتح العدسة. $error');
    }
  }

  Future<CameraController> _start(CameraDescription chosen) async {
    Object? last;
    for (final preset in const [
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ]) {
      final lens = CameraController(
        chosen,
        preset,
        enableAudio: false,
      );
      try {
        await lens.initialize();
        return lens;
      } catch (error) {
        last = error;
        await lens.dispose();
      }
    }
    throw last ?? StateError('lens');
  }

  Future<void> _applyZoom(double value) async {
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized) return;
    final zoom = value.clamp(_minZoom, _maxZoom);
    try {
      await lens.setZoomLevel(zoom);
    } catch (error) {
      await _say('رفضت العدسة هذا التقريب. $error');
      return;
    }
    if (!mounted) return;
    setState(() => _zoom = zoom);
  }

  Future<void> _applyTorch(bool on) async {
    final lens = _lens;
    if (lens == null || !_torchAvailable) return;
    try {
      await lens.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (error) {
      await _say('لا ضوء مستمر على هذه العدسة. $error');
      return;
    }
    if (!mounted) return;
    setState(() => _torchOn = on);
  }

  Future<void> _applyExposure(double value) async {
    final lens = _lens;
    if (lens == null || !_canExpose) return;
    final offset = value.clamp(_minExposure, _maxExposure);
    try {
      await lens.setExposureOffset(offset);
    } catch (error) {
      await _say('لا إزاحة تعريض على هذه العدسة. $error');
      return;
    }
    if (!mounted) return;
    setState(() => _exposure = offset);
  }

  Future<void> _shoot() async {
    final lens = _lens;
    if (_busy || lens == null || !lens.value.isInitialized) {
      await _say('افتح العدسة أولاً.');
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await lens.takePicture();
      if (!mounted) return;
      final controller = context.read<ActiveProfileController>();
      final profile = controller.activeProfile;
      final zoomLabel = _zoom.toStringAsFixed(1);
      if (profile == null) {
        setState(() => _shotPath = shot.path);
        await _say(
          'أُخذت اللقطة ×$zoomLabel. أنشئ الملف الصحي ليُحفظ المسار في الأرشيف.',
        );
        return;
      }
      ProfileBoxStore(profile).add(BoxKeys.layeredSlices, {
        'title': 'لقطة تقريب ×$zoomLabel',
        'detail':
            'لقطة تقريب من العدسة الخلفية. ليست تشخيص جلد ولا دمج شريحتين.',
        'path': shot.path,
        'zoom': _zoom,
        'origin': 'camera',
      });
      controller.saveActiveProfileChanges();
      setState(() => _shotPath = shot.path);
      await _say('حُفظت لقطة التقريب ×$zoomLabel في الملف. ليست تشخيص جلد.');
    } catch (error) {
      if (!mounted) return;
      await _say('تعذّر حفظ اللقطة. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _preview() {
    final lens = _lens;
    if (lens != null && lens.value.isInitialized) {
      final ratio =
          lens.value.aspectRatio == 0 ? 3 / 4 : lens.value.aspectRatio;
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: ratio,
            child: CameraPreview(lens),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => unawaited(_open()),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('افتح العدسة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shotPath;
    return Scaffold(
      appBar: AppBar(title: const Text('تقريب العدسة')),
      body: Column(
        children: [
          Expanded(child: _preview()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'لقطة تقريب للملف. ليست تشخيص جلد، ولا تركيب شريحتين.',
                  ),
                  if (_ready && _canZoom) ...[
                    Text('التقريب ${_zoom.toStringAsFixed(1)}×'),
                    Slider(
                      min: _minZoom,
                      max: _maxZoom,
                      value: _zoom.clamp(_minZoom, _maxZoom),
                      onChanged: _busy
                          ? null
                          : (value) => unawaited(_applyZoom(value)),
                    ),
                  ],
                  if (_ready && _torchAvailable)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ضوء مستمر'),
                      value: _torchOn,
                      onChanged: _busy
                          ? null
                          : (value) => unawaited(_applyTorch(value)),
                    ),
                  if (_ready && _canExpose) ...[
                    Text(
                      'إزاحة التعريض ${_exposure.toStringAsFixed(1)}',
                    ),
                    Slider(
                      min: _minExposure,
                      max: _maxExposure,
                      value: _exposure.clamp(_minExposure, _maxExposure),
                      onChanged: _busy
                          ? null
                          : (value) => unawaited(_applyExposure(value)),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('النطق'),
                    value: _voiceOn,
                    onChanged: (value) => setState(() => _voiceOn = value),
                  ),
                  if (_ready)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => unawaited(_shoot()),
                      icon: const Icon(Icons.camera),
                      label: Text(_busy ? 'يلتقط...' : 'التقط واحفظ'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => unawaited(_open()),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('افتح العدسة'),
                    ),
                  if (shot != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: Image.file(File(shot), fit: BoxFit.contain),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(_status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
