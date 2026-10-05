/// =============================================================
/// Lifex-AI — بروتوكول أجهزة
/// الملف: lifex_protocol.dart
/// DISCOVERED ≠ IDENTIFIED ≠ CONNECTED ≠ AUTHENTICATED ≠ AUTHORIZED ≠ CONTROLABLE
/// =============================================================
library lifex_ai.core.device_protocol.lifex_protocol;

import 'packet_type.dart';
import 'protocol_codec.dart';
import 'protocol_packet.dart';
import 'protocol_session.dart';

class LifexProtocol {
  LifexProtocol({
    ProtocolCodec? codec,
    this.encryptionBound = false,
    this.hardwareTransportBound = false,
  }) : codec = codec ?? const ProtocolCodec();

  final ProtocolCodec codec;
  final bool encryptionBound;
  final bool hardwareTransportBound;
  final sessions = <String, ProtocolSession>{};
  final capabilities = <String, List<CapabilityDescriptor>>{};
  final snapshots = <String, Map<String, dynamic>>{};
  final eventsOut = <EventPacket>[];

  ProtocolSession sessionFor(String deviceId) {
    return sessions.putIfAbsent(
      deviceId,
      () => ProtocolSession(
        sessionId: 'sess_$deviceId',
        deviceId: deviceId,
        encryptionBound: encryptionBound,
      ),
    );
  }

  ProtocolSessionStage stageOf(String deviceId) => sessionFor(deviceId).stage;

  CommandResult identify(String deviceId, {required List<CapabilityDescriptor> caps}) {
    final s = sessionFor(deviceId);
    if (s.stage != ProtocolSessionStage.discovered) {
      return s.rejectSkip(ProtocolSessionStage.identified);
    }
    capabilities[deviceId] = List.of(caps);
    s.advanceTo(ProtocolSessionStage.identified);
    return const CommandResult(ok: true);
  }

  CommandResult connect(String deviceId) {
    final s = sessionFor(deviceId);
    if (s.stage != ProtocolSessionStage.identified) {
      return s.rejectSkip(ProtocolSessionStage.connected);
    }
    s.advanceTo(ProtocolSessionStage.connected);
    return const CommandResult(ok: true);
  }

  CommandResult authenticate(String deviceId, {required bool credentialsOk}) {
    final s = sessionFor(deviceId);
    if (s.stage != ProtocolSessionStage.connected) {
      return s.rejectSkip(ProtocolSessionStage.authenticated);
    }
    if (!credentialsOk) {
      return const CommandResult(
        ok: false,
        reason: 'authenticationFailed',
      );
    }
    s.advanceTo(ProtocolSessionStage.authenticated);
    return const CommandResult(ok: true);
  }

  CommandResult authorize(String deviceId, {required Set<PermissionScope> scopes}) {
    final s = sessionFor(deviceId);
    if (s.stage != ProtocolSessionStage.authenticated) {
      return s.rejectSkip(ProtocolSessionStage.authorized);
    }
    if (!scopes.contains(PermissionScope.read) &&
        !scopes.contains(PermissionScope.medicalRead)) {
      return const CommandResult(ok: false, reason: 'unauthorized');
    }
    s.advanceTo(ProtocolSessionStage.authorized);
    return const CommandResult(ok: true);
  }

  CommandResult grantControl(String deviceId, {required Set<PermissionScope> scopes}) {
    final s = sessionFor(deviceId);
    if (s.stage != ProtocolSessionStage.authorized) {
      return s.rejectSkip(ProtocolSessionStage.controllable);
    }
    if (!scopes.contains(PermissionScope.control)) {
      return const CommandResult(ok: false, reason: 'unauthorized');
    }
    s.advanceTo(ProtocolSessionStage.controllable);
    return const CommandResult(ok: true);
  }

  CommandResult execute(CommandRequest cmd) {
    final s = sessionFor(cmd.deviceId);
    if (s.replay(cmd.commandId)) {
      return const CommandResult(ok: false, reason: 'replayDetected');
    }
    if (s.duplicateCommand(cmd.idempotencyKey)) {
      return const CommandResult(ok: true, reason: 'idempotent_replay');
    }
    if (cmd.medicalControl) {
      return const CommandResult(
        ok: false,
        reason: 'medicalControlForbidden',
      );
    }
    if (!s.stage.mayControl) {
      return const CommandResult(ok: false, reason: 'unauthorized');
    }
    final caps = capabilities[cmd.deviceId] ?? const [];
    final known = caps.any((c) => c.commands.contains(cmd.action) && c.controllable);
    if (!known) {
      return const CommandResult(ok: false, reason: 'unsupportedCommand');
    }
    snapshots[cmd.deviceId] = {
      ...?snapshots[cmd.deviceId],
      ...cmd.parameters,
    };
    return CommandResult(
      ok: true,
      executedOnDevice: true,
      values: Map.of(snapshots[cmd.deviceId]!),
    );
  }

  StateSnapshot? readState(String deviceId) {
    final s = sessionFor(deviceId);
    if (!s.stage.mayRead) return null;
    return StateSnapshot(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      values: Map.of(snapshots[deviceId] ?? const {}),
    );
  }

  ProtocolPacket? parse(List<int> bytes) => codec.decode(bytes);

  bool claimsEncryptedLink() => encryptionBound;
}
