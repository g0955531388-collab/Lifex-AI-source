/// =============================================================
/// Lifex-AI — بروتوكول
/// الملف: device_protocol.dart
/// قياس وارد ليس تشخيصاً.
/// =============================================================
library lifex_ai.core.connectivity.protocol.device_protocol;

import 'dart:convert';

import '../message_packet.dart';

class HeartbeatPacket {
  const HeartbeatPacket({required this.deviceId, required this.timestamp});

  final String deviceId;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'command': 'heartbeat',
      };
}

class CommandPacket {
  const CommandPacket(this.packet);
  final MessagePacket packet;
}

class ResponsePacket {
  const ResponsePacket({
    required this.ok,
    required this.packet,
    this.clinicalInterpretation = false,
  });

  final bool ok;
  final MessagePacket packet;
  final bool clinicalInterpretation;
}

class PacketEncoder {
  const PacketEncoder();

  List<int> encode(MessagePacket packet) {
    return utf8.encode(jsonEncode(packet.toJson()));
  }

  List<int> encodeHeartbeat(HeartbeatPacket beat) {
    return utf8.encode(jsonEncode(beat.toJson()));
  }
}

class PacketDecoder {
  const PacketDecoder();

  MessagePacket? decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return MessagePacket(
        messageId: '${map['messageId'] ?? ''}',
        deviceId: '${map['deviceId'] ?? ''}',
        command: '${map['command'] ?? ''}',
        timestamp: DateTime.tryParse('${map['timestamp']}') ?? DateTime.now(),
        payload: Map<String, dynamic>.from(
          map['payload'] as Map? ?? const {},
        ),
        direction: PacketDirection.fromDevice,
      );
    } on FormatException {
      return null;
    }
  }

  ResponsePacket toHealthData(MessagePacket packet) {
    return ResponsePacket(
      ok: packet.command == 'measurement',
      packet: packet,
      clinicalInterpretation: false,
    );
  }
}

class DeviceProtocol {
  const DeviceProtocol({
    this.encoder = const PacketEncoder(),
    this.decoder = const PacketDecoder(),
  });

  final PacketEncoder encoder;
  final PacketDecoder decoder;
}
