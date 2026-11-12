import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/permission_transparency.dart';
import 'package:lifex_ai/features/accessibility/assistive_vision_engine.dart';
import 'package:lifex_ai/features/accessibility/live_sight_conductor.dart';
import 'package:lifex_ai/features/voice/assistant_permission_desk.dart';
import 'package:lifex_ai/features/voice/assistant_session.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/text_to_speech_manager.dart';
import 'package:lifex_ai/features/voice/voice_action_router.dart';
import 'package:lifex_ai/features/voice/voice_engine.dart';
import 'package:lifex_ai/features/voice/voice_locale_policy.dart';
import 'package:lifex_ai/widgets/accessible_widgets.dart';

void main() {
  test('إذن الميكروفون لا يُطلب ثانية ما دام ممنوحاً', () async {
    var reads = 0;
    var requests = 0;
    final allowed = await const AssistantPermissionDesk().ensure(
      read: () async {
        reads++;
        return OsPermissionKind.granted;
      },
      request: () async {
        requests++;
        return OsPermissionKind.granted;
      },
    );
    expect(allowed, isTrue);
    expect(reads, 1);
    expect(requests, 0);
  });

  test('الرفض الأول يطلب مرة، والسحب الدائم لا يعيد الطلب', () async {
    var requests = 0;
    final first = await const AssistantPermissionDesk().ensure(
      read: () async => OsPermissionKind.denied,
      request: () async {
        requests++;
        return OsPermissionKind.denied;
      },
    );
    expect(first, isFalse);
    expect(requests, 1);
    expect(AssistantPermissionDesk.lastExplanationAr, contains('لم يُمنح'));

    requests = 0;
    final revoked = await const AssistantPermissionDesk().ensure(
      read: () async => OsPermissionKind.blocked,
      request: () async {
        requests++;
        return OsPermissionKind.granted;
      },
    );
    expect(revoked, isFalse);
    expect(requests, 0);
    expect(AssistantPermissionDesk.lastExplanationAr, contains('إعدادات'));
  });

  test('موافقة الكاميرا داخل التطبيق لا تُعاد بعد تسجيلها', () {
    final manager = PermissionTransparencyManager.instance;
    manager.decide(
      permission: LifexSensitivePermission.camera,
      granted: true,
    );
    expect(manager.isGranted(LifexSensitivePermission.camera), isTrue);
    manager.restore({'camera': true, 'microphone': false});
    expect(manager.isGranted(LifexSensitivePermission.camera), isTrue);
    expect(manager.isGranted(LifexSensitivePermission.microphone), isFalse);
  });

  test('افتح الكاميرا يفتح المساعد البصري بلا ملف صحي', () {
    final parsed = CommandParser().parse('افتح الكاميرا');
    expect(parsed.intent, VoiceCommandIntent.openLiveSight);
    final route = const VoiceActionRouter().route(parsed.intent);
    expect(route.destination, AssistantDestination.liveSight);
    expect(route.needsHealthProfile, isFalse);
    expect(
      const VoiceActionRouter()
          .route(CommandParser().parse('افتح المساعد البصري').intent)
          .destination,
      AssistantDestination.liveSight,
    );
    expect(
      const VoiceActionRouter()
          .route(CommandParser().parse('اقرأ هذا النص').intent)
          .destination,
      AssistantDestination.liveSightText,
    );
  });

  test('لغة الاستماع تتبع اختيار المستخدم ثم المتاح على الجهاز', () {
    const policy = VoiceLocalePolicy();
    expect(policy.listenCode(appLanguage: 'ar'), 'ar');
    expect(
      policy.matchAvailable(preferred: 'ar', available: ['en_US', 'ar_SA']),
      'ar_SA',
    );
    expect(
      policy.matchAvailable(preferred: 'fr', available: ['en_US']),
      'en_US',
    );
  });

  test('تحليل المشهد لا يتداخل، والوصف المتطابق لا يُعاد', () {
    final scheduler = LiveSightScheduler();
    final start = DateTime(2026, 1, 1, 12);
    expect(scheduler.claim(start), isTrue);
    expect(
        scheduler.claim(start.add(const Duration(milliseconds: 200))), isFalse);
    scheduler.release();
    expect(scheduler.claim(start.add(const Duration(seconds: 1))), isFalse);
    expect(scheduler.claim(start.add(const Duration(seconds: 2))), isTrue);

    final conductor = LiveSightConductor();
    const vision = AssistiveVisionResult(
      success: true,
      spokenMessageAr: 'أرى باباً أمامك، وكرسياً على اليمين.',
    );
    final first = conductor.pulse(
      cameraReady: true,
      userConsentedOnThisScreen: true,
      frameBytes: const [1],
      vision: vision,
    );
    final repeat = conductor.pulse(
      cameraReady: true,
      userConsentedOnThisScreen: true,
      frameBytes: const [1],
      vision: vision,
    );
    expect(first.speakNow, isTrue);
    expect(repeat.speakNow, isFalse);
    scheduler.narrationEnabled = false;
    scheduler.release();
    expect(scheduler.claim(start.add(const Duration(seconds: 5))), isFalse);
    scheduler.narrationEnabled = true;
    expect(scheduler.claim(start.add(const Duration(seconds: 5))), isTrue);
  });

  test('النطق الجديد يوقف المقطع السابق قبل أن يبدأ', () async {
    final fake = _FakeSpeech();
    TextToSpeechManager(provider: fake)
        .registerWithVoiceEngine(VoiceEngine.instance);
    final result = await VoiceEngine.instance.speak('أرى كرسياً');
    expect(result.success, isTrue);
    expect(fake.calls, ['stop', 'speak']);
  });

  test('عبارة الاستعداد لا تُكرر ولا تُعلن قبل نجاح النطق', () async {
    final session = AssistantSession.instance;
    session.announced = false;
    session.problemAr = null;
    final engine = VoiceEngine.instance;
    engine.bindSpeakImplementation((text) async {
      return const VoiceOperationResult.failure('النطق غير جاهز.');
    });
    await session.announceReady(engine);
    expect(session.announced, isFalse);
    expect(session.problemAr, contains('النطق'));
    engine.bindSpeakImplementation((text) async {
      return VoiceOperationResult.success(textResult: text);
    });
    await session.announceReady(engine);
    expect(session.announced, isTrue);
    await session.announceReady(engine);
    expect(session.announced, isTrue);
  });

  testWidgets('زر الإجراء يحمل تسمية يقرأها قارئ الشاشة', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccessibleActionButton(
          icon: Icons.videocam_outlined,
          label: 'المساعد البصري',
          semanticHint: 'يفتح البث الحي',
          onTap: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('المساعد البصري'), findsOneWidget);
    expect(BlindNavigationCopy.profileArrival, contains('العمر'));
  });
}

class _FakeSpeech implements TextToSpeechProvider {
  final calls = <String>[];

  @override
  String? get lastBlockAr => null;

  @override
  Future<bool> get isLanguageSupported async => true;

  @override
  Future<bool> speak(String text, SpeechSettings settings) async {
    calls.add('speak');
    return true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}
