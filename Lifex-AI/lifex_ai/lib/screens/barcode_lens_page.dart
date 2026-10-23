/// =============================================================
/// Lifex-AI — قراءة باركود من العدسة
/// النص هو ما طبعه الرمز. لا يُستنتج منه دواء أو تشخيص.
/// =============================================================
library lifex_ai.screens.barcode_lens_page;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/permission_transparency.dart';
import '../features/accessibility/camera_stream_frame.dart';
import '../features/voice/voice_engine.dart';

/// قراءة رمز كما أعادتها المكتبة. النص الخام لا يُعدَّل ولا يُفتح.
class BarcodeRead {
  const BarcodeRead({
    required this.raw,
    required this.formatName,
  });

  final String raw;
  final String formatName;

  bool get opensAutomatically => false;

  static BarcodeRead fromLibrary({
    required String? rawValue,
    required BarcodeFormat format,
  }) {
    return BarcodeRead(
      raw: rawValue ?? '',
      formatName: nameOf(format),
    );
  }

  static String nameOf(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.unknown:
      case BarcodeFormat.all:
        return 'unknown';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.upca:
        return 'UPC-A';
      case BarcodeFormat.upce:
        return 'UPC-E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
    }
  }
}

class BarcodeLensPage extends StatefulWidget {
  const BarcodeLensPage({super.key});

  @override
  State<BarcodeLensPage> createState() => _BarcodeLensPageState();
}

class _BarcodeLensPageState extends State<BarcodeLensPage> {
  CameraController? _lens;
  BarcodeScanner? _scanner;
  String? _error;
  bool _done = false;
  DateTime? _lastFrame;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    final lens = _lens;
    _lens = null;
    if (lens != null) unawaited(lens.dispose());
    final scanner = _scanner;
    _scanner = null;
    if (scanner != null) unawaited(scanner.close());
    super.dispose();
  }

  Future<void> _say(String line) => VoiceEngine.instance.speak(line);

  Future<void> _open() async {
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.camera,
      granted: true,
    );
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _error = 'رُفض إذن الكاميرا. قراءة الباركود متوقفة.');
      await _say(_error!);
      return;
    }
    try {
      final found = await availableCameras();
      if (!mounted) return;
      final rear = found.where(
        (item) => item.lensDirection == CameraLensDirection.back,
      );
      if (rear.isEmpty && found.isEmpty) {
        setState(() => _error = 'لا توجد عدسة على هذا الجهاز.');
        await _say(_error!);
        return;
      }
      final chosen = rear.isEmpty ? found.first : rear.first;
      final lens = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await lens.initialize();
      _scanner = BarcodeScanner();
      _lens = lens;
      await lens.startImageStream(_onFrame);
      if (!mounted) {
        await lens.dispose();
        _lens = null;
        return;
      }
      setState(() {});
      await _say('وجّه العدسة إلى الباركود.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر فتح العدسة. $error');
      await _say(_error!);
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_done || !mounted) return;
    final now = DateTime.now();
    final last = _lastFrame;
    if (last != null && now.difference(last).inMilliseconds < 400) return;
    _lastFrame = now;
    final lens = _lens;
    final scanner = _scanner;
    if (lens == null || scanner == null) return;
    final input = CameraStreamFrame.toInputImage(
      image: image,
      camera: lens.description,
      android: Platform.isAndroid,
    );
    if (input == null) return;
    try {
      final found = await scanner.processImage(input);
      if (_done || !mounted || found.isEmpty) return;
      final code = found.first;
      final read = BarcodeRead.fromLibrary(
        rawValue: code.rawValue,
        format: code.format,
      );
      final raw = read.raw.trim();
      if (raw.isEmpty) return;
      _done = true;
      await lens.stopImageStream();
      await _say(
        'قُرئ الرمز. النوع: ${read.formatName}. '
        'النص كما قرأته الكاميرا. لم يُفتح رابط ولم يُستنتج دواء.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(raw);
    } catch (_) {}
  }

  Widget _preview() {
    final lens = _lens;
    if (lens != null && lens.value.isInitialized) {
      return CameraPreview(lens);
    }
    if (_error != null) return const SizedBox.shrink();
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قراءة الباركود')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'يُحفظ نص الرمز كما قرأته الكاميرا. لا يُستنتج منه دواء أو تشخيص.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!),
            ),
          Expanded(child: _preview()),
        ],
      ),
    );
  }
}
