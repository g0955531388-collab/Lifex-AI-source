/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: live_sight_screen.dart
/// البث الحي يقرأ إطار العدسة الجاري. اللقطة الواحدة اختيار ظاهر.
/// الشرح بلغة هاتف المستخدم. إغلاق الصفحة يوقف العدسة.
/// =============================================================
library lifex_ai.screens.live_sight_screen;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/accessible_widgets.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_config.dart';
import '../core/permission_transparency.dart';
import '../features/accessibility/assistive_vision_engine.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/accessibility/blind_assist_gate.dart';
import '../features/accessibility/blind_camera_speech.dart';
import '../features/accessibility/blind_cloud_sight.dart';
import '../features/accessibility/gemini_bidi_session.dart';
import '../features/accessibility/gemini_live_link.dart';
import '../features/accessibility/internet_reachability.dart';
import '../features/accessibility/blind_frame_trace.dart';
import '../features/accessibility/blind_scene_brief.dart';
import '../features/accessibility/blind_walk_speech.dart';
import '../features/accessibility/capture_focus.dart';
import '../features/accessibility/camera_stream_frame.dart';
import '../features/accessibility/lifex_blind_vision_engine.dart';
import '../features/accessibility/live_vision_provider.dart';
import '../features/accessibility/live_sight_conductor.dart';
import '../features/accessibility/local_object_detector.dart';
import '../features/accessibility/scan_mode.dart';
import '../features/accessibility/visual_assist_floor.dart';
import '../features/accessibility/vision_engine_app.dart';
import '../features/spot/spot_speech.dart';
import '../features/voice/assistant_permission_desk.dart';
import '../features/voice/assistant_session.dart';
import '../features/voice/speech_queue.dart';
import '../features/voice/voice_engine.dart';
import '../features/voice/voice_turn_desk.dart';
import '../widgets/blind_camera_rail.dart';
import '../widgets/honesty_banner.dart';

enum BlindCameraDelivery { liveStream, singleFrame }

enum BlindCameraAsk { scene, text, both }

enum BlindCameraOrder {
  none,
  details,
  readText,
  pause,
  resume,
  front,
  back,
  cloud,
  barcode,
  grantCloud,
  revokeCloud,
}

class LiveSightScreen extends StatefulWidget {
  static int _openSessions = 0;

  static bool get isOpen => _openSessions > 0;

  const LiveSightScreen({
    super.key,
    required this.profileId,
    this.delivery = BlindCameraDelivery.liveStream,
    this.ask = BlindCameraAsk.both,
    this.readBarcode = false,
    this.initialOrder = BlindCameraOrder.none,
  });

  final String profileId;
  final BlindCameraDelivery delivery;
  final BlindCameraAsk ask;
  final bool readBarcode;
  final BlindCameraOrder initialOrder;

  @override
  State<LiveSightScreen> createState() => _LiveSightScreenState();
}

class _LiveSightScreenState extends State<LiveSightScreen> {
  final LiveSightConductor _conductor = LiveSightConductor();
  final LiveSightScheduler _scheduler = LiveSightScheduler(
    interval: const Duration(seconds: 4),
  );
  final CameraStreamReader _reader = CameraStreamReader();
  final BlindCloudSight _cloud = BlindCloudSight();
  final BlindAssistGate _railGate = BlindAssistGate();
  final SceneDoubleTap _doubleTap = SceneDoubleTap(
    window: const Duration(milliseconds: 300),
  );
  final BlindFrameTrace _trace = BlindFrameTrace();
  final LocalObjectDetector _detector = const LocalObjectDetector();
  final LifexBlindVisionEngine _vision = LifexBlindVisionEngine(
    localAnalyzer: const NoModelLocalVisionAnalyzer(),
    cloudAnalyzer: const ClosedCloudVisionAnalyzer(),
  );
  final GeminiLiveVisionProvider _geminiLive = GeminiLiveVisionProvider();
  final ExternalVisionHandoff _handoff = const ExternalVisionHandoff();
  final InternetReachability _reachability = const InternetReachability();

  CameraController? _lens;
  CameraDescription? _camera;
  /// الخلفية هي البداية. التبديل إلى الأمامية يتم بطلب صريح فقط.
  CameraLensDirection _direction = CameraLensDirection.back;
  BlindCameraDelivery _delivery = BlindCameraDelivery.liveStream;
  BlindCameraAsk _ask = BlindCameraAsk.both;
  bool _consented = false;
  bool _closed = false;
  bool _busy = false;
  bool _toldUnreadable = false;
  bool _barcodeOn = false;
  bool _cloudAllowed = false;
  Timer? _liveTimer;
  StreamSubscription<String>? _liveSpeech;
  GeminiBidiVisionSession? _bidi;
  bool _liveBusy = false;
  bool _toldLiveDown = false;
  bool _toldOffline = false;
  bool _geminiHasFloor = false;
  DateTime? _lastProbeAt;
  bool? _lastOnline;
  DateTime? _nextOpenAt;
  String _lastLiveSpeech = '';
  bool _earBusy = false;
  bool _detailLock = false;
  bool _hadFrame = false;
  bool _detectorRan = false;
  bool _toldDetectorMissing = false;
  bool _toldLocalModel = false;
  bool _strictDirection = true;
  bool _showOptions = false;
  bool _directGeminiTried = false;
  bool _externalLaunchFailed = false;
  Timer? _sceneTapTimer;
  int _generation = 0;
  double? _minZoom;
  double? _maxZoom;
  double _zoom = 1;
  bool _torchOn = false;
  var _handedToOther = false;
  var _hearingReady = false;
  var _welcomed = false;
  var _toldHearingGap = false;
  var _toldSpeechGap = false;
  var _toldCloudSending = false;
  String? _pendingOpening;
  String _languageCode = 'ar';
  List<String> _lastLabels = const [];
  String _lastReadText = '';
  String _sceneLine = '';
  String _heardHazardKey = '';
  bool _scanMode = true;
  List<String> _scanSpoken = const [];
  String _spoken =
      'هذه عدسة على الشاشة فقط. ليست تجسساً في الخلفية وليست تشخيصاً.';

  bool get _includeScene => _ask != BlindCameraAsk.text;

  bool get _includeText => _ask != BlindCameraAsk.scene;

