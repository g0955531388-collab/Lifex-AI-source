/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: protocol_packet.dart
/// =============================================================
library lifex_ai.core.device_protocol.protocol_packet;

import 'packet_type.dart';

class ProtocolHeader {
  const ProtocolHeader({
    required this.packetId,
    required this.sessionId,
    required this.sourceDeviceId,
    required this.targetDeviceId,
    required this.type,
    required this.sequence,
    required this.timestamp,
    this.protocolVersion = 1,
    this.flags = 0,
    this.payloadLength = 0,
    this.integrity = '',
    this.nonce = '',
  });

  final int protocolVersion;
  final String packetId;
  final String sessionId;
  final String sourceDeviceId;
  final String targetDeviceId;
  final PacketType type;
  final int flags;
  final int sequence;
  final DateTime timestamp;
  final int payloadLength;
  final String integrity;
  final String nonce;
}

class ProtocolPacket {
  const ProtocolPacket({
    required this.header,
    this.payload = const {},
  });

  final ProtocolHeader header;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'version': header.protocolVersion,
        'packetId': header.packetId,
        'sessionId': header.sessionId,
        'source': header.sourceDeviceId,
        'target': header.targetDeviceId,
        'type': header.type.name,
        'sequence': header.sequence,
        'timestamp': header.timestamp.toIso8601String(),
        'flags': header.flags,
        'nonce': header.nonce,
        'integrity': header.integrity,
        'payload': payload,
      };

  factory ProtocolPacket.fromJson(Map<String, dynamic> json) {
    return ProtocolPacket(
      header: ProtocolHeader(
        protocolVersion: json['version'] as int? ?? 1,
        packetId: '${json['packetId'] ?? ''}',
        sessionId: '${json['sessionId'] ?? ''}',
        sourceDeviceId: '${json['source'] ?? ''}',
        targetDeviceId: '${json['target'] ?? ''}',
        type: PacketType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PacketType.error,
        ),
        sequence: json['sequence'] as int? ?? 0,
        timestamp:
            DateTime.tryParse('${json['timestamp']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        flags: json['flags'] as int? ?? 0,
        nonce: '${json['nonce'] ?? ''}',
        integrity: '${json['integrity'] ?? ''}',
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    );
  }
}

class CapabilityDescriptor {
  const CapabilityDescriptor({
    required this.id,
    required this.name,
    required this.category,
    this.readable = false,
    this.writable = false,
    this.controllable = false,
    this.streamable = false,
    this.medical = false,
    this.commands = const [],
  });

  final String id;
  final String name;
  final String category;
  final bool readable;
  final bool writable;
  final bool controllable;
  final bool streamable;
  final bool medical;
  final List<String> commands;
}

class CommandRequest {
  const CommandRequest({
    required this.commandId,
    required this.deviceId,
    required this.action,
    required this.timestamp,
    required this.idempotencyKey,
    this.parameters = const {},
    this.medicalControl = false,
  });

  final String commandId;
  final String deviceId;
  final String action;
  final DateTime timestamp;
  final String idempotencyKey;
  final Map<String, dynamic> parameters;
  final bool medicalControl;
}

class CommandResult {
  const CommandResult({
    required this.ok,
    this.reason = '',
    this.executedOnDevice = false,
    this.values = const {},
  });

  final bool ok;
  final String reason;
  final bool executedOnDevice;
  final Map<String, dynamic> values;
}

class StateSnapshot {
  const StateSnapshot({
    required this.deviceId,
    required this.timestamp,
    this.values = const {},
  });

  final String deviceId;
  final DateTime timestamp;
  final Map<String, dynamic> values;
}

class EventPacket {
  const EventPacket({
    required this.eventId,
    required this.deviceId,
    required this.eventType,
    required this.timestamp,
    this.data = const {},
    this.clinicalInterpretation = false,
  });

  final String eventId;
  final String deviceId;
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool clinicalInterpretation;
}
