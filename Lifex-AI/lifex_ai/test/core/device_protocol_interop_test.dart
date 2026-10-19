/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_protocol_interop_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_interoperability/interoperability_engine.dart';
import 'package:lifex_ai/core/device_protocol/lifex_protocol.dart';
import 'package:lifex_ai/core/device_protocol/packet_type.dart';
import 'package:lifex_ai/core/device_protocol/protocol_codec.dart';
import 'package:lifex_ai/core/device_protocol/protocol_packet.dart';
import 'package:lifex_ai/core/device_protocol/virtual_protocol_endpoint.dart';

void main() {
  test('cannot jump from identified to controllable', () {
    final p = LifexProtocol();
    expect(p.grantControl('d1', scopes: {PermissionScope.control}).ok, isFalse);
    expect(p.identify('d1', caps: const []).ok, isTrue);
    expect(p.grantControl('d1', scopes: {PermissionScope.control}).ok, isFalse);
    expect(p.stageOf('d1'), ProtocolSessionStage.identified);
  });

  test('full ladder then unsupported POWER_OFF is not invented', () {
    final p = LifexProtocol();
    p.identify('tv', caps: const [
      CapabilityDescriptor(
        id: 'volume',
        name: 'volume',
        category: 'audio',
        controllable: true,
        commands: ['SET_VOLUME'],
      ),
    ]);
    p.connect('tv');
    p.authenticate('tv', credentialsOk: true);
    p.authorize('tv', scopes: {PermissionScope.read});
    p.grantControl('tv', scopes: {PermissionScope.control});
    final off = p.execute(
      CommandRequest(
        commandId: 'c1',
        deviceId: 'tv',
        action: 'POWER_OFF',
        timestamp: DateTime.now(),
        idempotencyKey: 'k1',
      ),
    );
    expect(off.ok, isFalse);
    expect(off.reason, 'unsupportedCommand');
    final vol = p.execute(
      CommandRequest(
        commandId: 'c2',
        deviceId: 'tv',
        action: 'SET_VOLUME',
        timestamp: DateTime.now(),
        idempotencyKey: 'k2',
        parameters: {'volume': 35},
      ),
    );
    expect(vol.ok, isTrue);
    expect(vol.executedOnDevice, isTrue);
  });

  test('medical control forbidden even when controllable', () {
    final p = LifexProtocol();
    p.identify('pump', caps: const [
      CapabilityDescriptor(
        id: 'flow',
        name: 'flow',
        category: 'medical',
        medical: true,
        controllable: true,
        commands: ['START_INFUSION'],
      ),
    ]);
    p.connect('pump');
    p.authenticate('pump', credentialsOk: true);
    p.authorize('pump', scopes: {PermissionScope.medicalRead});
    p.grantControl('pump', scopes: {PermissionScope.control});
    final r = p.execute(
      CommandRequest(
        commandId: 'm1',
        deviceId: 'pump',
        action: 'START_INFUSION',
        timestamp: DateTime.now(),
        idempotencyKey: 'mk',
        medicalControl: true,
      ),
    );
    expect(r.reason, 'medicalControlForbidden');
  });

  test('replay and idempotency', () {
    final p = LifexProtocol();
    p.identify('tv', caps: const [
      CapabilityDescriptor(
        id: 'volume',
        name: 'volume',
        category: 'audio',
        controllable: true,
        commands: ['SET_VOLUME'],
      ),
    ]);
    p.connect('tv');
    p.authenticate('tv', credentialsOk: true);
    p.authorize('tv', scopes: {PermissionScope.read});
    p.grantControl('tv', scopes: {PermissionScope.control});
    final a = CommandRequest(
      commandId: 'same',
      deviceId: 'tv',
      action: 'SET_VOLUME',
      timestamp: DateTime.now(),
      idempotencyKey: 'idem',
      parameters: const {'volume': 10},
    );
    expect(p.execute(a).ok, isTrue);
    expect(p.execute(a).reason, 'replayDetected');
  });

  test('codec rejects corrupt bytes; virtual endpoint echoes', () {
    const codec = ProtocolCodec();
    expect(codec.decode([1, 2, 3]), isNull);
    final ep = VirtualProtocolEndpoint(deviceId: 'sim');
    final pkt = ProtocolPacket(
      header: ProtocolHeader(
        packetId: 'h1',
        sessionId: 's',
        sourceDeviceId: 'phone',
        targetDeviceId: 'sim',
        type: PacketType.hello,
        sequence: 0,
        timestamp: DateTime.now(),
      ),
    );
    final out = ep.receive(codec.encode(pkt));
    expect(codec.decode(out)!.payload['echo'], isTrue);
  });

  test('interop unknown not trusted; no invented mapping', () {
    final engine = DeviceInteroperabilityEngine();
    final u = engine.inspect(
      deviceId: 'x',
      knownAdapter: false,
      genericServices: false,
      trusted: false,
    );
    expect(u.controlAvailable, isFalse);
    expect(u.reason, 'unknown_not_trusted');
    expect(
      engine
          .translateAndExecute(deviceId: 'x', universalCommand: 'POWER_OFF')
          .reason,
      'unsupportedCommand',
    );
    expect(const UnitConverter().convert(value: 1, from: 'kPa', to: 'mmHg'), isNull);
    expect(const UnitConverter().convert(value: 0, from: 'C', to: 'F'), 32);
  });

  test('encryption claim is false unless bound', () {
    expect(LifexProtocol().claimsEncryptedLink(), isFalse);
    expect(LifexProtocol(encryptionBound: true).claimsEncryptedLink(), isTrue);
  });
}
