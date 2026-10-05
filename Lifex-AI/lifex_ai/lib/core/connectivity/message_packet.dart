/// =============================================================
/// Lifex-AI — اتصال
/// الملف: message_packet.dart
/// حزمة بروتوكول Lifex. ليست وصفة ولا أمراً طبياً.
/// =============================================================
library lifex_ai.core.connectivity.message_packet;

class MessagePacket {
  const MessagePacket({
    required this.messageId,
    required this.deviceId,
    required this.command,
    required this.timestamp,
    this.payload = const {},
    this.direction = PacketDirection.toDevice,
  });

  final String messageId;
  final String deviceId;
  final String command;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final PacketDirection direction;

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'deviceId': deviceId,
        'command': command,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
        'direction': direction.name,
      };
}

enum PacketDirection { toDevice, fromDevice }
