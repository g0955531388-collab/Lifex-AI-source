/// نغمة الساعة مستقلة عن النطق: الترتيب والنغمة ومستوى صوتها.
library lifex_ai.features.clock.clock_chime;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../voice/user_ringtone_desk.dart';

enum ChimeOrder { speechOnly, toneOnly, toneThenSpeech, speechThenTone, off }

extension ChimeOrderParts on ChimeOrder {
  bool get usesSpeech =>
      this == ChimeOrder.speechOnly ||
      this == ChimeOrder.toneThenSpeech ||
      this == ChimeOrder.speechThenTone;

  bool get usesTone =>
      this == ChimeOrder.toneOnly ||
      this == ChimeOrder.toneThenSpeech ||
      this == ChimeOrder.speechThenTone;

  String get label {
    switch (this) {
      case ChimeOrder.speechOnly:
        return lifexUi('النطق فقط', 'Speech only');
      case ChimeOrder.toneOnly:
        return lifexUi('النغمة فقط', 'Tone only');
      case ChimeOrder.toneThenSpeech:
        return lifexUi('النغمة ثم النطق', 'Tone, then speech');
      case ChimeOrder.speechThenTone:
        return lifexUi('النطق ثم النغمة', 'Speech, then tone');
      case ChimeOrder.off:
        return lifexUi('إيقاف الاثنين', 'Both off');
    }
  }

  static ChimeOrder parse(Object? raw, {ChimeOrder fallback = ChimeOrder.speechOnly}) {
    for (final order in ChimeOrder.values) {
      if (order.name == raw) return order;
    }
    return fallback;
  }
}

enum BuiltInTone { calmBell, classicBell, digitalBeep, repeatingAlert, simpleTime }

extension BuiltInToneParts on BuiltInTone {
  static const prefix = 'lifex-tone:';

  String get ref => '$prefix$name';

  String get label {
    switch (this) {
      case BuiltInTone.calmBell:
        return lifexUi('جرس هادئ', 'Calm bell');
      case BuiltInTone.classicBell:
        return lifexUi('جرس تقليدي', 'Classic bell');
      case BuiltInTone.digitalBeep:
        return lifexUi('نغمة رقمية قصيرة', 'Short digital beep');
      case BuiltInTone.repeatingAlert:
        return lifexUi('نغمة متكررة للتنبيه', 'Repeating alert');
      case BuiltInTone.simpleTime:
        return lifexUi('نغمة إعلان الوقت', 'Simple time chime');
    }
  }

  static BuiltInTone? fromRef(String ref) {
    final trimmed = ref.trim();
    if (!trimmed.startsWith(prefix)) return null;
    final key = trimmed.substring(prefix.length);
    for (final tone in BuiltInTone.values) {
      if (tone.name == key) return tone;
    }
    return null;
  }
}

/// يولّد WAV أحادي 16 بت. مستوى الصوت يضرب السعة، فلا يمس صوت النطق.
class ClockToneSynth {
  const ClockToneSynth._();

  static const sampleRate = 22050;

  static Duration durationOf(BuiltInTone tone) {
    var end = 0.0;
    for (final strike in _strikes(tone)) {
      end = math.max(end, strike.start + strike.length);
    }
    return Duration(milliseconds: (end * 1000).round());
  }

