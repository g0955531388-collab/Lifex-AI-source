import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/clock/clock_chime.dart';
import 'package:lifex_ai/features/clock/clock_voice.dart';
import 'package:lifex_ai/features/clock/speaking_alarm_book.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/voice/user_ringtone_desk.dart';
import 'package:lifex_ai/features/voice/voice_action_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final parser = CommandParser();

  VoiceCommandIntent intentOf(String text) => parser.parse(text).intent;

  group('أوامر الكاميرا بصيغ طبيعية', () {
    for (final phrase in [
      'افتح الكاميرا',
      'بدي افتح الكاميرا',
      'شغّل كاميرا المكفوفين',
      'افتح كاميرا المكفوفين لو سمحت',
      'ليفكس افتح الكاميرا',
      'open the camera',
    ]) {
      test(phrase, () {
        expect(intentOf(phrase), VoiceCommandIntent.openLiveSight);
        final route = const VoiceActionRouter().route(intentOf(phrase));
        expect(route.destination, AssistantDestination.liveSight);
        expect(route.needsHealthProfile, isFalse);
      });
    }
  });

  group('أوامر الساعة والمنبه', () {
    for (final phrase in [
      'كم الساعة',
      'كم الساعة الآن؟',
      'قديش الساعة',
      'شو الساعة هلق',
      'what time is it',
    ]) {
      test('الوقت: $phrase', () {
        expect(intentOf(phrase), VoiceCommandIntent.tellTime);
      });
    }
    for (final phrase in [
      'افتح المنبه',
      'اضبط منبه',
      'المنبهات',
      'set an alarm',
    ]) {
      test('المنبهات: $phrase', () {
        expect(intentOf(phrase), VoiceCommandIntent.openClockAlarms);
      });
    }
    for (final phrase in [
      'أوقف المنبه',
      'اوقف التنبيه',
      'أسكت المنبه',
      'stop the alarm',
    ]) {
      test('الإيقاف: $phrase', () {
        expect(intentOf(phrase), VoiceCommandIntent.stopClockAlarm);
      });
    }
    test('إيقاف المنبه لا يُفهم إيقافاً للكرسي', () {
      expect(intentOf('stop alarm'), VoiceCommandIntent.stopClockAlarm);
      expect(intentOf('توقف'), VoiceCommandIntent.wheelchairStop);
    });
  });

  group('أوامر البحث', () {
    test('ابحث عن طبيب أسنان يبقى بحثاً', () {
      final intent = intentOf('ابحث عن طبيب أسنان');
      expect(intent, isNot(VoiceCommandIntent.tellTime));
      expect(intent, isNot(VoiceCommandIntent.openClockAlarms));
      expect(intent, isNot(VoiceCommandIntent.unknown));
    });
  });

  group('ردود الساعة', () {
    test('الوقت من لحظة الجهاز بلغتين', () {
      final reply = const ClockVoice().timeReply(DateTime(2026, 10, 28, 7, 5));
      expect(reply.ar, startsWith('الساعة السابعة و 5 دقائق صباحاً.'));
      expect(reply.ar, contains('الأربعاء'));
      expect(reply.en, "It's 5 minutes past seven in the morning.");
      expect(reply.of('en-US'), reply.en);
    });

    test('إيقاف بلا منبه يرن لا يدّعي الإيقاف', () async {
      SpeakingAlarmWatch.instance.ringing.value = null;
      final reply = await const ClockVoice().stopAlarm();
      expect(reply.ar, 'لا منبه يرن الآن.');
    });

    test('إيقاف منبه يرن يُتحقق منه قبل إعلانه', () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(UserRingtoneDesk.channelName),
        (call) async {
          calls.add(call.method);
          return true;
        },
      );
      SpeakingAlarmWatch.instance.ringing.value = 'البيت';
      final reply = await const ClockVoice().stopAlarm();
      expect(reply.ar, 'أوقفت المنبه.');
      expect(SpeakingAlarmWatch.instance.ringing.value, isNull);
      expect(ClockTonePlayer.instance.playing, isFalse);
      messenger.setMockMethodCallHandler(
        const MethodChannel(UserRingtoneDesk.channelName),
        null,
      );
    });
  });
}
