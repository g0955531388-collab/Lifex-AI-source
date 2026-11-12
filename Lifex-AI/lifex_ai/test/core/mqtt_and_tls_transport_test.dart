import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_device.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/device_capability.dart';
import 'package:lifex_ai/core/connectivity/permission_manager.dart';
import 'package:lifex_ai/core/device_drivers/device_command.dart';
import 'package:lifex_ai/core/device_integration/device_integration.dart';

Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 8)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

int _n = 0;
DeviceCommand cmd(String action, [Map<String, dynamic> params = const {}]) =>
    DeviceCommand(
      id: 'm${++_n}',
      deviceId: 'lamp',
      action: action,
      timestamp: DateTime.now(),
      parameters: params,
    );

/// وسيط MQTT 3.1.1 صغير للاختبار: CONNECT/SUBSCRIBE/UNSUBSCRIBE/PUBLISH/PING.
class FakeMqttBroker {
  FakeMqttBroker({this.context});

  final SecurityContext? context;
  late int port;
  late Future<void> Function() _close;
  final _subs = <Socket, Set<String>>{};
  final published = <String, List<List<int>>>{};
  void Function(String topic, List<int> payload)? onPublish;
  int connects = 0;

  Future<int> start() async {
    final Stream<Socket> server;
    final ctx = context;
    if (ctx == null) {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = s.port;
      _close = s.close;
      server = s;
    } else {
      final s = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, ctx);
      port = s.port;
      _close = s.close;
      server = s;
    }
    server.listen(_serve, onError: (_) {});
    return port;
  }

  static List<int> _remLen(int n) {
    final out = <int>[];
    do {
      var b = n % 128;
      n ~/= 128;
      if (n > 0) b |= 0x80;
      out.add(b);
    } while (n > 0);
    return out;
  }

  void _serve(Socket s) {
    _subs[s] = {};
    final buf = <int>[];
    s.listen((data) {
      buf.addAll(data);
      while (true) {
        if (buf.length < 2) return;
        var len = 0, mult = 1, i = 1;
        while (true) {
          if (i >= buf.length) return;
          final b = buf[i++];
          len += (b & 0x7F) * mult;
          mult *= 128;
          if (b & 0x80 == 0) break;
        }
        if (buf.length < i + len) return;
        final head = buf[0];
        final body = buf.sublist(i, i + len);
        buf.removeRange(0, i + len);
        _handle(s, head, body);
      }
    }, onError: (_) {}, onDone: () => _subs.remove(s));
  }

  void _handle(Socket s, int head, List<int> body) {
    switch (head >> 4) {
      case 1:
        connects++;
        s.add([0x20, 0x02, 0x00, 0x00]);
      case 8:
        final granted = <int>[];
        var pos = 2;
        while (pos < body.length) {
          final tl = (body[pos] << 8) | body[pos + 1];
          _subs[s]?.add(utf8.decode(body.sublist(pos + 2, pos + 2 + tl)));
          granted.add(body[pos + 2 + tl] > 1 ? 1 : body[pos + 2 + tl]);
          pos += 3 + tl;
        }
        s.add([0x90, 2 + granted.length, body[0], body[1], ...granted]);
      case 10:
        s.add([0xB0, 0x02, body[0], body[1]]);
      case 3:
        final qos = (head >> 1) & 3;
        final tl = (body[0] << 8) | body[1];
        final topic = utf8.decode(body.sublist(2, 2 + tl));
        var pos = 2 + tl;
        if (qos > 0) {
          s.add([0x40, 0x02, body[pos], body[pos + 1]]);
          pos += 2;
        }
        final payload = body.sublist(pos);
        published.putIfAbsent(topic, () => []).add(payload);
        onPublish?.call(topic, payload);
      case 12:
        s.add([0xD0, 0x00]);
      case 14:
        s.destroy();
    }
  }

  /// الجهاز ينشر على موضوعه.
  void publish(String topic, List<int> payload) {
    final t = utf8.encode(topic);
    final packet = [
      0x30,
      ..._remLen(2 + t.length + payload.length),
      t.length >> 8,
      t.length & 0xFF,
      ...t,
      ...payload,
    ];
    _subs.forEach((socket, topics) {
      if (topics.contains(topic)) socket.add(packet);
    });
  }

  void publishJson(String topic, Map<String, Object?> msg) =>
      publish(topic, utf8.encode(jsonEncode(msg)));

  void dropAll() {
    for (final s in _subs.keys.toList()) {
      s.destroy();
    }
    _subs.clear();
  }

  Future<void> stop() async {
    dropAll();
    await _close();
  }
}

