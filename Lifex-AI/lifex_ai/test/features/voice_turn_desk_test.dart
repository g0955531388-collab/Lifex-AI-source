import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_camera_speech.dart';
import 'package:lifex_ai/features/voice/assistant_session.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/voice_action_router.dart';
import 'package:lifex_ai/features/voice/voice_turn_desk.dart';

void main() {
  test('الأوامر الستة تُخطَّط من النص إلى الأثر قبل فتح الشاشة', () {
    expect(planVoiceTurn('ماذا يوجد أمامي؟').kind, VoiceTurnKind.scene);
    expect(planVoiceTurn('ماذا يوجد أمامي؟').messageAr, contains('لن أخترع'));
    expect(planVoiceTurn('أسرع القراءة').kind, VoiceTurnKind.faster);
    expect(planVoiceTurn('أبطئ القراءة').kind, VoiceTurnKind.slower);
    expect(planVoiceTurn('اقرأ الباركود').kind, VoiceTurnKind.barcode);
    expect(planVoiceTurn('اقرأ الباركود').messageAr, contains('ليس تفسيراً لدواء'));
    expect(planVoiceTurn('حدّث ذكاء الكاميرا الآن').kind, VoiceTurnKind.updateModel);
    expect(planVoiceTurn('أوقف التحديث التلقائي').kind, VoiceTurnKind.disableAuto);
    expect(planVoiceTurn('جملة بلا معنى').kind, VoiceTurnKind.pass);
    expect(planVoiceTurn('ماذا يوجد امامي').kind, VoiceTurnKind.scene);
    expect(planVoiceTurn('اعطني التفاصيل').kind, VoiceTurnKind.details);
    expect(planVoiceTurn('اوقف الوصف').kind, VoiceTurnKind.pauseDescription);
    expect(planVoiceTurn('اوافق على الارسال السحابي').kind, VoiceTurnKind.grantCloud);
    expect(planVoiceTurn('وين جوالي').kind, VoiceTurnKind.findPhone);
    expect(planVoiceTurn('عدسة جوجل').kind, VoiceTurnKind.openLens);
    expect(planVoiceTurn('google lens').kind, VoiceTurnKind.openLens);
    final parser = CommandParser();
    expect(parser.parse('افتح الكاميرا').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('اقرا النص').intent, VoiceCommandIntent.readVisibleText);
    expect(parser.parse('لا استطيع التنفس').intent, VoiceCommandIntent.callEmergency);
    expect(
      parser.parse('اريد التبرع لمرضي السرطان').intent,
      VoiceCommandIntent.donateSearchCancer,
    );
  });

  test('سرعة القراءة تتغير عند تنفيذ أثر الأبطأ والأسرع', () {
    final session = AssistantSession.instance;
    final before = session.speechRate;
    session.slowSpeech();
    expect(session.speechRate, lessThan(before));
    final slowed = session.speechRate;
    session.raiseSpeech();
    expect(session.speechRate, greaterThan(slowed));
    session.speechRate = before;
  });

  test('وصف المشهد يأتي من تسميات الإطار والفراغ لا يُختلق', () {
    final spoken = BlindCameraSpeech.liveFrom(
      labels: const ['Bottle'],
      text: '',
      includeScene: true,
      includeText: false,
    );
    expect(spoken, 'قارورة');
    final empty = BlindCameraSpeech.sceneFromLabels(const []);
    expect(empty, 'لم يظهر تصنيف واضح في الإطار. لن أخترع مشهداً.');
  });

  test('الأمر غير المفهوم يبقى unknown والمساعد البصري يصف الإطار', () {
    final parser = CommandParser();
    expect(parser.parse('طرطرطر').intent, VoiceCommandIntent.unknown);
    final route = const VoiceActionRouter().route(VoiceCommandIntent.openLiveSight);
    expect(route.destination, AssistantDestination.liveSight);
    expect(route.spokenAr, contains('لن أخترع'));
  });
}
