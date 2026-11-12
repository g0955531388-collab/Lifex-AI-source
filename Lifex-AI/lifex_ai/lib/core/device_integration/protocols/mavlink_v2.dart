/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: mavlink_v2.dart
/// قراءة إطارات MAVLink v2 (درون/روبوت) مع تحقق CRC. قراءة فقط:
/// إرسال أوامر الطيران غير مربوط حتى يُتحقق منه على جهاز أو محاكي (SITL).
/// =============================================================
library lifex_ai.core.device_integration.protocols.mavlink_v2;

import 'dart:typed_data';

import 'byte_stream_decoder.dart';

class MavlinkFrame {
  const MavlinkFrame({
    required this.sequence,
    required this.systemId,
    required this.componentId,
    required this.messageId,
    required this.payload,
    required this.signed,
  });

  final int sequence;
  final int systemId;
  final int componentId;
  final int messageId;

  /// الحمولة بعد إعادة الأصفار المقتطعة إلى طولها الكامل.
  final Uint8List payload;

  /// يحمل توقيعاً لم يُتحقق منه (لا مفتاح توقيع مربوط).
  final bool signed;
}

class MavHeartbeat {
  const MavHeartbeat({
    required this.customMode,
    required this.vehicleType,
    required this.autopilot,
    required this.baseMode,
    required this.systemStatus,
  });

  final int customMode;
  final int vehicleType;
  final int autopilot;
  final int baseMode;
  final int systemStatus;

  /// MAV_MODE_FLAG_SAFETY_ARMED
  bool get armed => baseMode & 0x80 != 0;
}

class MavGlobalPosition {
  const MavGlobalPosition({
    required this.timeBootMs,
    required this.latitude,
    required this.longitude,
    required this.altitudeMslM,
    required this.relativeAltitudeM,
    required this.vxMs,
    required this.vyMs,
    required this.vzMs,
    required this.headingDeg,
  });

  final int timeBootMs;
  final double latitude;
  final double longitude;
  final double altitudeMslM;
  final double relativeAltitudeM;
  final double vxMs;
  final double vyMs;
  final double vzMs;

  /// null عندما يرسل الجهاز UINT16_MAX (غير معروف).
  final double? headingDeg;
}

class MavCommandAck {
  const MavCommandAck({required this.command, required this.result});
  final int command;

  /// MAV_RESULT: 0 = مقبول.
  final int result;
  bool get accepted => result == 0;
}

class MavlinkV2Decoder implements ByteStreamDecoder<MavlinkFrame> {
  static const stx = 0xFD;
  static const msgHeartbeat = 0;
  static const msgGlobalPositionInt = 33;
  static const msgCommandAck = 77;

  /// CRC_EXTRA وأطوال الحمولة الأساسية من تعريف common.xml.
  static const crcExtra = {
    msgHeartbeat: 50,
    msgGlobalPositionInt: 104,
    msgCommandAck: 143,
  };
  static const payloadLength = {
    msgHeartbeat: 9,
    msgGlobalPositionInt: 28,
    msgCommandAck: 3,
  };

  final _buffer = <int>[];
  int _rejected = 0;
  int _unknown = 0;

  @override
  String get protocolName => 'mavlink2';

  @override
  int get rejected => _rejected;

  /// رسائل صحيحة الإطار لكن غير مدعومة هنا (لا يمكن التحقق من CRC بلا CRC_EXTRA).
  int get unknownMessages => _unknown;

  @override
  void reset() => _buffer.clear();

  /// CRC-16/MCRF4XX كما في crc_accumulate في MAVLink.
  static int crcAccumulate(int byte, int crc) {
    var tmp = (byte ^ (crc & 0xFF)) & 0xFF;
    tmp = (tmp ^ (tmp << 4)) & 0xFF;
    return ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF;
  }

  static int crc(Iterable<int> bytes, {int seed = 0xFFFF}) {
    var c = seed;
    for (final b in bytes) {
      c = crcAccumulate(b, c);
    }
    return c;
  }

