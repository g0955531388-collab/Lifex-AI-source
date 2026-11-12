import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_device.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/device_capability.dart';
import 'package:lifex_ai/core/connectivity/lan/lan_secure_channel.dart';
import 'package:lifex_ai/core/connectivity/permission_manager.dart';
import 'package:lifex_ai/core/device_control_center/control_types.dart';
import 'package:lifex_ai/core/device_drivers/device_command.dart';
import 'package:lifex_ai/core/device_integration/device_integration.dart';

Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

int _n = 0;
DeviceCommand cmd(String action, [Map<String, dynamic> params = const {}]) =>
    DeviceCommand(
      id: 'c${++_n}',
      deviceId: 'd',
      action: action,
      timestamp: DateTime.now(),
      parameters: params,
    );

ConnectionDevice bridged(String id, List<DeviceCapability> caps,
        {ConnectionType type = ConnectionType.network}) =>
    ConnectionDevice(
      id: id,
      name: id,
      connectionType: type,
      state: ConnectionState.disconnected,
      capabilities: caps,
    );

/// جهاز طرفي حقيقي على TCP محلي: يبث بايتات ويرد على أوامر LBP بسطور.
class FakeBridgeDevice {
  late ServerSocket server;
  final clients = <Socket>[];
  final commands = <String>[];
  final _line = <int>[];
  int accepted = 0;

  Future<int> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      accepted++;
      clients.add(socket);
      socket.listen((bytes) {
        for (final b in bytes) {
          if (b != 0x0A) {
            _line.add(b);
            continue;
          }
          final msg = jsonDecode(utf8.decode(_line)) as Map<String, dynamic>;
          _line.clear();
          commands.add(msg['action'] as String);
          send(utf8.encode('${jsonEncode({'t': 'ack', 'id': msg['id'], 'ok': true})}\n'));
        }
      }, onError: (_) {}, onDone: () => clients.remove(socket));
    });
    return server.port;
  }

  void send(List<int> bytes) {
    for (final c in clients) {
      c.add(bytes);
    }
  }

  void sendLine(Map<String, Object?> msg) => send(utf8.encode('${jsonEncode(msg)}\n'));

  void dropClients() {
    for (final c in clients.toList()) {
      c.destroy();
    }
    clients.clear();
  }

  Future<void> stop() async {
    dropClients();
    await server.close();
  }
}

