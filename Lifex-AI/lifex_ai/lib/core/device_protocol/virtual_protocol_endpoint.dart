/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: virtual_protocol_endpoint.dart
/// جهاز مختبر يتحدث نفس الحزم دون ادعاء عتاد.
/// =============================================================
library lifex_ai.core.device_protocol.virtual_protocol_endpoint;

import 'protocol_codec.dart';
import 'protocol_packet.dart';

class VirtualProtocolEndpoint {
  VirtualProtocolEndpoint({
    required this.deviceId,
    ProtocolCodec? codec,
  }) : codec = codec ?? const ProtocolCodec();

  final String deviceId;
  final ProtocolCodec codec;
  final outgoing = <List<int>>[];

  List<int> receive(List<int> packet) {
    final decoded = codec.decode(packet);
    if (decoded == null) return const [];
    final ack = ProtocolPacket(
      header: ProtocolHeader(
        packetId: 'ack_${decoded.header.packetId}',
        sessionId: decoded.header.sessionId,
        sourceDeviceId: deviceId,
        targetDeviceId: decoded.header.sourceDeviceId,
        type: decoded.header.type,
        sequence: decoded.header.sequence + 1,
        timestamp: DateTime.now(),
      ),
      payload: {'echo': true, 'ok': true},
    );
    final bytes = codec.encode(ack);
    outgoing.add(bytes);
    return bytes;
  }
}
