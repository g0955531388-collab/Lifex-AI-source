import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/assistive_vision_engine.dart';
import 'package:lifex_ai/features/accessibility/blind_camera_binding.dart';
import 'package:lifex_ai/features/accessibility/blind_camera_speech.dart';
import 'package:lifex_ai/features/accessibility/text_and_currency_reader.dart';

void main() {
  test('التصنيف الفارغ والنص الفارغ يبقيان فارغين', () {
    expect(BlindCameraSpeech.sceneFromLabels(['  ']), BlindCameraSpeech.noSceneAr);
    expect(BlindCameraSpeech.textFromRaw('   '), BlindCameraSpeech.noTextAr);
    expect(
      BlindCameraSpeech.liveFrom(labels: const [], text: ''),
      BlindCameraSpeech.noSceneAr,
    );
    expect(BlindCameraSpeech.hasReading(labels: const [], text: ' '), isFalse);
  });

  test('التصنيف المعروف يُشرح بالعربية والاسم غير المعروف يبقى كما عاد', () {
    final scene = BlindCameraSpeech.sceneFromLabels(['Chair', ' chair ', 'Door']);
    expect(BlindCameraSpeech.sceneFromLabels(['Furniture', 'Television']),
        contains('أثاث'));
    expect(BlindCameraSpeech.sceneFromLabels(['Furniture', 'Television']),
        contains('تلفاز'));
    expect(scene, contains('كرسي'));
    expect(scene, contains('باب'));
    expect(scene, isNot(contains('ما ظهر')));
    expect('كرسي'.allMatches(scene).length, 1);
    expect(BlindCameraSpeech.sceneFromLabels(['Zeppelin']), contains('Zeppelin'));
    final english = BlindCameraSpeech.sceneFromLabels(
      ['Chair', 'Door'],
      languageCode: 'en',
    );
    expect(english, 'Chair, Door');
    final live = BlindCameraSpeech.liveFrom(labels: ['Door'], text: 'خروج');
    expect(live, contains('باب'));
    expect(live, contains('خروج'));
    expect(live, contains('ليس تشخيصاً'));
    final sceneOnly = BlindCameraSpeech.liveFrom(
      labels: ['Chair'],
      text: 'خروج',
      includeText: false,
    );
    expect(sceneOnly, isNot(contains('خروج')));
    expect(
      BlindCameraSpeech.liveFrom(
        labels: const [],
        text: '',
        includeScene: false,
        includeText: true,
      ),
      BlindCameraSpeech.noTextAr,
    );
    expect(
      BlindCameraSpeech.forDeviceLanguage('In the frame: Chair.', 'fr'),
      contains('fr'),
    );
  });

  test('البث الحي بلا مسار لا يخترع مشهداً', () async {
    final engine = AssistiveVisionEngine.instance;
    BlindCameraBinding.register(
      engine,
      labelsFromPath: (_) async => ['Chair'],
      textFromPath: (_) async => 'باب',
    );
    final missing = await engine.process(
      imageOrFrameInput: const [1],
      type: AssistiveFeatureType.sceneDescription,
      context: const {'live': true},
    );
    expect(missing.success, isFalse);
    expect(missing.spokenMessageAr, BlindCameraSpeech.noPathAr);

    final live = await engine.process(
      imageOrFrameInput: const [1],
      type: AssistiveFeatureType.sceneDescription,
      context: const {'live': true, 'imagePath': 'frame.jpg'},
    );
    expect(live.success, isTrue);
    expect(live.spokenMessageAr, contains('كرسي'));
    expect(live.spokenMessageAr, contains('باب'));

    final english = await engine.process(
      imageOrFrameInput: const [1],
      type: AssistiveFeatureType.sceneDescription,
      context: const {
        'live': true,
        'imagePath': 'frame.jpg',
        'languageCode': 'en',
        'includeText': false,
      },
    );
    expect(english.spokenMessageAr, contains('Chair'));
    expect(english.spokenMessageAr, isNot(contains('باب')));

    final money = await engine.process(
      imageOrFrameInput: const [1],
      type: AssistiveFeatureType.textAndCurrencyReading,
      context: const {
        'imagePath': 'note.jpg',
        'targetType': ReadingTargetType.currencyNote,
      },
    );
    expect(money.success, isFalse);
    expect(money.spokenMessageAr, BlindCameraSpeech.noCurrencyAr);
  });

  test('تحية المساعد لا تُقال قبل البث والتحليل والاستماع والنطق', () {
    expect(
      VisualAssistOpening.welcome(
        languageCode: 'ar',
        cameraStreaming: true,
        analysisReady: true,
        hearingReady: true,
        speakingReady: true,
      ),
      VisualAssistOpening.welcomeAr,
    );
    expect(
      VisualAssistOpening.welcome(
        languageCode: 'en',
        cameraStreaming: true,
        analysisReady: true,
        hearingReady: true,
        speakingReady: true,
      ),
      VisualAssistOpening.welcomeEn,
    );
    expect(
      VisualAssistOpening.welcome(
        languageCode: 'ar',
        cameraStreaming: true,
        analysisReady: false,
        hearingReady: true,
        speakingReady: true,
      ),
      isNull,
    );
    expect(
      VisualAssistOpening.welcome(
        languageCode: 'en',
        cameraStreaming: true,
        analysisReady: true,
        hearingReady: false,
        speakingReady: true,
      ),
      isNull,
    );
    expect(
      VisualAssistOpening.welcome(
        languageCode: 'fr',
        cameraStreaming: false,
        analysisReady: true,
        hearingReady: true,
        speakingReady: true,
      ),
      isNull,
    );
    expect(VisualAssistOpening.cloudDown('en'), contains('Gemini'));
    expect(VisualAssistOpening.cloudDown('ar'), contains('جيميني'));
    expect(
      BlindCameraSpeech.lensOpen('ar', live: true),
      'تم فتح كاميرا المساعد البصري',
    );
  });
}