void main() {
  group('NMEA 0183', () {
    const gga = r'$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47';
    const rmc = r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A';

    test('مجموع التحقق يطابق القيم المنشورة للجمل المرجعية', () {
      expect(NmeaDecoder.checksumOf(gga.substring(1, gga.indexOf('*'))), 0x47);
      expect(NmeaDecoder.checksumOf(rmc.substring(1, rmc.indexOf('*'))), 0x6A);
    });

    test('GGA وRMC مقطّعتان عشوائياً تُفكّان إلى موقع صحيح', () {
      final d = NmeaDecoder();
      final bytes = ascii.encode('$gga\r\n$rmc\r\n');
      final out = <NmeaSentence>[];
      for (var i = 0; i < bytes.length; i += 7) {
        out.addAll(d.feed(bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7)));
      }
      expect(out.map((s) => s.type), ['GGA', 'RMC']);
      final a = NmeaDecoder.toFix(out[0])!;
      expect(a.valid, isTrue);
      expect(a.latitude, closeTo(48.1173, 1e-6));
      expect(a.longitude, closeTo(11.516667, 1e-6));
      expect(a.altitudeM, 545.4);
      expect(a.satellites, 8);
      final b = NmeaDecoder.toFix(out[1])!;
      expect(b.speedKnots, 22.4);
      expect(b.courseDeg, 84.4);
      expect(b.utc, DateTime.utc(1994, 3, 23, 12, 35, 19));
    });

    test('مجموع خاطئ أو مفقود يُرفض، وبلا تثبيت لا إحداثيات', () {
      final d = NmeaDecoder();
      expect(d.feed(ascii.encode('${gga.replaceFirst('*47', '*48')}\n')), isEmpty);
      expect(d.feed(ascii.encode('${gga.substring(0, gga.indexOf('*'))}\n')), isEmpty);
      expect(d.rejected, 2);
      const body = 'GPGGA,123519,4807.038,N,01131.000,E,0,00,,,M,,M,,';
      final cs = NmeaDecoder.checksumOf(body).toRadixString(16).padLeft(2, '0').toUpperCase();
      final s = d.feed(ascii.encode('\$$body*$cs\n')).single;
      final fix = NmeaDecoder.toFix(s)!;
      expect(fix.valid, isFalse);
      expect(fix.latitude, isNull);
      expect(fix.toValues().containsKey('lat'), isFalse);
    });
  });

  group('MAVLink v2', () {
    Uint8List heartbeatFrame({int baseMode = 0x80, int seq = 1}) {
      final p = ByteData(9)
        ..setUint32(0, 4, Endian.little)
        ..setUint8(4, 2)
        ..setUint8(5, 3)
        ..setUint8(6, baseMode)
        ..setUint8(7, 4)
        ..setUint8(8, 3);
      return MavlinkV2Decoder.encodeFrame(
          messageId: 0, payload: p.buffer.asUint8List(), sequence: seq);
    }

    Uint8List positionFrame() {
      final p = ByteData(28)
        ..setUint32(0, 1000, Endian.little)
        ..setInt32(4, 335000000, Endian.little)
        ..setInt32(8, 362000000, Endian.little)
        ..setInt32(12, 700500, Endian.little)
        ..setInt32(16, 12000, Endian.little)
        ..setInt16(20, 150, Endian.little)
        ..setInt16(22, -20, Endian.little)
        ..setInt16(24, 0, Endian.little)
        ..setUint16(26, 0xFFFF, Endian.little);
      return MavlinkV2Decoder.encodeFrame(messageId: 33, payload: p.buffer.asUint8List());
    }

    test('CRC-16/MCRF4XX يطابق قيمة الفحص المعيارية', () {
      expect(MavlinkV2Decoder.crc(ascii.encode('123456789')), 0x6F91);
    });

    test('إطارات مقطّعة مع ضجيج قبلها: نبض وموقع صحيحان', () {
      final d = MavlinkV2Decoder();
      final stream = [0x00, 0x13, ...heartbeatFrame(), ...positionFrame()];
      final frames = <MavlinkFrame>[];
      for (final b in stream) {
        frames.addAll(d.feed([b]));
      }
      expect(frames.map((f) => f.messageId), [0, 33]);
      final hb = MavlinkV2Decoder.heartbeat(frames[0]);
      expect(hb.armed, isTrue);
      expect(hb.vehicleType, 2);
      final pos = MavlinkV2Decoder.globalPosition(frames[1]);
      expect(pos.latitude, closeTo(33.5, 1e-9));
      expect(pos.longitude, closeTo(36.2, 1e-9));
      expect(pos.altitudeMslM, 700.5);
      expect(pos.relativeAltitudeM, 12.0);
      expect(pos.vxMs, 1.5);
      expect(pos.headingDeg, isNull);
    });

    test('بايت معدّل يُرفض ثم يُستأنف التزامن مع الإطار التالي', () {
      final d = MavlinkV2Decoder();
      final bad = heartbeatFrame()..[12] ^= 0x01;
      final frames = d.feed([...bad, ...heartbeatFrame(baseMode: 0, seq: 2)]);
      expect(frames.single.sequence, 2);
      expect(MavlinkV2Decoder.heartbeat(frames.single).armed, isFalse);
      expect(d.rejected, greaterThanOrEqualTo(1));
    });
  });

  group('خط القراءات والحالة', () {
    DeviceReading r(String ch, Object v) => DeviceReading(
        deviceId: 'd1', channel: ch, value: v, timestamp: DateTime.now());

    test('آخر قيمة، تصفية، ورفض القيم غير الصالحة', () async {
      final p = ReactiveDataPipeline();
      final got = <Object>[];
      final sub = p.watch(channel: 'spo2').listen((x) => got.add(x.value));
      expect(p.ingest(r('spo2', 97)), isTrue);
      expect(p.ingest(r('hr', 70)), isTrue);
      expect(p.ingest(r('spo2', double.nan)), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(got, [97]);
      expect(p.latest('d1', 'hr')!.value, 70);
      expect(p.rejectedReadings, 1);
      expect(r('spo2', 97).clinicalInterpretation, isFalse);
      await sub.cancel();
      await p.close();
    });

    test('مشترك مقيّد المعدل يتلقى الأحدث فقط دون تراكم', () async {
      final p = ReactiveDataPipeline();
      final got = <Object>[];
      final sub = p
          .watchLatest(
              deviceId: 'd1', channel: 'alt', minInterval: const Duration(milliseconds: 120))
          .listen((x) => got.add(x.value));
      await Future<void>.delayed(Duration.zero);
      for (var i = 1; i <= 5; i++) {
        p.ingest(r('alt', i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(got, [1, 5]);
      expect(p.conflatedReadings, 3);
      await sub.cancel();
      await p.close();
    });

    test('مخزن الحالة يبث اللقطة الحالية ثم التغييرات', () async {
      final store = DeviceLinkStateStore();
      final seen = <ConnectionState>[];
      final sub = store.watch('x').listen((s) => seen.add(s.connection));
      await Future<void>.delayed(Duration.zero);
      store.update('x', (s) => s.copyWith(connection: ConnectionState.connected));
      await Future<void>.delayed(Duration.zero);
      expect(seen, [ConnectionState.disconnected, ConnectionState.connected]);
      expect(store.of('x').controllable, isFalse);
      await sub.cancel();
      await store.close();
    });
  });

  group('جسر TCP: GPS ودرون وجهاز طبي', () {
    late FakeBridgeDevice peer;
    late BridgeTcpTransport transport;
    late PermissionManager permissions;

    setUp(() async {
      peer = FakeBridgeDevice();
      final port = await peer.start();
      final book = BridgeEndpointBook();
      for (final id in ['gps1', 'drone1', 'robot1', 'med1']) {
        book.add(BridgeEndpoint(
          deviceId: id,
          name: id,
          host: InternetAddress.loopbackIPv4.address,
          port: port,
        ));
      }
      transport = BridgeTcpTransport(
        endpoints: book,
        backoff: const ReconnectBackoff(
            base: Duration(milliseconds: 40), max: Duration(milliseconds: 200)),
      );
      permissions = PermissionManager();
    });

    tearDown(() async {
      await transport.dispose();
      await peer.stop();
    });

    test('GPS: مواقع حية إلى الخط، والقناة معلنة غير مشفّرة', () async {
      final pipeline = ReactiveDataPipeline();
      final gps = bridged('gps1', [DeviceCapability.location, DeviceCapability.readData]);
      permissions.grant(gps, DeviceCapability.readData);
      final driver = GpsNavigationDriver(
          transport: transport, pipeline: pipeline, permissions: permissions);
      expect((await driver.connect(gps)).ok, isTrue);
      await waitFor(() => peer.clients.isNotEmpty);
      peer.send(ascii.encode(
          '\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n'));
      await waitFor(() => pipeline.latest('gps1', 'position') != null);
      final pos = pipeline.latest('gps1', 'position')!;
      expect((pos.value as Map)['lat'], closeTo(48.1173, 1e-6));
      expect(pos.secureLink, isFalse);
      expect(driver.states.of('gps1').secureChannel, isFalse);
      expect((await driver.sendCommand(cmd('SET_RATE'))).reason, 'read_only_device');
      await driver.dispose();
      await pipeline.close();
    });

    test('GPS بلا منح قراءة: لا شيء يمر', () async {
      final pipeline = ReactiveDataPipeline();
      final gps = bridged('gps1', [DeviceCapability.location, DeviceCapability.readData]);
      final driver = GpsNavigationDriver(
          transport: transport, pipeline: pipeline, permissions: permissions);
      await driver.connect(gps);
      await waitFor(() => peer.clients.isNotEmpty);
      peer.send(ascii.encode(
          '\$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n'));
      await waitFor(() => driver.withheldReadings > 0);
      expect(pipeline.latest('gps1', 'position'), isNull);
      await driver.dispose();
      await pipeline.close();
    });

    test('انقطاع الجهاز ثم عودته: إعادة اتصال تلقائية', () async {
      final gps = bridged('gps1', [DeviceCapability.location, DeviceCapability.readData]);
      final driver = GpsNavigationDriver(transport: transport, permissions: permissions);
      final seen = <ConnectionState>[];
      final sub = driver.states.changes.listen((s) => seen.add(s.connection));
      await driver.connect(gps);
      await waitFor(() => peer.accepted == 1);
      peer.dropClients();
      await waitFor(() => seen.contains(ConnectionState.reconnecting));
      await waitFor(() => peer.accepted == 2 && gps.state == ConnectionState.connected);
      await sub.cancel();
      await driver.dispose();
    });

    test('درون MAVLink: حالة التسليح والموقع، وأوامر الطيران غير مربوطة', () async {
      final pipeline = ReactiveDataPipeline();
      final drone = bridged('drone1', [DeviceCapability.mobility, DeviceCapability.readData]);
      permissions.grant(drone, DeviceCapability.readData);
      final driver = RoboticsDroneDriver(
        transport: transport,
        protocol: RoboticsProtocol.mavlink,
        pipeline: pipeline,
        permissions: permissions,
      );
      await driver.connect(drone);
      await waitFor(() => peer.clients.isNotEmpty);
      final hb = ByteData(9)..setUint8(6, 0x80)..setUint8(4, 2);
      final pos = ByteData(28)
        ..setInt32(4, 335000000, Endian.little)
        ..setInt32(8, 362000000, Endian.little);
      peer.send([
        ...MavlinkV2Decoder.encodeFrame(messageId: 0, payload: hb.buffer.asUint8List()),
        ...MavlinkV2Decoder.encodeFrame(messageId: 33, payload: pos.buffer.asUint8List()),
      ]);
      await waitFor(() => pipeline.latest('drone1', 'position') != null);
      expect((await driver.readState()).values['armed'], isTrue);
      expect((pipeline.latest('drone1', 'position')!.value as Map)['lat'],
          closeTo(33.5, 1e-9));
      expect((await driver.sendCommand(cmd('TAKEOFF'))).reason, 'read_only_device');
      await driver.dispose();
      await pipeline.close();
    });

    test('روبوت على قناة غير مشفّرة: الحركة مرفوضة والإيقاف الطارئ يصل', () async {
      final robot = bridged('robot1', [DeviceCapability.mobility, DeviceCapability.readData]);
      permissions
        ..grant(robot, DeviceCapability.mobility)
        ..grant(robot, DeviceCapability.readData);
      final driver = RoboticsDroneDriver(transport: transport, permissions: permissions);
      await driver.connect(robot);
      await waitFor(() => peer.clients.isNotEmpty);
      peer.sendLine({'t': 'caps', 'actions': ['MOVE_FORWARD', 'EMERGENCY_STOP']});
      await waitFor(() => driver.states.of('robot1').declaredActions != null);
      final move = await driver.sendCommand(cmd('MOVE_FORWARD', {'userConfirmed': true}));
      expect(move.reason, 'insecure_channel');
      final stop = await driver.sendCommand(cmd('EMERGENCY_STOP'));
      expect(stop.ok, isTrue);
      expect(stop.executedOnHardware, isTrue);
      expect(peer.commands, ['EMERGENCY_STOP']);
      expect(driver.states.of('robot1').lastCommand!.status, CommandStatus.acknowledged);
      await driver.dispose();
    });

    test('جهاز طبي: القياس ملاحظة، والتحكم ممنوع حتى لو أعلنه الجهاز', () async {
      final pipeline = ReactiveDataPipeline();
      final med = bridged('med1', [DeviceCapability.readData, DeviceCapability.vitalSigns]);
      permissions
        ..grant(med, DeviceCapability.readData)
        ..grant(med, DeviceCapability.writeData);
      final driver = SmartHomeMedicalDriver(
        transport: transport,
        applianceClass: ApplianceClass.medical,
        pipeline: pipeline,
        permissions: permissions,
      );
      await driver.connect(med);
      await waitFor(() => peer.clients.isNotEmpty);
      peer.sendLine({'t': 'caps', 'actions': ['SET_RATE', 'READ_SPO2']});
      peer.sendLine({'t': 'reading', 'channel': 'spo2', 'value': 97, 'unit': '%'});
      await waitFor(() => pipeline.latest('med1', 'spo2') != null);
      final reading = pipeline.latest('med1', 'spo2')!;
      expect(reading.unit, '%');
      expect(reading.clinicalInterpretation, isFalse);
      expect((await driver.sendCommand(cmd('SET_RATE'))).reason, 'medicalControlForbidden');
      expect(peer.commands, isEmpty);
      await driver.dispose();
      await pipeline.close();
    });
  });

  group('روبوت عبر قناة Lifex المشفّرة (LAN)', () {
    test('غير معلن، بلا تأكيد، بلا تخويل، ثم تنفيذ مؤكَّد', () async {
      final key = LanFrameCipher.newPairingKey();
      final host = LanSyncHost(pairingKey: key);
      final port = await host.start(address: InternetAddress.loopbackIPv4);
      final executed = <String>[];
      final bridge = LocalScreenSyncResponder(
        host: host,
        handler: (action, params) async {
          executed.add(action);
          return null;
        },
      );
      final lan = LanTransport(
        pairing: LanPairingBook()
          ..pair(LanEndpoint(
            deviceId: 'chair',
            name: 'chair',
            host: InternetAddress.loopbackIPv4.address,
            port: port,
            pairingKey: key,
          )),
      );
      final chair = bridged('chair', [DeviceCapability.mobility, DeviceCapability.readData],
          type: ConnectionType.wifi);
      final permissions = PermissionManager()
        ..grant(chair, DeviceCapability.mobility)
        ..grant(chair, DeviceCapability.readData);
      final BaseDeviceDriver asBase = RoboticsDroneDriver(
          transport: lan, permissions: permissions);
      final driver = asBase as RoboticsDroneDriver;
      expect((await driver.connect(chair)).ok, isTrue);
      await waitFor(() => host.connectedClients == 1);
      await bridge.publishCapabilities(['MOVE_FORWARD', 'EMERGENCY_STOP', 'READ_BATTERY']);
      await waitFor(() => driver.states.of('chair').declaredActions != null);
      expect(driver.states.of('chair').controllable, isTrue);

      expect((await driver.sendCommand(cmd('FLY'))).reason, 'unsupportedCommand');
      final pending = await driver.sendCommand(cmd('MOVE_FORWARD'));
      expect(pending.reason, 'confirmation_required');
      expect(driver.states.of('chair').lastCommand!.status,
          CommandStatus.awaitingConfirmation);
      expect(executed, isEmpty);

      final moved = await driver.sendCommand(cmd('MOVE_FORWARD', {'userConfirmed': true}));
      expect(moved.ok, isTrue);
      expect((await driver.sendCommand(cmd('EMERGENCY_STOP'))).ok, isTrue);
      expect(executed, ['MOVE_FORWARD', 'EMERGENCY_STOP']);

      permissions.revoke(chair, DeviceCapability.mobility);
      expect(
          (await driver.sendCommand(cmd('MOVE_FORWARD', {'userConfirmed': true}))).reason,
          'unauthorized');

      await driver.dispose();
      await bridge.dispose();
      await lan.dispose();
      await host.stop();
    });

    test('شاشة مراقبة طبية: مشاهدة فقط', () async {
      final key = LanFrameCipher.newPairingKey();
      final host = LanSyncHost(pairingKey: key);
      final port = await host.start(address: InternetAddress.loopbackIPv4);
      final lan = LanTransport(
        pairing: LanPairingBook()
          ..pair(LanEndpoint(
            deviceId: 'monitor',
            name: 'monitor',
            host: InternetAddress.loopbackIPv4.address,
            port: port,
            pairingKey: key,
          )),
      );
      final monitor = bridged('monitor', [DeviceCapability.display, DeviceCapability.readData],
          type: ConnectionType.wifi);
      final driver = ScreenDisplayDriver(
        transport: lan,
        viewOnly: true,
        explicitGrant: false,
      );
      expect((await driver.connect(monitor)).ok, isTrue);
      expect((await driver.sendCommand(cmd('show'))).reason, 'read_only_device');
      expect(driver.supports(DeviceCapability.writeData), isFalse);
      await driver.dispose();
      await lan.dispose();
      await host.stop();
    });
  });
}
