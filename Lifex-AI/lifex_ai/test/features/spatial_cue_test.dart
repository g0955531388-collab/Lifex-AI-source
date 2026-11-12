import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/box_geometry.dart';
import 'package:lifex_ai/features/accessibility/local_object_detector.dart';
import 'package:lifex_ai/features/accessibility/spatial_cue.dart';
import 'package:lifex_ai/features/voice/user_ringtone_desk.dart';
import 'package:shared_preferences/shared_preferences.dart';

({int left, int right}) peaks(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  var left = 0;
  var right = 0;
  for (var i = 44; i + 3 < wav.length; i += 4) {
    left = left > data.getInt16(i, Endian.little).abs()
        ? left
        : data.getInt16(i, Endian.little).abs();
    right = right > data.getInt16(i + 2, Endian.little).abs()
        ? right
        : data.getInt16(i + 2, Endian.little).abs();
  }
  return (left: left, right: right);
}

DetectedObject object(String label, BoxPlace place) => DetectedObject(
      label: label,
      confidence: 0.8,
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      place: place,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الإشارة ستيريو والاتجاه من الكسب فقط', () {
    test('رأس WAV ستيريو 16 بت', () {
      final wav = SpatialCueSynth.wav(BoxPlace.left);
      final head = ByteData.sublistView(wav, 0, 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(head.getUint16(22, Endian.little), 2);
      expect(head.getUint16(34, Endian.little), 16);
      expect(SpatialCueSynth.duration.inMilliseconds, lessThan(300));
    });

    test('اليسار في الأذن اليسرى واليمين في اليمنى والوسط متساوٍ', () {
      final left = peaks(SpatialCueSynth.wav(BoxPlace.left));
      final right = peaks(SpatialCueSynth.wav(BoxPlace.right));
      final center = peaks(SpatialCueSynth.wav(BoxPlace.center));
      expect(left.left, greaterThan(left.right * 4));
      expect(right.right, greaterThan(right.left * 4));
      expect((center.left - center.right).abs(), lessThanOrEqualTo(1));
      expect(left.right, greaterThan(0), reason: 'أثر خفيف في الأذن الأخرى');
    });

    test('الموضع من أول شيء في الجملة، وبلا صندوق لا إشارة', () {
      expect(
        spatialCuePlace([
          object('chair', BoxPlace.right),
          object('cup', BoxPlace.left),
        ]),
        BoxPlace.right,
      );
      expect(spatialCuePlace(const []), isNull);
    });
  });

  group('الإعداد', () {
    test('مفعّلة افتراضياً وتُحفظ عند الإطفاء', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SpatialCueSettings.load(), isTrue);
      await SpatialCueSettings.save(false);
      expect(await SpatialCueSettings.load(), isFalse);
    });
  });

  group('المشغّل', () {
    late Directory dir;
    final calls = <String>[];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('lifex_spatial_test');
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

    test('يشغّل مرة ثم يوقف صراحة، وبلا تكرار', () async {
      final player = SpatialCuePlayer(folder: () async => dir);
      expect(await player.play(BoxPlace.left), isTrue);
      expect(calls, ['play', 'stop']);
      expect(File('${dir.path}/lifex_spatial_left.wav').existsSync(), isTrue);
    });
  });
}