  @override
  List<MavlinkFrame> feed(List<int> bytes) {
    _buffer.addAll(bytes);
    final out = <MavlinkFrame>[];
    while (true) {
      final start = _buffer.indexOf(stx);
      if (start < 0) {
        _buffer.clear();
        break;
      }
      if (start > 0) _buffer.removeRange(0, start);
      if (_buffer.length < 10) break;
      final len = _buffer[1];
      final incompat = _buffer[2];
      if (incompat & ~0x01 != 0) {
        _rejected++;
        _buffer.removeAt(0);
        continue;
      }
      final signed = incompat & 0x01 != 0;
      final total = 10 + len + 2 + (signed ? 13 : 0);
      if (_buffer.length < total) break;
      final msgId = _buffer[7] | (_buffer[8] << 8) | (_buffer[9] << 16);
      final extra = crcExtra[msgId];
      if (extra == null) {
        _unknown++;
        _buffer.removeRange(0, total);
        continue;
      }
      final expected = crcAccumulate(extra, crc(_buffer.getRange(1, 10 + len)));
      final declared = _buffer[10 + len] | (_buffer[11 + len] << 8);
      if (expected != declared) {
        _rejected++;
        _buffer.removeAt(0);
        continue;
      }
      final full = payloadLength[msgId]!;
      final payload = Uint8List(len > full ? len : full)
        ..setRange(0, len, _buffer.getRange(10, 10 + len));
      out.add(MavlinkFrame(
        sequence: _buffer[4],
        systemId: _buffer[5],
        componentId: _buffer[6],
        messageId: msgId,
        payload: payload,
        signed: signed,
      ));
      _buffer.removeRange(0, total);
    }
    return out;
  }

  /// تأطير حمولة كما يفعل المرسِل (للاختبار والمحاكاة)، مع اقتطاع الأصفار الأخيرة.
  static Uint8List encodeFrame({
    required int messageId,
    required List<int> payload,
    int sequence = 0,
    int systemId = 1,
    int componentId = 1,
  }) {
    var len = payload.length;
    while (len > 1 && payload[len - 1] == 0) {
      len--;
    }
    final header = [
      len,
      0,
      0,
      sequence & 0xFF,
      systemId & 0xFF,
      componentId & 0xFF,
      messageId & 0xFF,
      (messageId >> 8) & 0xFF,
      (messageId >> 16) & 0xFF,
    ];
    final body = [...header, ...payload.take(len)];
    final c = crcAccumulate(crcExtra[messageId] ?? 0, crc(body));
    return Uint8List.fromList([stx, ...body, c & 0xFF, c >> 8]);
  }

  static MavHeartbeat heartbeat(MavlinkFrame f) {
    final d = ByteData.sublistView(f.payload);
    return MavHeartbeat(
      customMode: d.getUint32(0, Endian.little),
      vehicleType: d.getUint8(4),
      autopilot: d.getUint8(5),
      baseMode: d.getUint8(6),
      systemStatus: d.getUint8(7),
    );
  }

  static MavGlobalPosition globalPosition(MavlinkFrame f) {
    final d = ByteData.sublistView(f.payload);
    final hdg = d.getUint16(26, Endian.little);
    return MavGlobalPosition(
      timeBootMs: d.getUint32(0, Endian.little),
      latitude: d.getInt32(4, Endian.little) / 1e7,
      longitude: d.getInt32(8, Endian.little) / 1e7,
      altitudeMslM: d.getInt32(12, Endian.little) / 1000,
      relativeAltitudeM: d.getInt32(16, Endian.little) / 1000,
      vxMs: d.getInt16(20, Endian.little) / 100,
      vyMs: d.getInt16(22, Endian.little) / 100,
      vzMs: d.getInt16(24, Endian.little) / 100,
      headingDeg: hdg == 0xFFFF ? null : hdg / 100,
    );
  }

  static MavCommandAck commandAck(MavlinkFrame f) {
    final d = ByteData.sublistView(f.payload);
    return MavCommandAck(
      command: d.getUint16(0, Endian.little),
      result: d.getUint8(2),
    );
  }
}
