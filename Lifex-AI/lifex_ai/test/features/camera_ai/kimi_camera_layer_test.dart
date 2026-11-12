import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/config/app_secrets.dart';
import 'package:lifex_ai/features/accessibility/camera_stream_frame.dart';
import 'package:lifex_ai/features/camera_ai/cloud/live_camera_provider.dart';
import 'package:lifex_ai/features/camera_ai/medical/barcode_medicine_reader.dart';
import 'package:lifex_ai/features/camera_ai/medical/medical_image_analyzer.dart';
import 'package:lifex_ai/features/camera_ai/medical/medical_monitor_reader.dart';
import 'package:lifex_ai/features/camera_ai/reading/universal_text_reader.dart';
import 'package:lifex_ai/features/camera_ai/scene/scene_understanding_engine.dart';

void main() {
  test('empty center is not called an open path', () {
    const engine = SceneUnderstandingEngine();
    final layout = engine.buildLayout(const [
      SceneElement(
        labelAr: 'رصيف',
        category: SceneCategory.sidewalk,
        zone: SpatialZone.right,
        confidence: 0.8,
        sizeRatio: 0.2,
      ),
    ]);
    expect(layout.spokenSummaryAr, contains('على يمينك'));
    expect(layout.spokenSummaryAr, contains('في الإطار'));
    expect(layout.spokenSummaryAr.contains('مفتوح'), isFalse);
    expect(layout.spokenSummaryAr.contains('آمن'), isFalse);
  });

  test('barcode matches the full code only', () {
    final reader = BarcodeMedicineReader(
      gtinToMedicationIdMap: const {'06281234567890': 'med-9'},
    );
    expect(
      reader.lookup('06281234567890').matchedMedicationId,
      'med-9',
    );
    expect(reader.lookup('1234567890').fallbackToOcr, isTrue);
    expect(reader.lookup('').fallbackToOcr, isTrue);
  });

  test('screen text outside the written range is not a phone measurement', () {
    final reader = MedicalMonitorReader();
    final seen = reader.analyzeText('SpO2 85 HR 72');
    expect(seen.hasCritical, isTrue);
    expect(seen.summaryAr, contains('ليست قياساً'));
    expect(seen.summaryAr, contains('85'));
    final empty = reader.analyzeText('لا أرقام');
    expect(empty.worstLevel, VitalAlertLevel.unread);
    expect(empty.summaryAr.contains('ضمن المطلوب'), isFalse);
    expect(empty.summaryAr, contains('ليس قياساً'));
  });

  test('a keyword is an unverified guess and not an image reading', () {
    const analyzer = MedicalImageAnalyzer();
    final result = analyzer.analyzeReadText('Chest x-ray report. tumor seen.');
    expect(result.modality, MedicalImagingModality.xray);
    expect(result.needsDoctorReview, isTrue);
    expect(result.summaryAr, contains('تخمين غير مؤكد'));
    expect(result.summaryAr, contains('ليس تفسيراً'));
    expect(result.summaryAr.contains('تشخيص مؤكد'), isFalse);
  });

  test('cloud text is used only when enabled and longer', () async {
    var calls = 0;
    final reader = UniversalTextReader(
      cloudEnabled: true,
      localReader: (_) async => 'أب',
      cloudClient: _Cloud((_) async {
        calls++;
        return 'أبجدية مقروءة من الخدمة';
      }),
    );
    final result = await reader.read(const [1, 2, 3]);
    expect(calls, 1);
    expect(result.source, 'cloud');
    expect(result.detectedLanguageNoteAr, contains('قد يخطئ'));
    expect(result.detectedLanguageNoteAr, contains('ليس تأكيداً'));
  });

  test('latin text stays on device', () async {
    var calls = 0;
    final reader = UniversalTextReader(
      cloudEnabled: true,
      localReader: (_) async => 'PARACETAMOL 500',
      cloudClient: _Cloud((_) async {
        calls++;
        return 'should not run';
      }),
    );
    final result = await reader.read(const [9]);
    expect(calls, 0);
    expect(result.source, 'on-device');
    expect(result.text, 'PARACETAMOL 500');
  });

  test('empty vision key does not call the network', () async {
    expect(AppSecrets.googleVisionApiKey, isEmpty);
    final client = GoogleCloudVisionClient();
    expect(await client.readTextFromImageBase64('abcd'), isNull);
  });

  test('a short gemini key stays on the local camera', () async {
    var started = false;
    final provider = GeminiLiveProvider(
      profileId: 'profile',
      readApiKey: () async => 'too-short',
      announcer: (_) async {},
      startSession: ({required apiKey, required model}) async {
        started = true;
        return null;
      },
    );
    await provider.connect();
    expect(started, isFalse);
    expect(provider.state, LiveSessionState.localFallback);
  });

  test('packed nv21 needs a known quarter turn', () {
    expect(
      CameraStreamFrame.fromPackedNv21(
        bytes: Uint8List(16),
        width: 4,
        height: 2,
        rotationDegrees: 45,
      ),
      isNull,
    );
  });
}

class _Cloud implements CloudOcrClient {
  _Cloud(this._read);

  final Future<String?> Function(String image) _read;

  @override
  Future<String?> readTextFromImageBase64(String base64Jpeg) => _read(base64Jpeg);
}
