/// منسّق أوضاع الكاميرا من دليل كيمي، على محركات Lifex.
/// كشف الأجسام غير المحمّل يُقال كما هو. فراغ الإطار ليس طريقاً آمناً.
/// تصعيد نص الشاشة إلى الطوارئ يتم بعد تأكيد المستخدم فقط.
library lifex_ai.features.camera_ai.camera_intelligence_engine;

import 'dart:async';

import '../accessibility/blind_scene_brief.dart';
import '../accessibility/camera_stream_frame.dart';
import '../accessibility/local_object_detector.dart';
import '../accessibility/multi_sensory_alert_manager.dart';
import '../emergency/emergency_manager.dart';
import '../emergency/emergency_message_manager.dart';
import 'cloud/live_camera_provider.dart';
import 'live/live_camera_feed.dart';
import 'medical/barcode_medicine_reader.dart';
import 'medical/medical_image_analyzer.dart';
import 'medical/medical_monitor_reader.dart';
import 'reading/universal_text_reader.dart';
import 'scene/scene_understanding_engine.dart';
import 'scene/tts_announcer.dart';

enum CameraAiMode {
  assistiveWalking,
  universalReading,
  monitorWatch,
  medicineScan,
  medicalImaging,
}

class CameraIntelligenceEngine {
  CameraIntelligenceEngine({
    required this.announcer,
    required this.sceneEngine,
    required this.monitorReader,
    required this.multiSensoryAlerts,
    required this.emergencyManager,
    required this.textReader,
    required this.barcodeReader,
    required this.imageAnalyzer,
    required this.objectDetector,
    this.liveFeed,
    this.openCloud,
    this.onEmergencyEscalation,
  });

  final TtsAnnouncer announcer;
  final SceneUnderstandingEngine sceneEngine;
  final MedicalMonitorReader monitorReader;
  final MultiSensoryAlertManager multiSensoryAlerts;
  final EmergencyManager emergencyManager;
  final UniversalTextReader textReader;
  final BarcodeMedicineReader barcodeReader;
  final MedicalImageAnalyzer imageAnalyzer;
  final LocalObjectDetector objectDetector;
  final LiveCameraFeed? liveFeed;
  final LiveCameraProvider Function(String profileId)? openCloud;
  final Future<void> Function(String reasonAr)? onEmergencyEscalation;

  final CameraStreamReader _streamReader = CameraStreamReader();
  CameraAiMode _mode = CameraAiMode.assistiveWalking;
  Timer? _sceneTicker;
  String _lastWalkingSpeech = '';
  LiveCameraProvider? _cloud;

  CameraAiMode get mode => _mode;

  Future<void> setMode(CameraAiMode newMode) async {
    _mode = newMode;
    _sceneTicker?.cancel();
    _sceneTicker = null;
    await announcer.announce(
      'وضع الكاميرا: ${_modeAr(newMode)}.',
      priority: AnnouncePriority.important,
    );
    if (newMode == CameraAiMode.assistiveWalking) {
      _sceneTicker = Timer.periodic(const Duration(seconds: 5), (_) {
        final last = _lastWalkingSpeech.trim();
        if (last.isEmpty) return;
        unawaited(announcer.announce(last));
      });
    }
  }

  /// إطار المشي: أسماء التصنيف إن وُجدت، وجملة كاشف الأجسام إن لم يُحمَّل.
  /// أوضاع القراءة تنتظر لقطة ثابتة ولا تحلّل كل إطار.
  Future<void> onLiveFrame(AnalyzableFrame frame) async {
    if (_mode != CameraAiMode.assistiveWalking) return;
    final image = CameraStreamFrame.fromPackedNv21(
      bytes: frame.nv21Bytes,
      width: frame.width,
      height: frame.height,
      rotationDegrees: frame.rotationDegrees,
    );
    final names = StringBuffer();
    if (image != null) {
      final reading = await _streamReader.read(
        image,
        includeScene: true,
        includeText: false,
      );
      names.write(BlindSceneBrief.classificationSpeech(reading.hits));
    }
    final detection = objectDetector.run();
    final spoken = StringBuffer();
    if (names.isNotEmpty) spoken.write(names.toString());
    if (!detection.ran) {
      if (spoken.isNotEmpty) spoken.write(' ');
      spoken.write(detection.reasonAr);
    }
    final phrase = spoken.toString().trim();
    if (phrase.isEmpty) return;
    _lastWalkingSpeech = phrase;
    await announcer.announce(phrase);
  }

