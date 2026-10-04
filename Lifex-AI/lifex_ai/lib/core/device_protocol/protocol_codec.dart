/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: protocol_codec.dart
/// حزمة تالفة تُرفض. لا اختراع محتوى.
/// =============================================================
library lifex_ai.core.device_protocol.protocol_codec;

import 'dart:convert';

import 'protocol_packet.dart';

class ProtocolCodec {
  const ProtocolCodec();

  List<int> encode(ProtocolPacket packet) {
    return utf8.encode(jsonEncode(packet.toJson()));
  }

  ProtocolPacket? decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      final map = jsonDecode(utf8.decode(bytes));
      if (map is! Map<String, dynamic>) return null;
      if (map['type'] == null || map['packetId'] == null) return null;
      return ProtocolPacket.fromJson(map);
    } on FormatException {
      return null;
    }
  }
}