class TestCert {
  TestCert(this.certPath, this.keyPath, this.sha256);
  final String certPath;
  final String keyPath;
  final List<int> sha256;

  SecurityContext serverContext() => SecurityContext()
    ..useCertificateChain(certPath)
    ..usePrivateKey(keyPath);
}

/// شهادة ذاتية التوقيع مؤقتة عبر openssl؛ null إن لم يتوفر.
Future<TestCert?> makeCert() async {
  final dir = await Directory.systemTemp.createTemp('lifex_tls_');
  final cert = '${dir.path}${Platform.pathSeparator}cert.pem';
  final key = '${dir.path}${Platform.pathSeparator}key.pem';
  final der = '${dir.path}${Platform.pathSeparator}cert.der';
  for (final exe in [
    r'C:\Program Files\Git\mingw64\bin\openssl.exe',
    r'C:\Program Files\Git\usr\bin\openssl.exe',
    'openssl',
  ]) {
    try {
      final r = await Process.run(exe, [
        'req', '-x509', '-newkey', 'rsa:2048', '-nodes', //
        '-keyout', key, '-out', cert, '-days', '1',
        '-subj', '/CN=localhost', '-addext', 'subjectAltName=IP:127.0.0.1',
      ]);
      if (r.exitCode != 0) continue;
      final d = await Process.run(exe, ['x509', '-in', cert, '-outform', 'DER', '-out', der]);
      if (d.exitCode != 0) continue;
      final sha = const DartSha256().hashSync(File(der).readAsBytesSync()).bytes;
      return TestCert(cert, key, sha);
    } catch (_) {
      continue;
    }
  }
  return null;
}

ConnectionDevice lampDevice() => ConnectionDevice(
      id: 'lamp',
      name: 'lamp',
      connectionType: ConnectionType.network,
      state: ConnectionState.disconnected,
      capabilities: const [DeviceCapability.readData, DeviceCapability.writeData],
    );

MqttTopicBook lampTopics() => MqttTopicBook()
  ..add(MqttDeviceTopics(
    deviceId: 'lamp',
    name: 'lamp',
    inboundTopic: 'lifex/dev/lamp/out',
    commandTopic: 'lifex/dev/lamp/in',
  ));

/// محاكي الجهاز: يرد بتأكيد LBP على كل أمر يصل على موضوع أوامره.
void actAsLamp(FakeMqttBroker broker, List<String> executed) {
  broker.onPublish = (topic, payload) {
    if (topic != 'lifex/dev/lamp/in') return;
    final msg = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    executed.add(msg['action'] as String);
    broker.publishJson('lifex/dev/lamp/out', {'t': 'ack', 'id': msg['id'], 'ok': true});
  };
}