  static Uint8List wav(BuiltInTone tone, {double volume = 0.8}) {
    final gain = volume.clamp(0.0, 1.0);
    final strikes = _strikes(tone);
    final seconds = durationOf(tone).inMilliseconds / 1000;
    final count = (seconds * sampleRate).ceil();
    final samples = Float64List(count);
    for (final strike in strikes) {
      final from = (strike.start * sampleRate).round();
      final length = (strike.length * sampleRate).round();
      for (var i = 0; i < length && from + i < count; i++) {
        final t = i / sampleRate;
        final attack = math.min(1.0, t / 0.005);
        final release = math.min(1.0, (strike.length - t) / 0.01);
        final envelope = attack * release * math.exp(-t * strike.decay);
        var value = 0.0;
        for (final partial in strike.partials) {
          value += partial.weight *
              math.sin(2 * math.pi * strike.hz * partial.ratio * t);
        }
        samples[from + i] += value * envelope;
      }
    }
    var peak = 0.0;
    for (final s in samples) {
      peak = math.max(peak, s.abs());
    }
    final scale = peak == 0 ? 0.0 : 0.85 * gain / peak;
    final pcm = ByteData(count * 2);
    for (var i = 0; i < count; i++) {
      final v = (samples[i] * scale * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, v, Endian.little);
    }
    return _wrap(pcm.buffer.asUint8List());
  }

  static Uint8List _wrap(Uint8List pcm) {
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
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  static List<_Strike> _strikes(BuiltInTone tone) {
    const bell = [
      _Partial(1, 1),
      _Partial(2.0, 0.45),
      _Partial(2.76, 0.25),
      _Partial(5.4, 0.1),
    ];
    const pure = [_Partial(1, 1), _Partial(2, 0.15)];
    switch (tone) {
      case BuiltInTone.calmBell:
        return const [_Strike(0, 1.8, 523.25, 2.2, bell)];
      case BuiltInTone.classicBell:
        return const [
          _Strike(0, 1.0, 784, 3.0, bell),
          _Strike(0.9, 1.4, 659.25, 2.6, bell),
        ];
      case BuiltInTone.digitalBeep:
        return const [
          _Strike(0, 0.12, 1000, 0, pure),
          _Strike(0.2, 0.12, 1000, 0, pure),
        ];
      case BuiltInTone.repeatingAlert:
        return [
          for (var group = 0; group < 4; group++) ...[
            _Strike(group * 0.75, 0.15, 880, 0, pure),
            _Strike(group * 0.75 + 0.22, 0.15, 880, 0, pure),
          ],
        ];
      case BuiltInTone.simpleTime:
        return const [
          _Strike(0, 0.5, 659.25, 4.0, pure),
          _Strike(0.35, 0.7, 987.77, 3.5, pure),
        ];
    }
  }
}

class _Partial {
  const _Partial(this.ratio, this.weight);

  final double ratio;
  final double weight;
}

class _Strike {
  const _Strike(this.start, this.length, this.hz, this.decay, this.partials);

  final double start;
  final double length;
  final double hz;
  final double decay;
  final List<_Partial> partials;
}

/// يشغّل نغمة واحدة في كل مرة عبر قناة النغمات القائمة، ويعود بعد انتهائها.
class ClockTonePlayer {
  ClockTonePlayer({
    UserRingtoneDesk desk = const UserRingtoneDesk(),
    Future<Directory> Function()? folder,
  })  : _desk = desk,
        _folder = folder ?? getTemporaryDirectory;

  static final ClockTonePlayer instance = ClockTonePlayer();

  /// نغمة الجهاز قد تكون طويلة؛ تُقطع بعد هذا الحد.
  static const deviceToneCap = Duration(seconds: 6);

  final UserRingtoneDesk _desk;
  final Future<Directory> Function() _folder;
  int _epoch = 0;
  bool _playing = false;

  bool get playing => _playing;

  Future<bool> play(String ref, {double volume = 0.8}) async {
    final trimmed = ref.trim();
    if (trimmed.isEmpty) return false;
    await stop();
    final epoch = ++_epoch;
    final builtIn = BuiltInToneParts.fromRef(trimmed);
    var uri = trimmed;
    var length = deviceToneCap;
    if (builtIn != null) {
      final file = await _file(builtIn, volume);
      if (file == null) return false;
      uri = file.uri.toString();
      length = ClockToneSynth.durationOf(builtIn) +
          const Duration(milliseconds: 150);
    }
    if (epoch != _epoch) return false;
    final played = await _desk.play(uri);
    if (!played) return false;
    _playing = true;
    await Future<void>.delayed(length);
    if (epoch == _epoch) await stop();
    return true;
  }

