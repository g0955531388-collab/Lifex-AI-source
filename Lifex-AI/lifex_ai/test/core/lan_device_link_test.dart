import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_device.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/connectivity_manager.dart';
import 'package:lifex_ai/core/connectivity/lan/lan_secure_channel.dart';
import 'package:lifex_ai/core/connectivity/lan/lan_transport.dart';
import 'package:lifex_ai/core/device_drivers/device_command.dart';
import 'package:lifex_ai/core/device_drivers/local_screen_sync_driver.dart';

ConnectionDevice screen(String id) => ConnectionDevice(
      id: id,
      name: 'شاشة الصالة',
      connectionType: ConnectionType.wifi,
      state: ConnectionState.disconnected,
    );

DeviceCommand command(String action, [Map<String, dynamic> params = const {}]) =>
    DeviceCommand(
      id: 'cmd-${DateTime.now().microsecondsSinceEpoch}',
      deviceId: 'tv',
      action: action,
      timestamp: DateTime.now(),
      parameters: params,
    );

Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('تشفير الإطار', () {
    final key = LanFrameCipher.newPairingKey();
    final cipher = LanFrameCipher(key);
    final tag = List<int>.filled(32, 7);

    test('ذهاب وإياب سليم', () async {
      final frame = await cipher.seal(
          direction: 0, seq: 3, sessionTag: tag, payload: [1, 2, 3]);
      final opened =
          await cipher.open(frame: frame, expectDirection: 0, sessionTag: tag);
      expect(opened.seq, 3);
      expect(opened.payload, [1, 2, 3]);
    });

    test('مفتاح آخر، أو عبث، أو جلسة أخرى، أو اتجاه معكوس: رفض', () async {
      final frame = await cipher.seal(
          direction: 0, seq: 1, sessionTag: tag, payload: [9, 9]);
      Future<void> rejects(Future<Object?> attempt) =>
          expectLater(attempt, throwsA(isA<LanFrameRejected>()));

      await rejects(LanFrameCipher(LanFrameCipher.newPairingKey())
          .open(frame: frame, expectDirection: 0, sessionTag: tag));
      final tampered = List<int>.of(frame)..[frame.length - 20] ^= 1;
      await rejects(
          cipher.open(frame: tampered, expectDirection: 0, sessionTag: tag));
      final reSeq = List<int>.of(frame)..[9] ^= 1;
      await rejects(
          cipher.open(frame: reSeq, expectDirection: 0, sessionTag: tag));
      await rejects(cipher.open(
          frame: frame, expectDirection: 0, sessionTag: List<int>.filled(32, 8)));
      await rejects(cipher.open(frame: frame, expectDirection: 1, sessionTag: tag));
    });
  });

  group('هاتف ↔ شاشة على الشبكة المحلية', () {
    late List<int> key;
    late LanSyncHost host;
    late int port;
    late LanTransport transport;
    final handled = <String>[];

    setUp(() async {
      handled.clear();
      key = LanFrameCipher.newPairingKey();
      host = LanSyncHost(pairingKey: key);
      port = await host.start(address: InternetAddress.loopbackIPv4);
      transport = LanTransport(
        pairing: LanPairingBook()
          ..pair(LanEndpoint(
            deviceId: 'tv',
            name: 'شاشة الصالة',
            host: InternetAddress.loopbackIPv4.address,
            port: port,
            pairingKey: key,
          )),
        baseBackoff: const Duration(milliseconds: 50),
        maxBackoff: const Duration(milliseconds: 200),
      );
    });

    tearDown(() async {
      await transport.dispose();
      await host.stop();
    });

    test('الاتصال يمر عبر ConnectivityManager ويُعدّ مشفّراً مصادقاً', () async {
      final manager = ConnectivityManager(
        transports: {ConnectionType.wifi: transport},
      );
      final tv = screen('tv');
      expect(await manager.connect(tv), ConnectionState.connected);
      expect(manager.transportBound(ConnectionType.wifi), isTrue);
      expect(manager.transportBound(ConnectionType.ble), isFalse);
      expect(transport.authenticatedSession('tv'), isTrue);
      await waitFor(() => host.connectedClients == 1);
    });

    test('أمر يُنفّذ على الشاشة ويعود بتأكيد، والحالة والأحداث تصل', () async {
      final responder = LocalScreenSyncResponder(
        host: host,
        handler: (action, params) async {
          handled.add(action);
          return action == 'show_clock' ? null : 'unsupported';
        },
      );
      final driver = LocalScreenSyncDriver(transport: transport);
      final tv = screen('tv');
      expect((await driver.connect(tv)).ok, isTrue);
      await waitFor(() => host.connectedClients == 1);

      final done = await driver.sendCommand(command('show_clock'));
      expect(done.ok, isTrue);
      expect(done.reason, 'peer_ack');
      final refused = await driver.sendCommand(command('format_disk'));
      expect(refused.ok, isFalse);
      expect(refused.reason, 'unsupported');
      expect(handled, ['show_clock', 'format_disk']);

      final event = driver.events.first;
      await responder.publishState({'screen': 'clock'});
      await responder.publishEvent('touched', {'x': 1});
      expect((await event.timeout(const Duration(seconds: 3))).kind, 'touched');
      expect((await driver.readState()).values['screen'], 'clock');
      await responder.dispose();
      await driver.dispose();
    });

    test('بيانات صحية بلا مرجع موافقة لا تغادر الهاتف', () async {
      LocalScreenSyncResponder(
        host: host,
        handler: (action, params) async {
          handled.add(action);
          return null;
        },
      );
      final driver = LocalScreenSyncDriver(transport: transport);
      await driver.connect(screen('tv'));
      final blocked = await driver.sendCommand(
          command('show_report', {'containsHealthData': true}));
      expect(blocked.ok, isFalse);
      expect(blocked.reason, 'health_data_without_consent');
      final allowed = await driver.sendCommand(command(
          'show_report', {'containsHealthData': true, 'consentRef': 'CONS-1'}));
      expect(allowed.ok, isTrue);
      expect(handled, ['show_report']);
      await driver.dispose();
    });

    test('مفتاح اقتران خاطئ: لا اتصال، والمضيف يرفض المصافحة', () async {
      final intruder = LanTransport(
        pairing: LanPairingBook()
          ..pair(LanEndpoint(
            deviceId: 'tv',
            name: 'x',
            host: InternetAddress.loopbackIPv4.address,
            port: port,
            pairingKey: LanFrameCipher.newPairingKey(),
          )),
        handshakeTimeout: const Duration(seconds: 2),
      );
      expect(await intruder.connect(screen('tv')), ConnectionState.error);
      await waitFor(() => host.rejectedHandshakes == 1);
      expect(host.connectedClients, 0);
      await intruder.dispose();
    });

    test('جهاز غير مقترن لا يتصل', () async {
      expect(await transport.connect(screen('unknown')), ConnectionState.error);
    });

    test('انقطاع المضيف ثم عودته: إعادة اتصال تلقائية', () async {
      final tv = screen('tv');
      final states = <ConnectionState>[];
      final sub = transport.stateChanges.listen((s) => states.add(s.state));
      expect(await transport.connect(tv), ConnectionState.connected);
      await host.stop();
      await waitFor(() => states.contains(ConnectionState.reconnecting));
      host = LanSyncHost(pairingKey: key);
      await host.start(address: InternetAddress.loopbackIPv4, port: port);
      await waitFor(() => transport.authenticatedSession('tv'),
          timeout: const Duration(seconds: 8));
      expect(tv.state, ConnectionState.connected);
      await sub.cancel();
    });

    test('قطع الاتصال يدوياً يوقف إعادة المحاولة', () async {
      final tv = screen('tv');
      await transport.connect(tv);
      await transport.disconnect(tv);
      await host.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(tv.state, ConnectionState.disconnected);
      expect(transport.authenticatedSession('tv'), isFalse);
    });
  });
}
