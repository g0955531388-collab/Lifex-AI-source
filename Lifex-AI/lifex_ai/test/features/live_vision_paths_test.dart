import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/error_handler.dart';
import 'package:lifex_ai/features/accessibility/blind_scene_brief.dart';
import 'package:lifex_ai/features/accessibility/lifex_blind_vision_engine.dart';
import 'package:lifex_ai/features/accessibility/live_sight_conductor.dart';
import 'package:lifex_ai/features/accessibility/live_vision_provider.dart';
import 'package:lifex_ai/features/accessibility/vision_engine_app.dart';

void main() {
  test('تصنيف الصورة ليس موقع جسم ولا يذكر باباً لم يظهر', () {
    final line = BlindSceneBrief.classificationSpeech(const [
      SceneHit('Person', 0.8),
      SceneHit('Dog', 0.9),
      SceneHit('Car', 0.7),
      SceneHit('Door', 0.2),
    ]);
    expect(line, 'شخص، سيارة');
    expect(line, isNot(contains('كلب')));
    expect(line, contains('شخص'));
    expect(line, contains('سيارة'));
    expect(line.contains('باب'), isFalse);
    expect(line.contains('متر'), isFalse);
    expect(line.contains('أمامك'), isFalse);
  });

  test('ثقة منخفضة أو مصنّف صامت لا يتحول إلى كشف', () async {
    final engine = LifexBlindVisionEngine(
      localAnalyzer: const NoModelLocalVisionAnalyzer(),
      cloudAnalyzer: const ClosedCloudVisionAnalyzer(),
    );
    final low = await engine.analyzeClassifiedFrame(
      modelRan: true,
      hits: const [SceneHit('Person', 0.4)],
    );
    expect(low, isEmpty);
    final before = ErrorHandler.instance.errorLog.length;
    final missing = await engine.analyzeClassifiedFrame(
      modelRan: false,
      hits: const [SceneHit('Person', 0.9)],
    );
    expect(missing, LifexBlindVisionEngine.localUnavailableAr);
    expect(missing.contains('أمامك'), isFalse);
    final added = ErrorHandler.instance.errorLog.skip(before);
    expect(added.map((error) => error.code), contains('LOCAL_MODEL_UNAVAILABLE'));
  });

  test('نجاح التصنيف لا يستدعي السحابة', () async {
    final cloud = _Cloud();
    final engine = LifexBlindVisionEngine(
      localAnalyzer: const NoModelLocalVisionAnalyzer(),
      cloudAnalyzer: cloud,
    );
    final line = await engine.analyzeClassifiedFrame(
      modelRan: true,
      hits: const [SceneHit('Bus', 0.9)],
    );
    expect(line, contains('حافلة'));
    expect(cloud.calls, 0);
    final still = await engine.analyzeScene(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      allowCloud: false,
    );
    expect(still, LifexBlindVisionEngine.unsureAr);
    expect(cloud.calls, 0);
  });

  test('Gemini Live بلا رمز لا يرسل الإطار', () async {
    final gemini = GeminiLiveVisionProvider();
    final opened = await gemini.open();
    expect(opened.phase, LiveVisionPhase.unconfigured);
    expect(opened.framesLeaveDevice, isFalse);
    final sent = await gemini.sendFrame(Uint8List.fromList([1, 2, 3]));
    expect(sent.framesLeaveDevice, isFalse);
    expect(sent.spokenAr, contains('لم يُرسل'));
    final closed = await gemini.close();
    expect(closed.phase, LiveVisionPhase.stopped);
  });

  test('فتح Gemini الخارجي لا يدّعي نقل البث', () async {
    final handoff = ExternalVisionHandoff(
      desk: VisionAppDesk(opener: (packages, viewUrl) async {
        expect(packages, contains('com.google.android.apps.bard'));
        expect(viewUrl, isNotEmpty);
        return 'view';
      }),
    );
    final spoken = await handoff.openGemini();
    expect(spoken, contains('وليس على موقع'));
    expect(spoken, contains('لم يؤكد اتصال فيديو'));
  });

  test('عدسة Google تُفتح كتطبيق لا كموقع', () async {
    final engine = VisionEngines.byId('lens');
    expect(engine.packages, contains('com.google.ar.lens'));
    expect(engine.packages, contains('com.google.android.googlequicksearchbox'));
    expect(engine.viewUrl, 'google://lens');
    expect(engine.viewUrl.startsWith('https'), isFalse);
    final handoff = ExternalVisionHandoff(
      desk: VisionAppDesk(opener: (packages, viewUrl) async {
        expect(packages.first, 'com.google.ar.lens');
        expect(viewUrl, 'google://lens');
        return 'view:${packages.first}';
      }),
    );
    final spoken = await handoff.openLens();
    expect(spoken, contains('وليس على موقع'));
    expect(spoken, contains('ليس تشخيصاً'));
    expect(spoken, contains('لم ينقل'));
  });

  test('الإطار المشغول لا يكدّس استدلالاً ثانياً', () {
    final scheduler = LiveSightScheduler();
    final now = DateTime.utc(2026, 10, 15, 2);
    expect(scheduler.claim(now), isTrue);
    expect(scheduler.claim(now.add(const Duration(seconds: 3))), isFalse);
    scheduler.release();
    expect(
      scheduler.claim(now.add(const Duration(seconds: 3))),
      isTrue,
    );
  });

  test('اتصال جيميني المباشر إلزامي عند الإنترنت ويسقط للمحلي عند الانقطاع', () {
    expect(
      directGeminiRoute(online: false, packageInstalled: true),
      DirectGeminiRoute.local,
    );
    expect(
      directGeminiRoute(online: true, packageInstalled: true),
      DirectGeminiRoute.external,
    );
    expect(
      directGeminiRoute(online: true, packageInstalled: false),
      DirectGeminiRoute.internal,
    );
  });
}

class _Cloud implements CloudVisionAnalyzer {
  int calls = 0;

  @override
  Future<String?> analyze(Uint8List imageBytes, String prompt) async {
    calls++;
    return 'سحابة';
  }
}
