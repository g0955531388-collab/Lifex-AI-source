import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_camera_speech.dart';
import 'package:lifex_ai/features/accessibility/blind_cloud_sight.dart';
import 'package:lifex_ai/features/accessibility/blind_frame_trace.dart';
import 'package:lifex_ai/features/accessibility/blind_scene_brief.dart';
import 'package:lifex_ai/features/accessibility/live_sight_conductor.dart';
import 'package:lifex_ai/features/voice/voice_turn_desk.dart';

void main() {
  test('الوصف الأساسي يقدّم الشخص والسيارة ويبعد تفاصيل الوجه', () {
    final spoken = BlindSceneBrief.primary(
      const ['Smile', 'Woman', 'Teeth', 'Car'],
    );
    expect(spoken, contains('امرأة'));
    expect(spoken, contains('سيارة'));
    expect(spoken, isNot(contains('ابتسامة')));
    expect(spoken, isNot(contains('متوقفة')));
    expect(spoken, isNot(contains('تتحرك')));
    expect(BlindSceneBrief.primary(const ['Person']), 'شخص');
    expect(BlindSceneBrief.primary(const ['Person', 'Dog']), 'شخص');
    expect(BlindSceneBrief.primary(const ['Dog']), 'كلب');
    expect(BlindSceneBrief.primary(const ['Table', 'Chair']), contains('طاولة'));
    expect(BlindSceneBrief.primary(const ['Table', 'Chair']), contains('كرسي'));
    expect(BlindSceneBrief.primary(const ['Smile', 'Face']), isEmpty);
    expect(BlindSceneBrief.primary(const []), isEmpty);
    expect(
      BlindSceneBrief.acceptedLabels(const [
        SceneHit('Person', 0.2),
        SceneHit('Car', 0.8),
      ]),
      ['Car'],
    );
  });

  test('التفاصيل تُطلب من الإطار الحالي والنقر المزدوج يُحسب مرة', () {
    expect(
      BlindSceneBrief.details(const [], hadFrame: false),
      BlindSceneBrief.noAnalysisAr,
    );
    final details = BlindSceneBrief.details(
      const ['Woman', 'Smile'],
      hadFrame: true,
    );
    expect(details, contains('امرأة'));
    expect(details, contains('ابتسامة'));
    expect(details, isNot(contains('تفاصيل')));
    final taps = SceneDoubleTap();
    final start = DateTime(2026, 10, 14, 12);
    expect(taps.register(start), isFalse);
    expect(taps.register(start.add(const Duration(milliseconds: 200))), isTrue);
    expect(taps.register(start.add(const Duration(milliseconds: 250))), isFalse);
  });

  test('السحابة لا ترسل بلا مفتاح ولا تعيد إطارات قديمة', () {
    final cloud = BlindCloudSight();
    final blocked = cloud.ask(userAllowsCloud: false, online: true);
    expect(blocked.sent, isFalse);
    final missing = cloud.ask(userAllowsCloud: true, online: true);
    expect(missing.sent, isFalse);
    expect(missing.spokenAr, contains('لم تُرسل صورة'));
    cloud.queuedFrames = 4;
    final back = cloud.onNetworkReturned();
    expect(back.sent, isFalse);
    expect(cloud.queuedFrames, 0);
    expect(back.spokenAr, contains('لم تُرسل صور قديمة'));
  });

  test('العداد يفصل الاستلام ولا يحتسب الإطار مرتين', () {
    final trace = BlindFrameTrace();
    final at = DateTime(2026, 10, 15, 0, 30);
    trace.receive(at);
    trace.receive(at);
    trace.receive(at);
    trace.deliver(1, at);
    trace.deliver(1, at);
    trace.classifierReturned(
      sequence: 1,
      at: at,
      elapsedMs: 40,
      ok: true,
      accepted: 1,
      top: 'Person',
    );
    trace.classifierReturned(
      sequence: 1,
      at: at,
      elapsedMs: 1,
      ok: true,
      accepted: 1,
      top: 'Person',
    );
    trace.reachedSpeech(1, at);
    trace.reachedSpeech(1, at);
    trace.fail(0, at, 'فتح الكاميرا', 'رفض الإذن');
    expect(trace.received, 3);
    expect(trace.delivered, 1);
    expect(trace.classified, 1);
    expect(trace.spoken, 1);
    expect(trace.statusAr(), contains('إطارات مستلمة: 3'));
    expect(trace.statusAr(), contains('أعاد المصنّف نتيجة: 1'));
    expect(trace.notes.join('\n'), contains('رفض الإذن'));
    expect(trace.notes.join('\n'), contains('40ms'));
    expect(trace.notes.join(' '), isNot(contains('jpeg')));
  });

  test('فشل المصنّف والثقة المنخفضة لا تُحسب نتيجة مقبولة', () {
    final trace = BlindFrameTrace();
    final at = DateTime(2026, 10, 15, 0, 31);
    final failed = trace.classifierReturned(
      sequence: 2,
      at: at,
      elapsedMs: 5,
      ok: false,
      failure: 'استثناء أثناء التصنيف',
    );
    expect(failed, contains('فشل'));
    expect(trace.classified, 0);
    final ignored = trace.ignoreLow(2, at, 'Person', 0.2);
    expect(ignored, contains('دون الحد'));
    expect(trace.spoken, 0);
    expect(
      BlindSceneBrief.acceptedLabels(const [SceneHit('Person', 0.2)]),
      isEmpty,
    );
    expect(BlindSceneBrief.primary(const []), isEmpty);
  });

  test('الوصف العربي لا يدّعي حركة ولا مسافة', () {
    expect(BlindSceneBrief.primary(const ['Person']), 'شخص');
    expect(BlindSceneBrief.primary(const ['Car']), 'سيارة');
    expect(BlindSceneBrief.primary(const ['Door']), 'باب');
    expect(BlindSceneBrief.primary(const ['Stairs']), 'درج');
    expect(BlindSceneBrief.primary(const ['Obstacle']), 'عائق');
    final spoken = BlindSceneBrief.primary(const ['Car', 'Person']);
    expect(spoken, isNot(contains('متوقفة')));
    expect(spoken, isNot(contains('يقترب')));
    expect(spoken, isNot(contains('متر')));
    expect(BlindCameraSpeech.cameraDenied('ar'), contains('رفض النظام'));
    expect(BlindCameraSpeech.lensFailed('ar'), contains('تعذّر'));
  });

  test('أوامر الكاميرا تُخطَّط والإطار المشغول لا يُكدّس', () {
    expect(planVoiceTurn('افتح كاميرا المكفوفين').kind, VoiceTurnKind.openBlindCamera);
    expect(planVoiceTurn('أعطني التفاصيل').kind, VoiceTurnKind.details);
    expect(planVoiceTurn('اقرأ النص').kind, VoiceTurnKind.readText);
    expect(planVoiceTurn('أوقف الوصف مؤقتاً').kind, VoiceTurnKind.pauseDescription);
    expect(planVoiceTurn('استأنف الوصف').kind, VoiceTurnKind.resumeDescription);
    expect(planVoiceTurn('بدّل إلى الكاميرا الأمامية').kind, VoiceTurnKind.frontCamera);
    expect(planVoiceTurn('ارجع إلى الكاميرا الخلفية').kind, VoiceTurnKind.backCamera);
    expect(planVoiceTurn('اسأل الذكاء الاصطناعي عن المشهد').kind, VoiceTurnKind.askCloud);
    expect(planVoiceTurn('ماذا يوجد أمامي؟').kind, VoiceTurnKind.scene);
    final scheduler = LiveSightScheduler();
    final now = DateTime(2026, 10, 14, 12);
    expect(scheduler.claim(now), isTrue);
    expect(scheduler.claim(now.add(const Duration(milliseconds: 100))), isFalse);
    scheduler.release();
    scheduler.narrationEnabled = false;
    expect(scheduler.claim(now.add(const Duration(seconds: 5))), isFalse);
  });
}
