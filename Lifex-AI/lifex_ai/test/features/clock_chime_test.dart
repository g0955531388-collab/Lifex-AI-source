import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/clock/clock_chime.dart';
import 'package:lifex_ai/features/clock/speaking_alarm_book.dart';
import 'package:lifex_ai/features/location/device_location_reader.dart';
import 'package:lifex_ai/features/voice/user_ringtone_desk.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<String>> _run(ChimeOrder order,
    {bool toneWorks = true, bool fallback = false}) async {
  final calls = <String>[];
  await runChime(
    order: order,
    audibleFallback: fallback,
    tone: () async {
      calls.add('tone');
      return toneWorks;
    },
    speak: () async {
      calls.add('speech');
      return true;
    },
  );
  return calls;
}

SpeakingAlarm _alarm({
  bool speechCue = true,
  String toneUri = '',
  ChimeOrder? cueOrder,
}) {
  return SpeakingAlarm(
    id: 'a',
    name: 'home',
    hour: 7,
    minute: 30,
    enabled: true,
    latitude: 33.5,
    longitude: 36.3,
    radiusMeters: 200,
    speechCue: speechCue,
    toneUri: toneUri,
    cueOrder: cueOrder,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ترتيب النطق والنغمة', () {
    test('النطق فقط', () async {
      expect(await _run(ChimeOrder.speechOnly), ['speech']);
    });
    test('النغمة فقط بلا نطق', () async {
      expect(await _run(ChimeOrder.toneOnly), ['tone']);
    });
    test('النغمة ثم النطق', () async {
      expect(await _run(ChimeOrder.toneThenSpeech), ['tone', 'speech']);
    });
    test('النطق ثم النغمة', () async {
      expect(await _run(ChimeOrder.speechThenTone), ['speech', 'tone']);
    });
    test('إيقاف الاثنين لا يصدر صوتاً', () async {
      expect(await _run(ChimeOrder.off), isEmpty);
    });
    test('نغمة فاشلة للمنبه تعود إلى النطق', () async {
      expect(
        await _run(ChimeOrder.toneOnly, toneWorks: false, fallback: true),
        ['tone', 'speech'],
      );
      expect(
        await _run(ChimeOrder.toneOnly, toneWorks: false),
        ['tone'],
      );
    });
    test('الإيقاف يمنع بقية الترتيب', () async {
      var stopped = false;
      final calls = <String>[];
      await runChime(
        order: ChimeOrder.toneThenSpeech,
        cancelled: () => stopped,
        tone: () async {
          calls.add('tone');
          stopped = true;
          return true;
        },
        speak: () async {
          calls.add('speech');
          return true;
        },
      );
      expect(calls, ['tone']);
    });
  });

  group('المنبه لا يصمت بإيقاف النطق', () {
    test('منبه قديم بلا ترتيب يبقى ناطقاً', () {
      expect(_alarm().order, ChimeOrder.speechOnly);
    });
    test('منبه قديم بنغمة جهاز وبلا نطق يبقى نغمة', () {
      expect(
        _alarm(speechCue: false, toneUri: 'content://tone').order,
        ChimeOrder.toneOnly,
      );
    });
    test('«إيقاف الاثنين» على منبه يعود نطقاً', () {
      expect(_alarm(cueOrder: ChimeOrder.off).order, ChimeOrder.speechOnly);
    });
    test('نغمة مطلوبة بلا نغمة محفوظة تعود نطقاً', () {
      expect(_alarm(cueOrder: ChimeOrder.toneOnly).order, ChimeOrder.speechOnly);
    });
    test('الترتيب يُحفظ ويُسترجع من JSON', () {
      final alarm = _alarm(
        speechCue: true,
        toneUri: BuiltInTone.calmBell.ref,
        cueOrder: ChimeOrder.speechThenTone,
      );
      final back = SpeakingAlarm.fromJson(alarm.toJson())!;
      expect(back.order, ChimeOrder.speechThenTone);
      expect(back.toneUri, BuiltInTone.calmBell.ref);
    });
  });

  group('مكتبة النغمات', () {
    test('كل نغمة تولّد WAV صالحاً بطول معقول', () {
      for (final tone in BuiltInTone.values) {
        final bytes = ClockToneSynth.wav(tone);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: tone.name);
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE', reason: tone.name);
        final ms = ClockToneSynth.durationOf(tone).inMilliseconds;
        expect(ms, inInclusiveRange(200, 4000), reason: tone.name);
        expect(bytes.length, greaterThan(44 + ms * ClockToneSynth.sampleRate * 2 ~/ 1100));
        expect(BuiltInToneParts.fromRef(tone.ref), tone);
      }
    });
    test('مستوى الصوت يضرب السعة', () {
      int peak(List<int> bytes) {
        var best = 0;
        for (var i = 44; i + 1 < bytes.length; i += 2) {
          var v = bytes[i] | (bytes[i + 1] << 8);
          if (v > 32767) v -= 65536;
          if (v.abs() > best) best = v.abs();
        }
        return best;
      }

      final loud = peak(ClockToneSynth.wav(BuiltInTone.digitalBeep, volume: 1));
      final quiet = peak(ClockToneSynth.wav(BuiltInTone.digitalBeep, volume: 0.2));
      expect(quiet, lessThan(loud ~/ 3));
      expect(quiet, greaterThan(0));
    });
  });

  group('حفظ إعداد الساعة', () {
    test('الافتراضي هو السلوك القائم: النطق فقط', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await ClockChimeSettings.load();
      expect(settings.order, ChimeOrder.speechOnly);
    });
    test('الإعداد يبقى بعد إعادة الفتح', () async {
      SharedPreferences.setMockInitialValues({});
      await const ClockChimeSettings(
        order: ChimeOrder.toneThenSpeech,
        toneRef: 'lifex-tone:classicBell',
        volume: 0.4,
      ).save();
      final back = await ClockChimeSettings.load();
      expect(back.order, ChimeOrder.toneThenSpeech);
      expect(back.toneRef, 'lifex-tone:classicBell');
      expect(back.volume, closeTo(0.4, 1e-9));
    });
  });

  group('مشغّل النغمة', () {
    late Directory dir;
    final calls = <String>[];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('lifex_tone_test');
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(UserRingtoneDesk.channelName),
        (call) async {
          calls.add(call.method);
          return true;
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(UserRingtoneDesk.channelName),
        null,
      );
      await dir.delete(recursive: true);
    });

    test('تشغيل ثم إيقاف ينهي الصوت ولا يتكرر', () async {
      final player = ClockTonePlayer(folder: () async => dir);
      final done = player.play(BuiltInTone.repeatingAlert.ref, volume: 0.5);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.playing, isTrue);
      await player.stop();
      expect(player.playing, isFalse);
      expect(await done, isTrue);
      expect(calls.where((m) => m == 'play').length, 1);
      expect(calls.last, 'stop');
    });

    test('نغمة جديدة توقف السابقة قبل أن تبدأ', () async {
      final player = ClockTonePlayer(folder: () async => dir);
      unawaited(player.play(BuiltInTone.calmBell.ref));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      unawaited(player.play(BuiltInTone.digitalBeep.ref));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(calls, ['play', 'stop', 'play']);
      await player.stop();
    });
  });

  group('منبه بعد إعادة الفتح', () {
    test('منبه محفوظ بنغمة فقط يرن بلا نطق', () async {
      SharedPreferences.setMockInitialValues({});
      await const SpeakingAlarmBook().save([
        _alarm(
          speechCue: false,
          toneUri: BuiltInTone.classicBell.ref,
          cueOrder: ChimeOrder.toneOnly,
        ),
      ]);
      final spoken = <String>[];
      final rung = <String>[];
      await SpeakingAlarmWatch.instance.tick(
        DateTime(2026, 10, 27, 7, 30),
        fix: const DeviceLocationRead(messageAr: ''),
        speak: (text) async => spoken.add(text),
        tone: (ref, volume) async {
          rung.add(ref);
          return true;
        },
      );
      expect(rung, [BuiltInTone.classicBell.ref]);
      expect(spoken, isEmpty);
      expect(SpeakingAlarmWatch.instance.ringing.value, isNull);
    });

    test('المنبه لا يتكرر في الدقيقة نفسها', () async {
      SharedPreferences.setMockInitialValues({});
      await const SpeakingAlarmBook().save([_alarm()]);
      final spoken = <String>[];
      Future<void> once() => SpeakingAlarmWatch.instance.tick(
            DateTime(2026, 10, 28, 7, 30),
            fix: const DeviceLocationRead(messageAr: ''),
            speak: (text) async => spoken.add(text),
            tone: (ref, volume) async => true,
          );
      await once();
      await once();
      expect(spoken.length, 1);
    });
  });
}
