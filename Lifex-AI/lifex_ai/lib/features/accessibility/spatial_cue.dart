/// إشارة اتجاه صوتية قصيرة قبل جملة الصناديق: يسار أو وسط أو يمين فقط.
/// الجملة المنطوقة تبقى الأساس؛ الإشارة إضافة لمن يسمع بأذنين. بلا مسافة.
library lifex_ai.features.accessibility.spatial_cue;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice/user_ringtone_desk.dart';
import 'box_geometry.dart';
import 'local_object_detector.dart';

/// كسب القناتين لكل موضع. الوسط متساوٍ، والجانب يبقي أثراً خفيفاً في الأذن الأخرى.
({double left, double right}) spatialGains(BoxPlace place) {
  switch (place) {
    case BoxPlace.left:
      return (left: 1.0, right: 0.15);
    case BoxPlace.center:
      return (left: 0.71, right: 0.71);
    case BoxPlace.right:
      return (left: 0.15, right: 1.0);
  }
}

/// موضع أول شيء في الجملة، لأن الجملة تبدأ به.
BoxPlace? spatialCuePlace(List<DetectedObject> objects) {
  for (final object in objects) {
    if (object.hasBox) return object.place;
  }
  return null;
}

class SpatialCueSynth {
  const SpatialCueSynth._();

  static const sampleRate = 22050;
  static const hz = 880.0;
  static const blipSeconds = 0.07;
  static const gapSeconds = 0.05;

  static Duration get duration => Duration(
        milliseconds: ((blipSeconds * 2 + gapSeconds) * 1000).round(),
      );

  /// WAV ستيريو 16 بت: نقرتان قصيرتان بالكسب الجانبي للموضع.
  static Uint8List wav(BoxPlace place, {double volume = 0.8}) {
    final gain = volume.clamp(0.0, 1.0);
    final pan = spatialGains(place);
    final blip = (blipSeconds * sampleRate).round();
    final gap = (gapSeconds * sampleRate).round();
    final frames = blip * 2 + gap;
    final pcm = ByteData(frames * 4);
    for (var i = 0; i < frames; i++) {
      final inSecond = i >= blip + gap;
      final inFirst = i < blip;
      var sample = 0.0;
      if (inFirst || inSecond) {
        final local = inFirst ? i : i - blip - gap;
        final t = local / sampleRate;
        final attack = math.min(1.0, t / 0.004);
        final release = math.min(1.0, (blipSeconds - t) / 0.01);
        sample = math.sin(2 * math.pi * hz * t) * attack * release * 0.85 * gain;
      }
      int pcm16(double value) => (value * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 4, pcm16(sample * pan.left), Endian.little);
      pcm.setInt16(i * 4 + 2, pcm16(sample * pan.right), Endian.little);
    }
    return _wrapStereo(pcm.buffer.asUint8List());
  }

  static Uint8List _wrapStereo(Uint8List pcm) {
    final header = ByteData(44);
    void ascii(int at, String text) {
      for (var i = 0; i < text.length; i++) {
        header.setUint8(at + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 2, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 4, Endian.little);
    header.setUint16(32, 4, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }
}

/// مفعّلة افتراضياً، ويُطفئها المستخدم من خيارات المساعد البصري.
class SpatialCueSettings {
  const SpatialCueSettings._();

  static const storageKey = 'lifex_spatial_cue_v1';

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(storageKey) ?? true;
  }

  static Future<void> save(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, enabled);
  }
}

/// إشارة واحدة في كل مرة عبر قناة النغمات القائمة، ثم إيقاف صريح.
class SpatialCuePlayer {
  SpatialCuePlayer({
    UserRingtoneDesk desk = const UserRingtoneDesk(),
    Future<Directory> Function()? folder,
  })  : _desk = desk,
        _folder = folder ?? getTemporaryDirectory;

  static final SpatialCuePlayer instance = SpatialCuePlayer();

  final UserRingtoneDesk _desk;
  final Future<Directory> Function() _folder;
  int _epoch = 0;

  Future<bool> play(BoxPlace place) async {
    final epoch = ++_epoch;
    final file = await _file(place);
    if (file == null || epoch != _epoch) return false;
    final played = await _desk.play(file.uri.toString());
    if (!played) return false;
    await Future<void>.delayed(
      SpatialCueSynth.duration + const Duration(milliseconds: 60),
    );
    if (epoch == _epoch) await _desk.stop();
    return true;
  }

  Future<void> stop() async {
    _epoch++;
    await _desk.stop();
  }

  Future<File?> _file(BoxPlace place) async {
    try {
      final dir = await _folder();
      final file = File('${dir.path}/lifex_spatial_${place.name}.wav');
      if (!await file.exists()) {
        await file.writeAsBytes(SpatialCueSynth.wav(place), flush: true);
      }
      return file;
    } catch (_) {
      return null;
    }
  }
}