  SceneLayout describe(List<SceneElement> elements) {
    return sceneEngine.buildLayout(elements);
  }

  Future<UniversalReadResult> readStill(List<int> imageBytes) {
    return textReader.read(imageBytes);
  }

  Future<BarcodeScanResult> scanMedicineFile(String imagePath) {
    return barcodeReader.scanFromImagePath(imagePath);
  }

  MonitorScreenAnalysis readMonitorText(String ocrText) {
    return monitorReader.analyzeText(ocrText);
  }

  MedicalImageAnalysisResult readMedicalText(String ocrText) {
    return imageAnalyzer.analyzeReadText(ocrText);
  }

  /// تنبيه حسي ونطق. لا يفتح حالة طوارئ.
  /// [autoMonitoringEnabled] يستدعي الوصلة الاختيارية فقط، وهي غير مربوطة
  /// في الإقلاع حتى لا تُرسل رسالة طوارئ من رقم مقروء قد يكون خطأ.
  Future<void> escalateVitalsIfNeeded(
    MonitorScreenAnalysis analysis, {
    bool autoMonitoringEnabled = false,
  }) async {
    if (!analysis.hasCritical) return;
    await multiSensoryAlerts.triggerAlert(AlertSeverityForSenses.critical);
    await announcer.alertCritical(
      'تنبيه: رقم مقروء من شاشة خارج مدى المقارنة. ${analysis.summaryAr} '
      'هذا ليس قياساً من الهاتف ولا استدعاء طوارئ حتى تؤكد.',
    );
    monitorReader.reportScreenTextOutsideRange(analysis);
    if (autoMonitoringEnabled) {
      await onEmergencyEscalation?.call(analysis.summaryAr);
    }
  }

  /// تأكيد المستخدم فقط هو الذي يفتح حالة الطوارئ القائمة.
  Future<EmergencyDispatchOutcome?> confirmMonitorEscalation({
    required String profileId,
    required MonitorScreenAnalysis analysis,
  }) {
    if (!analysis.hasCritical || profileId.trim().isEmpty) {
      return Future.value();
    }
    return emergencyManager.triggerEmergency(
      profileId: profileId,
      reasonAr:
          'المستخدم أكّد تصعيد نص مقروء من شاشة. ${analysis.summaryAr}',
    );
  }

  Future<LiveSessionState> connectCloud({required String profileId}) async {
    final opener = openCloud;
    if (opener == null || profileId.trim().isEmpty) {
      return LiveSessionState.localFallback;
    }
    await _cloud?.disconnect();
    _cloud = opener(profileId);
    await _cloud!.connect();
    return _cloud!.state;
  }

  Future<void> shutdown() async {
    _sceneTicker?.cancel();
    _sceneTicker = null;
    await _streamReader.close();
    await liveFeed?.dispose();
    await _cloud?.disconnect();
    _cloud = null;
  }

  static String _modeAr(CameraAiMode mode) => {
        CameraAiMode.assistiveWalking: 'المشي المساعد',
        CameraAiMode.universalReading: 'القراءة',
        CameraAiMode.monitorWatch: 'نص شاشة المراقبة',
        CameraAiMode.medicineScan: 'مسح الأدوية',
        CameraAiMode.medicalImaging: 'نص الوثائق الطبية',
      }[mode]!;
}