  @override
  void initState() {
    super.initState();
    VisualAssistFloorSwitch.listen(_onVisualFloor);
    VisualAssistFloorSwitch.take(VisualAssistFloor.legacy);
    _delivery = widget.delivery;
    _ask = widget.ask;
    _barcodeOn = widget.readBarcode;
    if (widget.initialOrder == BlindCameraOrder.front) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }
    _strictDirection = true;
    LiveSightScreen._openSessions++;
    _useUserLanguage();
    unawaited(_loadCloudConsent());
    AssistantSession.instance.bindSight(
      repeat: _repeatLast,
      pause: _pauseNarration,
      resume: _resumeNarration,
      applyTurn: _applyTurn,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closed) unawaited(_askConsentThenOpen());
    });
  }

  void _useUserLanguage() {
    _languageCode =
        AppConfig.instance.defaultLanguage == AppLanguage.english ? 'en' : 'ar';
  }

  void _onVisualFloor(VisualAssistFloor floor) {
    if (floor == VisualAssistFloor.legacy || _handedToOther) return;
    _handedToOther = true;
    _closed = true;
    _liveTimer?.cancel();
    unawaited(_closeGeminiSession());
    _dropLens();
    unawaited(VoiceEngine.instance.interruptIfSpeaking());
    handOffVisualAssist(context, mounted: () => mounted);
  }

  void _stopSession() {
    if (_closed) return;
    _closed = true;
    _liveTimer?.cancel();
    unawaited(_closeGeminiSession());
    _dropLens();
    unawaited(VoiceEngine.instance.interruptIfSpeaking());
    final ear = VoiceEngine.instance.state;
    if (ear == VoiceEngineState.listening ||
        ear == VoiceEngineState.processing) {
      unawaited(VoiceEngine.instance.stopListening());
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  void _dropLens() {
    final lens = _lens;
    _lens = null;
    if (lens == null) return;
    if (lens.value.isStreamingImages) {
      lens.stopImageStream().whenComplete(lens.dispose);
    } else {
      lens.dispose();
    }
  }

  @override
  void dispose() {
    _closed = true;
    VisualAssistFloorSwitch.unlisten(_onVisualFloor);
    LiveSightScreen._openSessions =
        (LiveSightScreen._openSessions - 1).clamp(0, 1 << 30);
    _liveTimer?.cancel();
    _sceneTapTimer?.cancel();
    unawaited(_liveSpeech?.cancel());
    unawaited(_bidi?.close());
    debugPrint(_trace.stopped(DateTime.now(), 'مغادرة الشاشة'));
    AssistantSession.instance.unbindSight();
    _dropLens();
    unawaited(_reader.close());
    unawaited(_geminiLive.close());
    unawaited(VoiceEngine.instance.interruptIfSpeaking());
    final ear = VoiceEngine.instance.state;
    if (ear == VoiceEngineState.listening ||
        ear == VoiceEngineState.processing) {
      unawaited(VoiceEngine.instance.stopListening());
    }
    super.dispose();
  }

  Future<OsPermissionKind> _cameraKind() async {
    final status = await Permission.camera.status;
    return AssistantPermissionDesk.classify(
      granted: status.isGranted,
      blocked: status.isPermanentlyDenied || status.isRestricted,
    );
  }

  Future<OsPermissionKind> _requestCamera() async {
    final status = await Permission.camera.request();
    return AssistantPermissionDesk.classify(
      granted: status.isGranted,
      blocked: status.isPermanentlyDenied || status.isRestricted,
    );
  }

  Future<OsPermissionKind> _micKind() async {
    final status = await Permission.microphone.status;
    return AssistantPermissionDesk.classify(
      granted: status.isGranted,
      blocked: status.isPermanentlyDenied || status.isRestricted,
    );
  }

  Future<OsPermissionKind> _requestMic() async {
    final status = await Permission.microphone.request();
    return AssistantPermissionDesk.classify(
      granted: status.isGranted,
      blocked: status.isPermanentlyDenied || status.isRestricted,
    );
  }

  /// إذن النظام هو الموافقة. لا تُفتح العدسة قبله، ولا تُفتح شاشة إعداد.
  Future<void> _askConsentThenOpen() async {
    _useUserLanguage();
    final cameraNow = await _cameraKind();
    if (_closed || !mounted) return;
    if (cameraNow != OsPermissionKind.granted) {
      await _announce(VisualAssistOpening.cameraAsk(_languageCode));
      if (_closed || !mounted) return;
    }
    final allowed = await const AssistantPermissionDesk().ensure(
      read: _cameraKind,
      request: _requestCamera,
    );
    if (!mounted || _closed) return;
    if (!allowed) {
      debugPrint(
        _trace.fail(0, DateTime.now(), 'فتح الكاميرا', 'رفض الإذن'),
      );
      await _announce(BlindCameraSpeech.cameraDenied(_languageCode));
      return;
    }
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.camera,
      granted: true,
    );
    final micNow = await _micKind();
    if (_closed || !mounted) return;
    if (micNow != OsPermissionKind.granted) {
      await _announce(VisualAssistOpening.micAsk(_languageCode));
      if (_closed || !mounted) return;
    }
    final mic = await const AssistantPermissionDesk().ensure(
      read: _micKind,
      request: _requestMic,
    );
    if (!mounted || _closed) return;
    _hearingReady = mic;
    if (mic) {
      PermissionTransparencyManager.instance.decide(
        permission: LifexSensitivePermission.microphone,
        granted: true,
      );
    } else {
      _toldHearingGap = true;
      await _announce(VisualAssistOpening.micDenied(_languageCode));
    }
    if (!mounted || _closed) return;
    setState(() => _consented = true);
    await _attachLens();
  }

  void _queueOpening({required bool analysisReady}) {
    if (_welcomed || _pendingOpening != null || _closed) return;
    final streaming = _lens?.value.isStreamingImages == true;
    final speaking = VoiceEngine.instance.speakingBound;
    final hearing = _hearingReady && VoiceEngine.instance.listeningBound;
    final line = VisualAssistOpening.welcome(
      languageCode: _languageCode,
      cameraStreaming: streaming,
      analysisReady: analysisReady,
      hearingReady: hearing,
      speakingReady: speaking,
    );
    if (line != null) {
      _welcomed = true;
      _pendingOpening = line;
      return;
    }
    if (!analysisReady || !streaming) return;
    if (!speaking) {
      if (_toldSpeechGap) return;
      _toldSpeechGap = true;
      _pendingOpening = VisualAssistOpening.speechOff(_languageCode);
      return;
    }
    if (!hearing && !_toldHearingGap) {
      _toldHearingGap = true;
      _pendingOpening = VisualAssistOpening.hearingOff(_languageCode);
    }
  }

  String _takeOpening(String text) {
    final opening = _pendingOpening;
    _pendingOpening = null;
    if (opening == null || opening.trim().isEmpty) return text;
    if (text.trim().isEmpty) return opening;
    return '$opening\n$text';
  }

  Future<void> _attachLens() async {
    try {
      final found = await availableCameras();
      if (_closed || !mounted) return;
      if (found.isEmpty) {
        debugPrint(_trace.fail(0, DateTime.now(), 'فتح الكاميرا', 'لا عدسة'));
        await _announce(BlindCameraSpeech.noLens(_languageCode));
        return;
      }
      final match = found.where(
        (item) => item.lensDirection == _direction,
      );
      final CameraDescription? chosen = match.isNotEmpty
          ? match.first
          : (_strictDirection ? null : found.first);
      if (chosen == null) {
        await _announce(_missingLensPhrase());
        return;
      }
      _direction = chosen.lensDirection;
      await _releaseLens();
      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (_closed || !mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _lens = controller;
        _camera = chosen;
        _toldUnreadable = false;
        _torchOn = false;
      });
      _trace.opened(DateTime.now());
      debugPrint('BlindCamera ${_trace.notes.last}');
      await _readZoomRange(controller);
      if (_delivery == BlindCameraDelivery.liveStream) {
        await _startStream();
        final streaming = _lens?.value.isStreamingImages == true;
        if (!streaming) {
          await _announce(BlindCameraSpeech.lensFailed(_languageCode));
          return;
        }
      }
      await _announce(
        '${BlindCameraSpeech.lensOpen(
          _languageCode,
          live: _delivery == BlindCameraDelivery.liveStream,
        )} ${_lensName()}',
      );
      if (!GeminiBlindLink.held) await _forceDirectGemini();
      await _runInitialOrder();
    } catch (error) {
      if (_closed || !mounted) return;
      debugPrint(_trace.fail(0, DateTime.now(), 'فتح الكاميرا', 'تعذر التشغيل'));
      setState(() {
        _spoken = '${BlindCameraSpeech.lensFailed(_languageCode)}\n$error';
      });
      await VoiceEngine.instance
          .speak(BlindCameraSpeech.lensFailed(_languageCode));
    }
  }

  Future<void> _startStream() async {
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized || _closed) return;
    if (lens.value.isStreamingImages) return;
    await lens.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    final lens = _lens;
    if (lens == null || !lens.value.isStreamingImages) return;
    await lens.stopImageStream();
  }

  Future<void> _releaseLens() async {
    final lens = _lens;
    _lens = null;
    if (lens == null) return;
    if (lens.value.isStreamingImages) {
      await lens.stopImageStream();
    }
    await lens.dispose();
  }

  void _onFrame(CameraImage image) {
    if (_closed || _delivery != BlindCameraDelivery.liveStream) return;
    final camera = _camera;
    if (camera == null) return;
    _trace.receive(DateTime.now());
    final arrived = _trace.notes.isNotEmpty && _trace.received == 1
        ? _trace.notes.last
        : '';
    if (arrived.isNotEmpty) {
      debugPrint('BlindCamera $arrived');
      if (mounted) setState(() {});
    }
    if (!_scheduler.claim(DateTime.now())) return;
    final generation = ++_generation;
    final input = CameraStreamFrame.toInputImage(
      image: image,
      camera: camera,
      android: Platform.isAndroid,
    );
    if (input == null) {
      _scheduler.release();
      debugPrint(
        _trace.fail(generation, DateTime.now(), 'تحويل الإطار', 'تنسيق غير مقروء'),
      );
      if (_toldUnreadable) return;
      _toldUnreadable = true;
      unawaited(_announce(BlindCameraSpeech.unreadableFrame(_languageCode)));
      return;
    }
    _busy = true;
    unawaited(_explainStream(input, generation));
  }

  Future<void> _explainStream(InputImage input, int generation) async {
    final started = DateTime.now();
    try {
      final handed = _trace.deliver(generation, started);
      debugPrint('BlindCamera $handed');
      if (!handed.contains('نجح')) return;
      final reading = await _reader.read(
        input,
        includeScene: _includeScene,
        includeText: _includeText,
        includeBarcode: _barcodeOn,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      for (final hit in reading.hits) {
        if (hit.confidence < BlindSceneBrief.speechFloor) {
          debugPrint(
            'BlindCamera ${_trace.ignoreLow(generation, DateTime.now(), hit.label, hit.confidence)}',
          );
        }
      }
      final accepted = BlindSceneBrief.acceptedLabels(reading.hits);
      final resultLine = _trace.classifierReturned(
        sequence: generation,
        at: DateTime.now(),
        elapsedMs: elapsed,
        ok: reading.sceneRan,
        accepted: accepted.length,
        top: accepted.isEmpty ? '' : accepted.first,
        failure: reading.sceneRan ? '' : 'المصنّف لم يعد نتيجة',
      );
      debugPrint('BlindCamera $resultLine');
      final detection = _detector.run();
      _detectorRan = detection.ran;
      if (!detection.ran && !_toldDetectorMissing) {
        _toldDetectorMissing = true;
        debugPrint(
          _trace.fail(
            generation,
            DateTime.now(),
            'كشف الأجسام',
            'النموذج غير محمّل',
          ),
        );
      }
      if (_closed || !mounted || generation != _generation) return;
      _hadFrame = reading.sceneRan;
      final detectedLabels = [
        for (final object in detection.objects)
          if (object.hasBox &&
              object.confidence >= BlindSceneBrief.speechFloor)
            object.label,
      ];
      _lastLabels = detectedLabels.isNotEmpty
          ? detectedLabels
          : BlindSceneBrief.acceptedLabels(reading.hits);
      _lastReadText = reading.text;
      if (mounted) setState(() {});
      if (!_scheduler.narrationEnabled) return;
      var sceneLine = await _vision.analyzeClassifiedFrame(
        modelRan: reading.sceneRan,
        hits: reading.hits,
        reportUnavailable: !_toldLocalModel,
        languageCode: _languageCode,
      );
      if (!reading.sceneRan) _toldLocalModel = true;
      if (_closed || !mounted || generation != _generation) return;
      if (reading.sceneRan && sceneLine.trim().isEmpty) {
        sceneLine = VisualAssistOpening.unsure(_languageCode);
      }
      if (reading.sceneRan) _queueOpening(analysisReady: true);
      _sceneLine = sceneLine;
      await _speakReading(
        generation,
        sceneLine,
        reading.text,
        barcodes: reading.barcodes,
      );
    } catch (_) {
      debugPrint(
        _trace.classifierReturned(
          sequence: generation,
          at: DateTime.now(),
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
          ok: false,
          failure: 'استثناء أثناء التصنيف',
        ),
      );
      if (!_toldUnreadable && mounted && !_closed) {
        _toldUnreadable = true;
        await _announce(BlindCameraSpeech.unreadableFrame(_languageCode));
      }
    } finally {
      _busy = false;
      _scheduler.release();
    }
  }

  Future<void> _captureOnce() async {
    if (_busy || _closed) return;
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized) return;
    _busy = true;
    try {
      await _stopStream();
      await focusBeforeCapture(() => lens.setFocusMode(FocusMode.auto));
      final shot = await lens.takePicture();
      if (_closed || !mounted) return;
      if (!_scheduler.narrationEnabled) return;
      final engine = AssistiveVisionEngine.instance;
      final vision = await engine.process(
        imageOrFrameInput: await shot.readAsBytes(),
        type: _includeText && !_includeScene
            ? AssistiveFeatureType.textAndCurrencyReading
            : AssistiveFeatureType.sceneDescription,
        context: {
          'profileId': widget.profileId,
          'live': _includeScene,
          'imagePath': shot.path,
          'languageCode': _languageCode,
          'includeScene': _includeScene,
          'includeText': _includeText,
        },
      );
      if (_closed || !mounted) return;
      final spoken = BlindCameraSpeech.forDeviceLanguage(
        vision.spokenMessageAr,
        _languageCode,
      );
      setState(() => _spoken = spoken);
      if (!_scheduler.narrationEnabled) return;
      await VoiceEngine.instance.speak(spoken);
    } catch (error) {
      if (_closed || !mounted) return;
      setState(() {
        _spoken = '${BlindCameraSpeech.lensFailed(_languageCode)}\n$error';
      });
      await VoiceEngine.instance
          .speak(BlindCameraSpeech.lensFailed(_languageCode));
    } finally {
      _busy = false;
    }
  }

  void _pauseNarration() {
    _scheduler.narrationEnabled = false;
    unawaited(VoiceEngine.instance.speak('أوقفت الوصف.'));
  }

  void _resumeNarration() {
    _scheduler.narrationEnabled = true;
    unawaited(_announce('استأنفت الوصف.'));
  }

  void _repeatLast() {
    final pulse = _conductor.pulse(
      cameraReady: _open,
      userConsentedOnThisScreen: _consented,
      frameBytes: const [1],
      vision: AssistiveVisionResult(success: true, spokenMessageAr: _spoken),
      force: true,
    );
    unawaited(_announce(pulse.spokenAr));
  }

  bool get _zoomReady =>
      _minZoom != null && _maxZoom != null && _maxZoom! > _minZoom! + 0.05;

  Future<void> _readZoomRange(CameraController controller) async {
    try {
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      if (_closed || !mounted) return;
      setState(() {
        _minZoom = min;
        _maxZoom = max;
        _zoom = min;
      });
    } catch (_) {
      if (_closed || !mounted) return;
      setState(() {
        _minZoom = null;
        _maxZoom = null;
      });
    }
  }

  Future<void> _nudgeZoom(double delta) async {
    final lens = _lens;
    final min = _minZoom;
    final max = _maxZoom;
    if (lens == null || min == null || max == null || max <= min) {
      await _announce('التكبير غير متاح على هذه العدسة.');
      return;
    }
    final next = (_zoom + delta).clamp(min, max);
    try {
      await lens.setZoomLevel(next);
      if (!mounted || _closed) return;
      setState(() => _zoom = next);
      await _announce('التكبير ${next.toStringAsFixed(1)}.');
    } catch (_) {
      await _announce('تعذر تغيير التكبير على هذه العدسة.');
    }
  }

  Future<void> _toggleTorch() async {
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized) {
      await _announce('الفلاش غير متاح قبل فتح العدسة.');
      return;
    }
    final next = _torchOn ? FlashMode.off : FlashMode.torch;
    try {
      await lens.setFlashMode(next);
      if (!mounted || _closed) return;
      setState(() => _torchOn = next == FlashMode.torch);
      await _announce(_torchOn ? 'الفلاش يعمل.' : 'الفلاش متوقف.');
    } catch (_) {
      await _announce('الفلاش غير متاح على هذه العدسة.');
    }
  }

  Future<void> _autoFocus() async {
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized) {
      await _announce('التركيز غير متاح قبل فتح العدسة.');
      return;
    }
    try {
      await lens.setFocusMode(FocusMode.auto);
      await _announce('وضع التركيز التلقائي.');
    } catch (_) {
      await _announce('التركيز التلقائي غير متاح على هذه العدسة.');
    }
  }

  Future<void> _speakReading(
    int sequence,
    String sceneLine,
    String text, {
    List<String> barcodes = const [],
  }) async {
    _useUserLanguage();
    final arabic = BlindCameraSpeech.explainsInArabic(_languageCode);
    final scene = _includeScene
        ? BlindWalkSpeech.line(sceneLine, arabic: arabic)
        : '';
    final read = _ask == BlindCameraAsk.text
        ? BlindCameraSpeech.textFromRaw(text, languageCode: _languageCode)
        : '';
    final spoken = BlindCameraSpeech.forDeviceLanguage(
      [scene, read].where((part) => part.trim().isNotEmpty).join('\n'),
      _languageCode,
    );
    final codes = barcodes.where((code) => code.trim().isNotEmpty).toList();
    var sceneSpeech =
        codes.isEmpty ? spoken : '$spoken\nالرموز: ${codes.join('، ')}.';
    if (_scanMode && _includeScene) {
      final delta = scanSpeechDelta(previous: _scanSpoken, next: _lastLabels);
      _scanSpoken = List<String>.of(_lastLabels);
      if (delta.isEmpty && read.trim().isEmpty && codes.isEmpty) return;
      if (delta.isNotEmpty) {
        sceneSpeech = BlindWalkSpeech.line(delta.join('، '), arabic: arabic);
        if (codes.isNotEmpty) {
          sceneSpeech = '$sceneSpeech\nالرموز: ${codes.join('، ')}.';
        }
      }
    }
    if (sceneSpeech.trim().isEmpty && _pendingOpening == null) return;
    final hazardKey = BlindWalkSpeech.hazardKey(sceneSpeech);
    if (BlindWalkSpeech.yieldToCurrentSpeech(
      speaking: SpeechDesk.instance.queue.isSpeaking ||
          VoiceEngine.instance.state == VoiceEngineState.speaking,
      hazardKey: hazardKey,
      heardHazardKey: _heardHazardKey,
    )) {
      return;
    }
    final urgent = hazardKey.isNotEmpty && hazardKey != _heardHazardKey;
    if (urgent) _heardHazardKey = hazardKey;
    final pulse = _conductor.pulse(
      cameraReady: true,
      userConsentedOnThisScreen: _consented,
      frameBytes: const [1],
      vision: AssistiveVisionResult(
        success: true,
        spokenMessageAr: sceneSpeech,
      ),
    );
    if (!mounted || _closed) return;
    final ear = VoiceEngine.instance.state;
    if (ear == VoiceEngineState.listening ||
        ear == VoiceEngineState.processing) {
      debugPrint(
        'BlindCamera ${_trace.fail(sequence, DateTime.now(), 'نطق', 'الاستماع جارٍ')}',
      );
      return;
    }
    if ((!pulse.speakNow && _pendingOpening == null) ||
        !_scheduler.narrationEnabled) {
      debugPrint('BlindCamera ${_trace.skipRepeat(sequence, DateTime.now())}');
      return;
    }
    final voicedText = _takeOpening(pulse.spokenAr);
    setState(() => _spoken = voicedText);
    debugPrint('BlindCamera ${_trace.reachedSpeech(sequence, DateTime.now())}');
    if (!mounted || _closed || sequence != _generation) return;
    final accepted = urgent
        ? await SpeechDesk.instance.speakInterruptible(
            voicedText,
            hapticAfter: () => HapticFeedback.heavyImpact(),
          )
        : await SpeechDesk.instance.speakQueued(voicedText);
    if (!accepted && urgent && mounted && !_closed) {
      setState(() => _spoken = 'تعذّر النطق.\n$voicedText');
    }
  }

  Future<void> _speakDetails({String prefix = ''}) async {
    if (_detailLock || _closed) return;
    _detailLock = true;
    try {
      final body = !_detectorRan
          ? (_sceneLine.trim().isEmpty
              ? LocalObjectDetector.notInstalledAr
              : _sceneLine)
          : BlindSceneBrief.details(
              _lastLabels,
              hadFrame: _hadFrame,
              languageCode: _languageCode,
            );
      final lead = prefix.trim();
      await _announce(lead.isEmpty ? body : '$lead\n$body', urgent: true);
    } finally {
      _detailLock = false;
    }
  }

  void _onScenePointer(DateTime now) {
    if (_doubleTap.register(now)) {
      _sceneTapTimer?.cancel();
      unawaited(_freezeFrame());
      return;
    }
    _sceneTapTimer?.cancel();
    _sceneTapTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_closed) unawaited(_onSceneTap());
    });
  }

  Future<void> _onSceneTap() async {
    final scene = _sceneLine.trim();
    if (scene.isNotEmpty) {
      await _announce(BlindWalkSpeech.line(
        scene,
        arabic: BlindCameraSpeech.explainsInArabic(_languageCode),
      ));
      return;
    }
    final streaming = _lens?.value.isStreamingImages == true;
    final live = _bidi?.isReady == true;
    final hearing = _hearingReady && VoiceEngine.instance.listeningBound;
    if (streaming && hearing && (live || _hadFrame)) {
      await _announce(lifexUi(
        'المساعد في وضع الاستماع والبث الحي',
        'The assistant is listening and the live path is on.',
      ));
      return;
    }
    await _speakDetails();
  }

  Future<void> _freezeFrame() async {
    if (_closed) return;
    final lens = _lens;
    if (lens != null && lens.value.isInitialized) {
      await focusBeforeCapture(() => lens.setFocusMode(FocusMode.auto));
    }
    if (_closed) return;
    final hold = lifexUi('ثُبّت الإطار.', 'The frame is held.');
    await _speakDetails(prefix: hold);
  }

  Future<void> _stopFromScene() async {
    if (_closed) return;
    await _announce(
      lifexUi(
        'تم إيقاف المساعد البصري',
        'The visual assistant is stopped.',
      ),
      urgent: true,
    );
    _stopSession();
  }

  Future<void> _forceDirectGemini() async {
    if (_closed || GeminiBlindLink.held) return;
    if (_directGeminiTried) {
      if (_externalLaunchFailed && !_cloudAllowed) {
        await _setCloudAllowed(true);
      }
      return;
    }
    _directGeminiTried = true;
    final online = await _internetOnline(force: true);
    if (_closed) return;
    if (!online) {
      await _announce(lifexUi(
        'لا يوجد اتصال بالإنترنت. جاري تشغيل المساعد البصري المحلي المدمج',
        'No internet connection. Starting the built-in local visual assistant.',
      ));
      return;
    }
    final installed =
        await VisionAppChannel.installed(VisionEngines.gemini.packages);
    if (_closed) return;
    final route = directGeminiRoute(
      online: true,
      packageInstalled: installed,
    );
    if (route == DirectGeminiRoute.internal) {
      await _setCloudAllowed(true);
      return;
    }
    _dropLens();
    await _announce(lifexUi(
      'أهلاً بك، تم تفعيل اتصال جيمناي المباشر',
      'Welcome. The direct Gemini connection is on.',
    ));
    if (_closed) return;
    var code = 'missing';
    try {
      final opened = await const VisionAppDesk().open(VisionEngines.gemini);
      code = opened.code;
    } catch (_) {
      code = 'missing';
    }
    if (code == 'app' || code == 'view' || _closed) return;
    _externalLaunchFailed = true;
    if (!mounted || _closed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closed) unawaited(_attachLens());
    });
  }

  Future<void> _readStoredText() async {
    setState(() => _ask = BlindCameraAsk.text);
    if (!_hadFrame) {
      await _announce(BlindSceneBrief.noAnalysisAr);
      return;
    }
    final limit = BlindCameraSpeech.explainsInArabic(_languageCode)
        ? '${BlindSceneBrief.ocrLimitAr}\n'
        : '';
    await _announce(
      '$limit${BlindCameraSpeech.textFromRaw(_lastReadText, languageCode: _languageCode)}',
    );
  }

  String _lensName() {
    final rear = _direction == CameraLensDirection.back;
    if (BlindCameraSpeech.explainsInArabic(_languageCode)) {
      return rear ? 'العدسة الخلفية.' : 'العدسة الأمامية.';
    }
    return rear ? 'Rear camera.' : 'Front camera.';
  }

  String _missingLensPhrase() {
    final rear = _direction == CameraLensDirection.back;
    if (BlindCameraSpeech.explainsInArabic(_languageCode)) {
      return rear
          ? 'العدسة الخلفية غير متاحة. زر التبديل يفتح الأمامية إن وُجدت.'
          : 'العدسة الأمامية غير متاحة. زر التبديل يفتح الخلفية إن وُجدت.';
    }
    return rear
        ? 'The rear camera is not available. The switch opens the front camera if the device has one.'
        : 'The front camera is not available. The switch opens the rear camera if the device has one.';
  }

  String _switchLabel() {
    final rear = _direction == CameraLensDirection.back;
    if (BlindCameraSpeech.explainsInArabic(_languageCode)) {
      return rear
          ? 'العدسة الخلفية. اضغط للتبديل إلى الأمامية'
          : 'العدسة الأمامية. اضغط للتبديل إلى الخلفية';
    }
    return rear
        ? 'Rear camera. Press to switch to the front camera'
        : 'Front camera. Press to switch to the rear camera';
  }

  Future<void> _toggleLens() async {
    final next = _direction == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _switchDirection(next);
  }

  Future<void> _switchDirection(CameraLensDirection direction) async {
    _strictDirection = true;
    _direction = direction;
    await _attachLens();
  }

  static const _cloudConsentKey = 'lifex_blind_cloud_consent_v1';

  Future<void> _loadCloudConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final allowed = prefs.getBool(_cloudConsentKey) ?? false;
    if (!mounted || _closed) return;
    setState(() => _cloudAllowed = allowed);
    if (allowed) _startLiveLoop();
  }

  Future<void> _setCloudAllowed(bool allowed) async {
    if (!mounted || _closed) return;
    setState(() => _cloudAllowed = allowed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudConsentKey, allowed);
    if (!allowed) {
      _toldLiveDown = false;
      _toldOffline = false;
      _toldCloudSending = false;
      _nextOpenAt = null;
      _lastProbeAt = null;
      _geminiHasFloor = false;
      _scheduler.narrationEnabled = true;
      await _stopLive();
      await _announce(VisualAssistOpening.cloudStopped(_languageCode));
      return;
    }
    _startLiveLoop();
    await _tickLive();
  }

  void _startLiveLoop() {
    _liveTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickLive());
    });
  }

  Future<void> _closeGeminiSession() async {
    await _liveSpeech?.cancel();
    _liveSpeech = null;
    final session = _bidi;
    _bidi = null;
    await session?.close();
  }

  Future<void> _stopLive() async {
    _liveTimer?.cancel();
    _liveTimer = null;
    await _closeGeminiSession();
  }

  Future<bool> _internetOnline({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastProbeAt != null &&
        _lastOnline != null &&
        now.difference(_lastProbeAt!) < const Duration(seconds: 3)) {
      return _lastOnline!;
    }
    final online = await _reachability.online;
    _lastProbeAt = DateTime.now();
    _lastOnline = online;
    return online;
  }

  Future<void> _shutGeminiOffline({required bool wasOpen}) async {
    _toldOffline = true;
    _toldCloudSending = false;
    _nextOpenAt = null;
    final restoreLocal = _geminiHasFloor;
    _geminiHasFloor = false;
    if (wasOpen) {
      await _closeGeminiSession();
      await VoiceEngine.instance.stopSpeaking();
    }
    if (_closed) return;
    await _announce(
      VisualAssistOpening.offline(
        languageCode: _languageCode,
        wasOpen: wasOpen,
      ),
    );
    if (restoreLocal) _scheduler.narrationEnabled = true;
  }

  Future<void> _openLive() async {
    if (!mounted || _closed || !_cloudAllowed) return;
    LioSensitiveActionEntry? entry;
    try {
      entry = context.read<LioSensitiveActionEntry>();
    } catch (_) {
      entry = null;
    }
    if (entry == null) {
      await _sayLiveDown();
      return;
    }
    final outcome = await entry.openBlindLiveVision(
      gatewayRequest: LioGatewayRequest(
        requestId:
            'live_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
        correlationId: 'live_${widget.profileId}',
        identityAccountId: widget.profileId,
        purpose: 'blind_live_vision',
        requestedAction: 'open_gemini_live_vision',
        dataScope: 'camera_frame',
        sensitivity: LioDataSensitivity.operational,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: LioActionRisk.medium,
        timestamp: DateTime.now().toUtc(),
        authenticated: true,
        authorized: true,
        minimumNecessarySatisfied: true,
      ),
      profileId: widget.profileId,
    );
    if (!mounted || _closed || !_cloudAllowed) {
      await outcome.value?.close();
      return;
    }
    final session = outcome.executed ? outcome.value : null;
    if (session == null || !session.isReady) {
      await session?.close();
      await _sayLiveDown();
      return;
    }
    _bidi = session;
    _toldLiveDown = false;
    _nextOpenAt = null;
    _liveSpeech = session.spoken.listen((text) {
      if (_closed || !_cloudAllowed || text == _lastLiveSpeech) return;
      _lastLiveSpeech = text;
      unawaited(_handGemini(text));
    });
  }

  Future<void> _handGemini(String text) async {
    if (_welcomed && text.contains('انا اسمع وأرى') && text.length < 90) {
      return;
    }
    final first = !_geminiHasFloor;
    _geminiHasFloor = true;
    _scheduler.narrationEnabled = false;
    if (_closed || !_cloudAllowed || _toldOffline) return;
    await _announce(text, urgent: first);
  }

  Future<void> _sayLiveDown() async {
    if (_toldLiveDown || _closed) return;
    _toldLiveDown = true;
    _nextOpenAt = DateTime.now().add(const Duration(seconds: 8));
    if (_geminiHasFloor) {
      _geminiHasFloor = false;
      _scheduler.narrationEnabled = true;
    }
    await _announce(VisualAssistOpening.cloudDown(_languageCode));
  }

  Future<Uint8List?> _jpegSample() async {
    final lens = _lens;
    if (lens == null || !lens.value.isInitialized || _closed) return null;
    final wasStreaming = lens.value.isStreamingImages;
    try {
      if (wasStreaming) await lens.stopImageStream();
      await focusBeforeCapture(() => lens.setFocusMode(FocusMode.auto));
      final shot = await lens.takePicture();
      final bytes = await shot.readAsBytes();
      try {
        await File(shot.path).delete();
      } catch (_) {}
      return bytes;
    } catch (_) {
      return null;
    } finally {
      if (wasStreaming &&
          !_closed &&
          identical(_lens, lens) &&
          _delivery == BlindCameraDelivery.liveStream) {
        try {
          await lens.startImageStream(_onFrame);
        } catch (_) {}
      }
    }
  }

  Future<void> _tickLive() async {
    if (GeminiBlindLink.held) {
      if (_bidi != null) await _closeGeminiSession();
      return;
    }
    if (!_cloudAllowed || _closed || _liveBusy) return;
    _liveBusy = true;
    try {
      final online = await _internetOnline();
      if (_closed || !_cloudAllowed) return;
      final order = geminiLiveLinkOrder(
        consent: _cloudAllowed,
        online: online,
        sessionReady: _bidi?.isReady == true,
        announcedOffline: _toldOffline,
      );
      if (order.step == GeminiLiveLinkStep.close) {
        await _shutGeminiOffline(wasOpen: true);
        return;
      }
      if (order.step == GeminiLiveLinkStep.stayClosed) {
        if (order.announce) await _shutGeminiOffline(wasOpen: false);
        return;
      }
      if (order.step == GeminiLiveLinkStep.open && order.announce) {
        _toldOffline = false;
        _toldLiveDown = false;
        _nextOpenAt = null;
        _toldCloudSending = false;
      }
      if (order.step == GeminiLiveLinkStep.open &&
          _nextOpenAt != null &&
          DateTime.now().isBefore(_nextOpenAt!)) {
        return;
      }
      final lens = _lens;
      if (lens == null || !lens.value.isInitialized) return;
      if (_bidi == null || !_bidi!.isReady) {
        await _openLive();
      }
      final session = _bidi;
      if (session == null || !session.isReady || !_cloudAllowed) return;
      final jpeg = await _jpegSample();
      if (jpeg == null || jpeg.isEmpty || !_cloudAllowed || GeminiBlindLink.held) {
        if (GeminiBlindLink.held) await _closeGeminiSession();
        return;
      }
      if (!await _internetOnline()) {
        await _shutGeminiOffline(wasOpen: true);
        return;
      }
      final sent = await session.sendJpeg(jpeg);
      if (sent) {
        final welcomedBefore = _welcomed;
        _queueOpening(analysisReady: true);
        final opening = _pendingOpening;
        if (opening != null) {
          _pendingOpening = null;
          await _announce(opening);
        }
        if (welcomedBefore && !_toldCloudSending && !_closed) {
          _toldCloudSending = true;
          await _announce(VisualAssistOpening.cloudSending(_languageCode));
        }
        return;
      }
      await _closeGeminiSession();
      _lastProbeAt = null;
      final stillOnline = await _internetOnline(force: true);
      if (!stillOnline) {
        await _shutGeminiOffline(wasOpen: true);
        return;
      }
      await _sayLiveDown();
    } finally {
      _liveBusy = false;
    }
  }

  Future<void> _askCloud() async {
    if (!_cloudAllowed) {
      final answer = _cloud.ask(userAllowsCloud: false, online: null);
      await _announce(answer.spokenAr);
      return;
    }
    await _tickLive();
  }

  Future<void> _openEngineApp(String id) async {
    if (id == 'gemini' && !await _internetOnline(force: true)) {
      await _shutGeminiOffline(wasOpen: _bidi?.isReady == true);
      return;
    }
    await _announce(await _handoff.openEngine(id));
  }

  Future<void> _runInitialOrder() async {
    switch (widget.initialOrder) {
      case BlindCameraOrder.details:
        await _speakDetails();
      case BlindCameraOrder.readText:
        await _readStoredText();
      case BlindCameraOrder.pause:
        _pauseNarration();
      case BlindCameraOrder.resume:
        _resumeNarration();
      case BlindCameraOrder.front:
      case BlindCameraOrder.back:
        return;
      case BlindCameraOrder.cloud:
        await _askCloud();
      case BlindCameraOrder.grantCloud:
        await _setCloudAllowed(true);
      case BlindCameraOrder.revokeCloud:
        await _setCloudAllowed(false);
      case BlindCameraOrder.barcode:
        if (mounted && !_closed) setState(() => _barcodeOn = true);
        await _announce('قراءة الرمز مفعّلة على الإطار التالي.');
      case BlindCameraOrder.none:
        return;
    }
  }

  Future<void> _applyTurn(VoiceTurn turn) async {
    switch (turn.kind) {
      case VoiceTurnKind.pauseDescription:
        _pauseNarration();
      case VoiceTurnKind.resumeDescription:
        _resumeNarration();
      case VoiceTurnKind.details:
        await _speakDetails();
      case VoiceTurnKind.readText:
        await _readStoredText();
      case VoiceTurnKind.frontCamera:
        await _switchDirection(CameraLensDirection.front);
      case VoiceTurnKind.backCamera:
        await _switchDirection(CameraLensDirection.back);
      case VoiceTurnKind.askCloud:
        await _askCloud();
      case VoiceTurnKind.grantCloud:
        await _setCloudAllowed(true);
      case VoiceTurnKind.revokeCloud:
        await _setCloudAllowed(false);
      case VoiceTurnKind.openLens:
        await _openEngineApp('lens');
      case VoiceTurnKind.barcode:
        if (mounted && !_closed) setState(() => _barcodeOn = true);
        await _announce(
          turn.messageAr.isEmpty
              ? 'قراءة الرمز مفعّلة على الإطار التالي.'
              : turn.messageAr,
        );
      case VoiceTurnKind.scene:
      case VoiceTurnKind.openBlindCamera:
        await _announce(
          'كاميرا المكفوفين تعمل. الوصف الأساسي يُقال عند تغيّر المشهد.',
        );
        if (_cloudAllowed) await _tickLive();
      case VoiceTurnKind.slower:
        AssistantSession.instance.slowSpeech();
        await _announce(
          'أبطأت القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
        );
      case VoiceTurnKind.faster:
        AssistantSession.instance.raiseSpeech();
        await _announce(
          'رفعت سرعة القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
        );
      default:
        if (turn.messageAr.isNotEmpty) {
          await _announce(turn.messageAr);
        } else if (turn.kind == VoiceTurnKind.pass) {
          await _announce(
            'لم أفهم الأمر. جرّب: صف المشهد، أو اقرأ النص، أو عدسة جوجل، أو أوقف الوصف.',
          );
        }
    }
  }

  Future<void> _hearCommand() async {
    if (_earBusy || _closed) return;
    _earBusy = true;
    try {
      final result = await VoiceEngine.instance.listenFresh();
      if (!mounted || _closed) return;
      final heard = result.textResult?.trim() ?? '';
      if (heard.isEmpty) {
        await _announce(result.errorMessageAr ?? 'لم يصل أمر.');
        return;
      }
      await _applyTurn(planVoiceTurn(heard));
    } finally {
      _earBusy = false;
    }
  }

  Future<void> _announce(String text, {bool urgent = false}) async {
    _useUserLanguage();
    final spoken = BlindCameraSpeech.forDeviceLanguage(
      _takeOpening(text),
      _languageCode,
    );
    if (!mounted || _closed) return;
    setState(() => _spoken = spoken);
    if (urgent) {
      await SpeechDesk.instance.speakInterruptible(spoken);
      return;
    }
    await SpeechDesk.instance.speakQueued(spoken);
  }

  Future<void> _chooseDelivery(BlindCameraDelivery next) async {
    if (next == _delivery) return;
    setState(() => _delivery = next);
    if (_lens == null) return;
    if (next == BlindCameraDelivery.liveStream) {
      await _startStream();
      if (_lens?.value.isStreamingImages == true) {
        await _announce(BlindCameraSpeech.lensOpen(_languageCode, live: true));
      } else {
        await _announce(BlindCameraSpeech.lensFailed(_languageCode));
      }
    } else {
      await _stopStream();
      await _announce(BlindCameraSpeech.lensOpen(_languageCode, live: false));
    }
  }

  bool get _open {
    final lens = _lens;
    return lens != null && lens.value.isInitialized;
  }

  Future<void> _onRailZone(BlindRailZone zone) async {
    final step = _railGate.press(zone);
    if (step != BlindAssistStep.open) {
      if (mounted && !_closed) setState(() {});
      final ask = switch (zone) {
        BlindRailZone.assistant => BlindAssistGate.assistantAskAr,
        BlindRailZone.front => BlindAssistGate.frontAskAr,
        BlindRailZone.spot =>
          SpotSpeech.armAsk(SpotSpeech.deviceLanguage()),
      };
      await _announce(ask);
      return;
    }
    if (zone == BlindRailZone.spot) {
      final page = VisualAssistFloorSwitch.spotPage?.call();
      if (page == null || !mounted || _closed) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => page),
      );
      return;
    }
    if (mounted && !_closed) setState(() {});
    final direction = zone == BlindRailZone.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    if (_open) {
      if (_direction != direction) await _switchDirection(direction);
      return;
    }
    _direction = direction;
    _strictDirection = true;
    await _askConsentThenOpen();
  }

  Widget _scope(ThemeData theme) {
    final lens = _lens;
    final Widget child;
    if (lens != null && lens.value.isInitialized) {
      final preview = lens.value.previewSize;
      final width = preview?.height ?? 480;
      final height = preview?.width ?? 640;
      child = ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: CameraPreview(lens),
          ),
        ),
      );
    } else {
      child = ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            _consented ? 'العدسة لم تُهيأ بعد' : 'العدسة مغلقة حتى الموافقة',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: lifexUi(
        'مساحة المشهد. نقرة لما في الإطار. نقرتان لتثبيت الإطار وقراءته. الإيقاف من الزر السفلي',
        'Scene. One tap speaks the frame. Two taps hold it and read more. Stop is the lower button.',
      ),
      onTap: () => unawaited(_onSceneTap()),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onScenePointer(DateTime.now()),
        child: SizedBox.expand(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScreenArrival(
      message: lifexUi('كاميرا المكفوفين', 'Visual assistant'),
      controls: [
        lifexUi('ابدأ', 'Start'),
        lifexUi('التفاصيل', 'Details'),
        lifexUi('أوقف الوصف', 'Pause description'),
      ],
      body: _spoken.trim().isEmpty
          ? lifexUi(
              'الوصف الأساسي يأتي من الإطار الحالي. التفاصيل عند الطلب.',
              'The short description comes from the current frame. Details are on request.',
            )
          : _spoken,
      child: Scaffold(
      appBar: AppBar(
        title: Text(lifexUi('كاميرا المكفوفين', 'Visual assistant')),
        actions: [
          IconButton(
            tooltip: lifexUi(
              'إيقاف الكاميرا والصوت',
              'Stop the camera and speech',
            ),
            onPressed: () => unawaited(_stopFromScene()),
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlindCameraRail(
            armedZone: _railGate.armedZone,
            onZone: (zone) => unawaited(_onRailZone(zone)),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                _scope(theme),
                if (_showOptions)
                  const ColoredBox(color: Color(0xE6101010)),
                if (_showOptions)
                  ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'مساعدة إضافية فقط. ليست بديلاً عن العصا البيضاء أو كلب الإرشاد، وليست تشخيصاً طبياً.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لغة الشرح: $_languageCode',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'البث الحي هو الإطار الجاري. اللقطة الواحدة لا تتكرر وحدها.',
                  ),
                  const SizedBox(height: 12),
                  Text('ماذا تفتح؟', style: theme.textTheme.titleSmall),
                  RadioListTile<BlindCameraDelivery>(
                    title: const Text('بث حي'),
                    subtitle: const Text('الإطار الجاري، ويُشرح حين يتغير'),
                    value: BlindCameraDelivery.liveStream,
                    groupValue: _delivery,
                    onChanged: (value) {
                      if (value != null) unawaited(_chooseDelivery(value));
                    },
                  ),
                  RadioListTile<BlindCameraDelivery>(
                    title: const Text('لقطة واحدة'),
                    subtitle: const Text('تُلتقط حين تضغط، ولا تتكرر وحدها'),
                    value: BlindCameraDelivery.singleFrame,
                    groupValue: _delivery,
                    onChanged: (value) {
                      if (value != null) unawaited(_chooseDelivery(value));
                    },
                  ),
                  Text('ماذا يُشرح؟', style: theme.textTheme.titleSmall),
                  RadioListTile<BlindCameraAsk>(
                    title: const Text('المشهد'),
                    value: BlindCameraAsk.scene,
                    groupValue: _ask,
                    onChanged: (value) {
                      if (value != null) setState(() => _ask = value);
                    },
                  ),
                  RadioListTile<BlindCameraAsk>(
                    title: const Text('النص'),
                    value: BlindCameraAsk.text,
                    groupValue: _ask,
                    onChanged: (value) {
                      if (value != null) setState(() => _ask = value);
                    },
                  ),
                  RadioListTile<BlindCameraAsk>(
                    title: const Text('المشهد والنص'),
                    value: BlindCameraAsk.both,
                    groupValue: _ask,
                    onChanged: (value) {
                      if (value != null) setState(() => _ask = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(lifexUi(
                      'اتصال جيميني الحي',
                      'Gemini live connection',
                    )),
                    subtitle: Text(lifexUi(
                      'يفتح مع الكاميرا عند وجود الإنترنت. الإيقاف يقطع الإرسال. '
                      'الوصف ليس تشخيصاً ولا قياس مسافة.',
                      'It opens with the camera when the internet is available. '
                      'Stopping cuts the sending. The description is not a diagnosis and not a distance.',
                    )),
                    value: _cloudAllowed,
                    onChanged: (value) => unawaited(_setCloudAllowed(value)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _askConsentThenOpen,
            icon: const Icon(Icons.videocam_outlined),
            label: Text(_open ? 'العدسة مفتوحة على هذه الصفحة' : 'ابدأ'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _repeatLast,
                child: Text(lifexUi('أعد الوصف', 'Repeat the description')),
              ),
              OutlinedButton(
                onPressed: _speakDetails,
                child: Text(lifexUi('التفاصيل', 'Details')),
              ),
              OutlinedButton(
                onPressed: _hearCommand,
                child: const Text('استمع للأمر'),
              ),
              OutlinedButton(
                onPressed: () => _switchDirection(CameraLensDirection.front),
                child: const Text('أمامية'),
              ),
              OutlinedButton(
                onPressed: () => _switchDirection(CameraLensDirection.back),
                child: const Text('خلفية'),
              ),
              OutlinedButton(
                onPressed: _askCloud,
                child: const Text('اسأل السحابة'),
              ),
              OutlinedButton(
                onPressed: () => _openEngineApp('lens'),
                child: const Text('عدسة Google'),
              ),
              OutlinedButton(
                onPressed: () => _openEngineApp('gemini'),
                child: const Text('تطبيق جيميني'),
              ),
              OutlinedButton(
                onPressed: () => _openEngineApp('copilot'),
                child: const Text('تطبيق كوبايلوت'),
              ),
              OutlinedButton(
                onPressed: () => _openEngineApp('chatgpt'),
                child: const Text('تطبيق شات جي بي تي'),
              ),
              OutlinedButton(
                onPressed: () => _openEngineApp('claude'),
                child: const Text('تطبيق كلود'),
              ),
              OutlinedButton(
                onPressed: _pauseNarration,
                child: const Text('أوقف الوصف'),
              ),
              OutlinedButton(
                onPressed: _resumeNarration,
                child: const Text('استأنف الوصف'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _scheduler.interval = const Duration(seconds: 2);
                }),
                child: const Text('كل ثانيتين'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _scanMode = !_scanMode;
                  if (_scanMode) {
                    _scheduler.interval = const Duration(seconds: 4);
                    _scanSpoken = const [];
                  }
                }),
                child: Text(_scanMode ? 'وضع المسح يعمل' : 'وضع المسح'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _scheduler.interval = const Duration(seconds: 4);
                }),
                child: const Text('كل 4 ثوانٍ'),
              ),
              if (_zoomReady) ...[
                Semantics(
                  button: true,
                  label: 'قرّب العدسة',
                  child: OutlinedButton(
                    onPressed: () => _nudgeZoom(0.5),
                    child: const Text('قرّب'),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'بعّد العدسة',
                  child: OutlinedButton(
                    onPressed: () => _nudgeZoom(-0.5),
                    child: const Text('بعّد'),
                  ),
                ),
              ],
              Semantics(
                button: true,
                label: _torchOn ? 'أوقف الفلاش' : 'جرّب الفلاش',
                child: OutlinedButton(
                  onPressed: _toggleTorch,
                  child: Text(_torchOn ? 'الفلاش يعمل' : 'جرّب الفلاش'),
                ),
              ),
              Semantics(
                button: true,
                label: 'تركيز تلقائي',
                child: OutlinedButton(
                  onPressed: _autoFocus,
                  child: const Text('ركّز'),
                ),
              ),
              Semantics(
                button: true,
                label: _barcodeOn ? 'إيقاف قراءة الرمز' : 'قراءة الباركود',
                child: OutlinedButton(
                  onPressed: () => setState(() => _barcodeOn = !_barcodeOn),
                  child: Text(_barcodeOn ? 'الرمز مفعّل' : 'اقرأ الرمز'),
                ),
              ),
            ],
          ),
          if (_delivery == BlindCameraDelivery.singleFrame && _open) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _captureOnce,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('التقط واشرح'),
            ),
          ],
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(_spoken, style: theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 8),
          Text(_trace.statusAr()),
        ],
                  ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: 1,
                  height: 1,
                  child: Semantics(
                    liveRegion: true,
                    label: _spoken,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Semantics(
                    button: true,
                    label: _switchLabel(),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: FloatingActionButton(
                        heroTag: 'blind-assist-lens',
                        tooltip: _switchLabel(),
                        onPressed: () => unawaited(_toggleLens()),
                        child: const Icon(Icons.cameraswitch_outlined),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Semantics(
                    button: true,
                    label: _showOptions
                        ? 'إخفاء خيارات المساعد البصري'
                        : 'خيارات المساعد البصري',
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: FloatingActionButton(
                        heroTag: 'blind-assist-options',
                        onPressed: () =>
                            setState(() => _showOptions = !_showOptions),
                        child: Icon(_showOptions ? Icons.close : Icons.tune),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