void main() {
  group('MQTT بلا TLS', () {
    late FakeMqttBroker broker;
    late MqttTransport transport;

    setUp(() async {
      broker = FakeMqttBroker();
      await broker.start();
      transport = MqttTransport(
        broker: MqttBrokerConfig(
          host: InternetAddress.loopbackIPv4.address,
          port: broker.port,
          clientId: 'lifex-test-${++_n}',
          tls: false,
        ),
        topics: lampTopics(),
      );
    });

    tearDown(() async {
      await transport.dispose();
      await broker.stop();
    });

    test('القراءات تصل، والتحكم مرفوض لأن القناة غير مشفّرة', () async {
      final pipeline = ReactiveDataPipeline();
      final lamp = lampDevice();
      final permissions = PermissionManager()
        ..grant(lamp, DeviceCapability.readData)
        ..grant(lamp, DeviceCapability.writeData);
      final driver = SmartHomeMedicalDriver(
        transport: transport,
        applianceClass: ApplianceClass.home,
        pipeline: pipeline,
        permissions: permissions,
      );
      expect((await driver.connect(lamp)).ok, isTrue);
      expect(transport.secureSession('lamp'), isFalse);
      broker.publishJson('lifex/dev/lamp/out', {'t': 'caps', 'actions': ['POWER_ON']});
      broker.publishJson(
          'lifex/dev/lamp/out', {'t': 'reading', 'channel': 'power_w', 'value': 7.5, 'unit': 'W'});
      await waitFor(() => pipeline.latest('lamp', 'power_w') != null);
      expect(pipeline.latest('lamp', 'power_w')!.secureLink, isFalse);
      expect((await driver.sendCommand(cmd('POWER_ON'))).reason, 'insecure_channel');
      expect(broker.published['lifex/dev/lamp/in'], isNull);
      await driver.dispose();
      await pipeline.close();
    });

    test('النقل نفسه ينشر على موضوع الأوامر', () async {
      final lamp = lampDevice();
      expect(await transport.connect(lamp), ConnectionState.connected);
      expect((await transport.send(lamp, utf8.encode('{"t":"cmd"}'))).accepted, isTrue);
      await waitFor(() => broker.published['lifex/dev/lamp/in'] != null);
      expect(utf8.decode(broker.published['lifex/dev/lamp/in']!.single), '{"t":"cmd"}');
    });

    test('انقطاع الوسيط: إعادة اتصال واشتراك تلقائيان', () async {
      final lamp = lampDevice();
      final seen = <ConnectionState>[];
      final sub = transport.stateChanges.listen((c) => seen.add(c.state));
      await transport.connect(lamp);
      broker.dropAll();
      await waitFor(() => seen.contains(ConnectionState.reconnecting));
      await waitFor(() => broker.connects == 2 && lamp.state == ConnectionState.connected);
      final got = <List<int>>[];
      final inbound = transport.inbound.listen((m) => got.add(m.bytes));
      await waitFor(() {
        broker.publish('lifex/dev/lamp/out', [0x7B, 0x7D]);
        return got.isNotEmpty;
      });
      await inbound.cancel();
      await sub.cancel();
    });

    test('جهاز غير مسجّل أو وسيط غير موجود: خطأ', () async {
      final ghost = ConnectionDevice(
        id: 'ghost',
        name: 'ghost',
        connectionType: ConnectionType.network,
        state: ConnectionState.disconnected,
      );
      expect(await transport.connect(ghost), ConnectionState.error);
      await broker.stop();
      final offline = MqttTransport(
        broker: MqttBrokerConfig(
          host: InternetAddress.loopbackIPv4.address,
          port: broker.port,
          clientId: 'lifex-offline',
          tls: false,
          connectTimeout: const Duration(seconds: 1),
        ),
        topics: lampTopics(),
      );
      expect(await offline.connect(lampDevice()), ConnectionState.error);
      await offline.dispose();
      broker = FakeMqttBroker();
      await broker.start();
    });
  });

  group('TLS بشهادة ذاتية التوقيع معروفة البصمة', () {
    TestCert? cert;

    setUpAll(() async {
      cert = await makeCert();
    });

    test('MQTT عبر TLS: قناة آمنة، والتحكم يصل ويؤكّده الجهاز', () async {
      final c = cert;
      if (c == null) {
        markTestSkipped('openssl غير متوفر لإنشاء شهادة اختبار');
        return;
      }
      final broker = FakeMqttBroker(context: c.serverContext());
      await broker.start();
      final executed = <String>[];
      actAsLamp(broker, executed);
      final transport = MqttTransport(
        broker: MqttBrokerConfig(
          host: InternetAddress.loopbackIPv4.address,
          port: broker.port,
          clientId: 'lifex-tls',
          trustedSelfSignedSha256: c.sha256,
        ),
        topics: lampTopics(),
      );
      final lamp = lampDevice();
      final permissions = PermissionManager()
        ..grant(lamp, DeviceCapability.readData)
        ..grant(lamp, DeviceCapability.writeData);
      final driver = SmartHomeMedicalDriver(
        transport: transport,
        applianceClass: ApplianceClass.home,
        permissions: permissions,
      );
      expect((await driver.connect(lamp)).ok, isTrue);
      expect(transport.secureSession('lamp'), isTrue);
      broker.publishJson(
          'lifex/dev/lamp/out', {'t': 'caps', 'actions': ['POWER_ON', 'UNLOCK_DOOR']});
      await waitFor(() => driver.states.of('lamp').declaredActions != null);
      expect(driver.states.of('lamp').controllable, isTrue);

      final on = await driver.sendCommand(cmd('POWER_ON'));
      expect(on.ok, isTrue);
      expect(on.reason, 'peer_ack');
      expect((await driver.sendCommand(cmd('UNLOCK_DOOR'))).reason, 'confirmation_required');
      expect(executed, ['POWER_ON']);

      await driver.dispose();
      await transport.dispose();
      await broker.stop();
    });

    test('MQTT عبر TLS ببصمة خاطئة: لا اتصال', () async {
      final c = cert;
      if (c == null) {
        markTestSkipped('openssl غير متوفر لإنشاء شهادة اختبار');
        return;
      }
      final broker = FakeMqttBroker(context: c.serverContext());
      await broker.start();
      final transport = MqttTransport(
        broker: MqttBrokerConfig(
          host: InternetAddress.loopbackIPv4.address,
          port: broker.port,
          clientId: 'lifex-tls-bad',
          trustedSelfSignedSha256: List<int>.filled(32, 1),
          connectTimeout: const Duration(seconds: 2),
        ),
        topics: lampTopics(),
      );
      expect(await transport.connect(lampDevice()), ConnectionState.error);
      expect(broker.connects, 0);
      await transport.dispose();
      await broker.stop();
    });

    test('جسر TCP عبر TLS: البصمة الصحيحة آمنة، والخاطئة مرفوضة', () async {
      final c = cert;
      if (c == null) {
        markTestSkipped('openssl غير متوفر لإنشاء شهادة اختبار');
        return;
      }
      final server = await SecureServerSocket.bind(
          InternetAddress.loopbackIPv4, 0, c.serverContext());
      final peers = <Socket>[];
      server.listen(peers.add, onError: (_) {});
      BridgeTcpTransport bridgeWith(List<int> pin) => BridgeTcpTransport(
            endpoints: BridgeEndpointBook()
              ..add(BridgeEndpoint(
                deviceId: 'gps1',
                name: 'gps1',
                host: InternetAddress.loopbackIPv4.address,
                port: server.port,
                tls: true,
                pinnedCertificateSha256: pin,
              )),
          );
      final gps = ConnectionDevice(
        id: 'gps1',
        name: 'gps1',
        connectionType: ConnectionType.network,
        state: ConnectionState.disconnected,
      );
      final good = bridgeWith(c.sha256);
      expect(await good.connect(gps), ConnectionState.connected);
      expect(good.secureSession('gps1'), isTrue);
      await good.dispose();

      final bad = bridgeWith(List<int>.filled(32, 9));
      expect(await bad.connect(gps), ConnectionState.error);
      expect(bad.secureSession('gps1'), isFalse);
      await bad.dispose();
      for (final p in peers) {
        p.destroy();
      }
      await server.close();
    });
  });
}
