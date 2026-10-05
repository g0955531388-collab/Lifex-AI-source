/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: packet_type.dart
/// النقل ليس البروتوكول.
/// =============================================================
library lifex_ai.core.device_protocol.packet_type;

enum PacketType {
  hello,
  helloAck,
  discovery,
  probeRequest,
  probeResponse,
  capabilityRequest,
  capabilityResponse,
  authenticationRequest,
  authenticationResponse,
  sessionOpen,
  sessionClose,
  stateRequest,
  stateResponse,
  stateUpdate,
  stateSnapshot,
  stateDelta,
  commandRequest,
  commandAck,
  commandResult,
  commandCancel,
  eventSubscribe,
  eventUnsubscribe,
  event,
  streamOpen,
  streamData,
  streamControl,
  streamClose,
  ping,
  pong,
  timeSync,
  error,
}

enum ProtocolSessionStage {
  discovered,
  identified,
  connected,
  authenticated,
  authorized,
  controllable,
}

extension ProtocolSessionStageX on ProtocolSessionStage {
  bool get mayRead =>
      index >= ProtocolSessionStage.authenticated.index;
  bool get mayControl => this == ProtocolSessionStage.controllable;
  bool get medicalReadOk =>
      index >= ProtocolSessionStage.authorized.index;
}

enum ProtocolErrorCode {
  unknown,
  unsupportedProtocol,
  unsupportedCommand,
  unauthorized,
  authenticationFailed,
  deviceBusy,
  timeout,
  invalidPacket,
  invalidPayload,
  sequenceError,
  integrityFailure,
  sessionExpired,
  capabilityUnavailable,
  transportFailure,
  deviceFailure,
  replayDetected,
  encryptionUnbound,
  medicalControlForbidden,
  skippedStage,
}

enum PermissionScope {
  read,
  write,
  control,
  stream,
  admin,
  emergency,
  medicalRead,
  medicalControl,
}
