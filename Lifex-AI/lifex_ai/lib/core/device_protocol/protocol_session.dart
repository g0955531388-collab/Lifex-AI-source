/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: protocol_session.dart
/// لا قفز من identified إلى controllable.
/// =============================================================
library lifex_ai.core.device_protocol.protocol_session;

import 'packet_type.dart';
import 'protocol_packet.dart';

class ProtocolSession {
  ProtocolSession({
    required this.sessionId,
    required this.deviceId,
    this.encryptionBound = false,
  });

  final String sessionId;
  final String deviceId;
  final bool encryptionBound;
  ProtocolSessionStage stage = ProtocolSessionStage.discovered;
  int sequence = 0;
  final seenIds = <String>{};
  final seenIdempotency = <String>{};
  DateTime openedAt = DateTime.now();

  bool advanceTo(ProtocolSessionStage next) {
    if (next.index != stage.index + 1) return false;
    stage = next;
    return true;
  }

  CommandResult rejectSkip(ProtocolSessionStage wanted) {
    return CommandResult(
      ok: false,
      reason: ProtocolErrorCode.skippedStage.name,
    );
  }

  bool replay(String packetId) {
    if (seenIds.contains(packetId)) return true;
    seenIds.add(packetId);
    return false;
  }

  bool duplicateCommand(String idempotencyKey) {
    if (seenIdempotency.contains(idempotencyKey)) return true;
    seenIdempotency.add(idempotencyKey);
    return false;
  }
}
