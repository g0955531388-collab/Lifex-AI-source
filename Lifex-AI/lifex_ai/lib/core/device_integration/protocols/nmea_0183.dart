/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: nmea_0183.dart
/// NMEA 0183 (GGA/RMC) من أجهزة GPS/GNSS عبر تسلسلي أو TCP.
/// بلا تثبيت موقع صالح من الجهاز لا تخرج إحداثيات. لا إحداثيات مختلقة.
/// =============================================================
library lifex_ai.core.device_integration.protocols.nmea_0183;

import 'byte_stream_decoder.dart';

class NmeaSentence {
  const NmeaSentence({
    required this.talker,
    required this.type,
    required this.fields,
  });

  /// GP, GN, GL, GA, GB...
  final String talker;

  /// GGA, RMC...
  final String type;
  final List<String> fields;
}

class GnssFix {
  const GnssFix({
    required this.source,
    required this.valid,
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.satellites,
    this.hdop,
    this.fixQuality,
    this.speedKnots,
    this.courseDeg,
    this.utc,
    this.utcTimeOfDay,
  });

  final String source;
  final bool valid;
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
  final int? satellites;
  final double? hdop;
  final int? fixQuality;
  final double? speedKnots;
  final double? courseDeg;
  final DateTime? utc;

  /// hhmmss.ss كما أرسلها الجهاز عند غياب التاريخ (GGA).
  final String? utcTimeOfDay;

  Map<String, Object> toValues() => {
        'source': source,
        'valid': valid,
        if (latitude != null) 'lat': latitude!,
        if (longitude != null) 'lon': longitude!,
        if (altitudeM != null) 'altM': altitudeM!,
        if (satellites != null) 'satellites': satellites!,
        if (hdop != null) 'hdop': hdop!,
        if (fixQuality != null) 'fixQuality': fixQuality!,
        if (speedKnots != null) 'speedKnots': speedKnots!,
        if (courseDeg != null) 'courseDeg': courseDeg!,
        if (utc != null) 'utc': utc!.toIso8601String(),
        if (utcTimeOfDay != null) 'utcTime': utcTimeOfDay!,
      };
}

class NmeaDecoder implements ByteStreamDecoder<NmeaSentence> {
  /// الحد في المعيار 82 حرفاً للجملة.
  static const maxSentenceLength = 82;

  final _line = StringBuffer();
  int _rejected = 0;

  @override
  String get protocolName => 'nmea0183';

  @override
  int get rejected => _rejected;

  @override
  void reset() => _line.clear();

  static int checksumOf(String body) {
    var sum = 0;
    for (final unit in body.codeUnits) {
      sum ^= unit;
    }
    return sum;
  }

  @override
  List<NmeaSentence> feed(List<int> bytes) {
    final out = <NmeaSentence>[];
    for (final b in bytes) {
      if (b == 0x0A) {
        final sentence = parseLine(_line.toString().trim());
        if (sentence != null) out.add(sentence);
        _line.clear();
      } else if (b != 0x0D) {
        if (_line.length > maxSentenceLength + 2) {
          _rejected++;
          _line.clear();
        }
        _line.writeCharCode(b & 0x7F);
      }
    }
    return out;
  }

  /// جملة كاملة مع مجموع التحقق الإلزامي، وإلا null.
  NmeaSentence? parseLine(String line) {
    if (line.isEmpty) return null;
    if (!line.startsWith(r'$') || line.length > maxSentenceLength) {
      _rejected++;
      return null;
    }
    final star = line.lastIndexOf('*');
    if (star < 0 || star + 3 != line.length) {
      _rejected++;
      return null;
    }
    final body = line.substring(1, star);
    final declared = int.tryParse(line.substring(star + 1), radix: 16);
    if (declared == null || declared != checksumOf(body)) {
      _rejected++;
      return null;
    }
    final parts = body.split(',');
    final address = parts.first;
    if (address.length < 5) {
      _rejected++;
      return null;
    }
    return NmeaSentence(
      talker: address.substring(0, address.length - 3),
      type: address.substring(address.length - 3),
      fields: parts.sublist(1),
    );
  }

  static double? _coordinate(String value, String hemisphere, int degreeDigits) {
    if (value.length < degreeDigits + 2) return null;
    final degrees = int.tryParse(value.substring(0, degreeDigits));
    final minutes = double.tryParse(value.substring(degreeDigits));
    if (degrees == null || minutes == null || minutes >= 60) return null;
    final result = degrees + minutes / 60;
    switch (hemisphere) {
      case 'N':
      case 'E':
        return result;
      case 'S':
      case 'W':
        return -result;
    }
    return null;
  }

  static String _field(List<String> f, int i) => i < f.length ? f[i] : '';

  /// GGA أو RMC إلى تثبيت موقع. غير ذلك: null.
  static GnssFix? toFix(NmeaSentence s) {
    final f = s.fields;
    switch (s.type) {
      case 'GGA':
        final quality = int.tryParse(_field(f, 5)) ?? 0;
        final lat = _coordinate(_field(f, 1), _field(f, 2), 2);
        final lon = _coordinate(_field(f, 3), _field(f, 4), 3);
        final valid = quality > 0 && lat != null && lon != null;
        return GnssFix(
          source: 'GGA',
          valid: valid,
          latitude: valid ? lat : null,
          longitude: valid ? lon : null,
          fixQuality: quality,
          satellites: int.tryParse(_field(f, 6)),
          hdop: double.tryParse(_field(f, 7)),
          altitudeM: valid && _field(f, 9) == 'M'
              ? double.tryParse(_field(f, 8))
              : null,
          utcTimeOfDay: _field(f, 0).isEmpty ? null : _field(f, 0),
        );
      case 'RMC':
        final lat = _coordinate(_field(f, 2), _field(f, 3), 2);
        final lon = _coordinate(_field(f, 4), _field(f, 5), 3);
        final valid = _field(f, 1) == 'A' && lat != null && lon != null;
        return GnssFix(
          source: 'RMC',
          valid: valid,
          latitude: valid ? lat : null,
          longitude: valid ? lon : null,
          speedKnots: valid ? double.tryParse(_field(f, 6)) : null,
          courseDeg: valid ? double.tryParse(_field(f, 7)) : null,
          utc: _rmcUtc(_field(f, 0), _field(f, 8)),
        );
    }
    return null;
  }

  static DateTime? _rmcUtc(String time, String date) {
    if (time.length < 6 || date.length != 6) return null;
    final hh = int.tryParse(time.substring(0, 2));
    final mm = int.tryParse(time.substring(2, 4));
    final ss = double.tryParse(time.substring(4));
    final day = int.tryParse(date.substring(0, 2));
    final month = int.tryParse(date.substring(2, 4));
    final yy = int.tryParse(date.substring(4, 6));
    if ([hh, mm, ss, day, month, yy].contains(null)) return null;
    final year = yy! >= 80 ? 1900 + yy : 2000 + yy;
    final whole = ss!.floor();
    return DateTime.utc(
      year,
      month!,
      day!,
      hh!,
      mm!,
      whole,
      ((ss - whole) * 1000).round(),
    );
  }
}