  Future<void> stop() async {
    _epoch++;
    final was = _playing;
    _playing = false;
    if (was) await _desk.stop();
  }

  Future<File?> _file(BuiltInTone tone, double volume) async {
    try {
      final dir = await _folder();
      final percent = (volume.clamp(0.0, 1.0) * 100).round();
      final file = File('${dir.path}/lifex_tone_${tone.name}_$percent.wav');
      if (!await file.exists()) {
        await file.writeAsBytes(ClockToneSynth.wav(tone, volume: volume),
            flush: true);
      }
      return file;
    } catch (_) {
      return null;
    }
  }
}

class ChimeOutcome {
  const ChimeOutcome({required this.spoke, required this.toned});

  final bool spoke;
  final bool toned;

  bool get audible => spoke || toned;
}

/// يرتب النغمة والنطق. [audibleFallback] للمنبه: إن فشلت النغمة وحدها يُنطق.
Future<ChimeOutcome> runChime({
  required ChimeOrder order,
  required Future<bool> Function() tone,
  required Future<bool> Function() speak,
  bool audibleFallback = false,
  bool Function()? cancelled,
}) async {
  bool stopped() => cancelled?.call() ?? false;
  var spoke = false;
  var toned = false;
  switch (order) {
    case ChimeOrder.off:
      break;
    case ChimeOrder.speechOnly:
      spoke = await speak();
    case ChimeOrder.toneOnly:
      toned = await tone();
      if (!toned && audibleFallback && !stopped()) spoke = await speak();
    case ChimeOrder.toneThenSpeech:
      toned = await tone();
      if (!stopped()) spoke = await speak();
    case ChimeOrder.speechThenTone:
      spoke = await speak();
      if (!stopped()) toned = await tone();
  }
  return ChimeOutcome(spoke: spoke, toned: toned);
}

/// إعداد إعلان الوقت عند لمس الساعة. الافتراضي هو السلوك القائم: النطق فقط.
class ClockChimeSettings {
  const ClockChimeSettings({
    this.order = ChimeOrder.speechOnly,
    this.toneRef = 'lifex-tone:simpleTime',
    this.toneTitle = '',
    this.volume = 0.8,
  });

  static const storageKey = 'lifex_clock_chime_v1';

  final ChimeOrder order;
  final String toneRef;
  final String toneTitle;
  final double volume;

  String get toneLabel {
    final builtIn = BuiltInToneParts.fromRef(toneRef);
    if (builtIn != null) return builtIn.label;
    return toneTitle.trim().isEmpty
        ? lifexUi('نغمة من الجهاز', 'Device ringtone')
        : toneTitle;
  }

  ClockChimeSettings copyWith({
    ChimeOrder? order,
    String? toneRef,
    String? toneTitle,
    double? volume,
  }) {
    return ClockChimeSettings(
      order: order ?? this.order,
      toneRef: toneRef ?? this.toneRef,
      toneTitle: toneTitle ?? this.toneTitle,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() => {
        'order': order.name,
        'toneRef': toneRef,
        'toneTitle': toneTitle,
        'volume': volume,
      };

  static ClockChimeSettings fromJson(Map<String, dynamic> json) {
    final ref = json['toneRef']?.toString().trim() ?? '';
    final volume = json['volume'];
    return ClockChimeSettings(
      order: ChimeOrderParts.parse(json['order']),
      toneRef: ref.isEmpty ? const ClockChimeSettings().toneRef : ref,
      toneTitle: json['toneTitle']?.toString() ?? '',
      volume: volume is num ? volume.toDouble().clamp(0.1, 1.0) : 0.8,
    );
  }

  static Future<ClockChimeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const ClockChimeSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ClockChimeSettings();
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const ClockChimeSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }
}
