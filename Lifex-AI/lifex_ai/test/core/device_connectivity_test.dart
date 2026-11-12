import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_device.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/device_capability.dart';
import 'package:lifex_ai/core/connectivity/transport.dart';
import 'package:lifex_ai/core/connectivity/connection_session.dart';
import 'package:lifex_ai/core/connectivity/protocol/device_protocol.dart';
import 'package:lifex_ai/core/connectivity/wired/serial_connection.dart';
import 'package:lifex_ai/core/connectivity/wired/usb_connection.dart';
import 'package:lifex_ai/core/connectivity/wireless/ble/ble_manager.dart';
import 'package:lifex_ai/core/connectivity/wireless/nfc/nfc_manager.dart';
import 'package:lifex_ai/core/connectivity/wireless/wifi/wifi_manager.dart';
import 'package:lifex_ai/core/connectivity/message_packet.dart';
import 'package:lifex_ai/core/device_drivers/device_command.dart';
import 'package:lifex_ai/core/device_drivers/lifex_device_hub.dart';
import 'package:lifex_ai/core/device_drivers/virtual_device.dart';

void main() {
  test('الحزمة 41 النقل غير المربوط لا يتصل', () async {
    final pack = jsonDecode(
      File('lib/data/encyclopedia/lifex_device_connectivity_v1.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(pack['pack'], 41);
    expect(pack['unbound_transport_is_not_connected'], isTrue);

    final usb = UnboundTransport(ConnectionType.usb);
    expect(usb.hardwareBound, isFalse);
    expect(await usb.scan(), isEmpty);
    final phantom = ConnectionDevice(
      id: 'usb_x',
      name: 'كاميرا USB',
      connectionType: ConnectionType.usb,
      state: ConnectionState.disconnected,
    );
    expect(await usb.connect(phantom), ConnectionState.unbound);
    final sent = await usb.send(phantom, [1, 2, 3]);
    expect(sent.accepted, isFalse);
  });

  test('الحزمة 42 قوالب وليست سواقات كل شركات العالم', () {
    final pack = jsonDecode(
      File('lib/data/encyclopedia/lifex_universal_virtual_drivers_v1.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(pack['pack'], 42);
    expect(pack['no_samsung_apple_sony_hardcoded_drivers'], isTrue);
    expect(pack['simulator_is_not_market_catalog'], isTrue);
  });

  test('التلفزيون الوهمي ثنائي الاتجاه بعد الإذن فقط', () async {
    final hub = LifexDeviceHub();
    final found = await hub.discover();
    final tv = found.firstWhere((d) => d.id == 'sim_tv_001');
    expect(tv.virtual, isTrue);
    expect(tv.manufacturer, 'Lifex Simulator');

    final linked = await hub.connect(tv);
    expect(linked.ok, isTrue);

    final denied = await hub.showOnDisplay(tv, 'مرحبا');
    expect(denied.ok, isFalse);
    expect(denied.reason, 'permission_denied');

    hub.permissions.grant(tv, DeviceCapability.display);
    hub.permissions.grant(tv, DeviceCapability.volume);
    hub.permissions.grant(tv, DeviceCapability.powerOn);

    final shown = await hub.showOnDisplay(tv, 'مرحبا');
    expect(shown.ok, isTrue);
    expect(shown.executedOnHardware, isFalse);

    final driver = hub.registry.findDriver(tv)! as VirtualDevice;
    expect(driver.displayLog, contains('مرحبا'));

    final powered = await hub.command(
      tv,
      DeviceCommand(
        id: 'p1',
        deviceId: tv.id,
        action: 'powerOn',
        timestamp: DateTime.now(),
      ),
    );
    expect(powered.ok, isTrue);
    expect((await driver.readState()).powered, isTrue);

    final events = <String>[];
    final sub = driver.events.listen((e) => events.add(e.kind));
    driver.requestFromPeer('show_on_phone', {'text': 'حالة التلفزيون'});
    await Future<void>.delayed(Duration.zero);
    expect(events, contains('peer_request'));
    await sub.cancel();
  });

  test('جهاز غير معروف لا يُسمّى ماركة ولا ينفّذ أوامر', () async {
    final hub = LifexDeviceHub();
    final unknown =
        (await hub.discover()).firstWhere((d) => d.id == 'sim_unknown_001');
    await hub.connect(unknown);
    final r = await hub.command(
      unknown,
      DeviceCommand(
        id: 'x',
        deviceId: unknown.id,
        action: 'powerOn',
        timestamp: DateTime.now(),
      ),
    );
    expect(r.ok, isFalse);
    expect(r.reason, 'unsupported_action');
    expect(unknown.name, contains('غير معروف'));
  });

  test('الساعة لا تتحكم بكاميرا الهاتف والقياس المحاكى ليس تشخيصاً', () async {
    final hub = LifexDeviceHub();
    final watch =
        (await hub.discover()).firstWhere((d) => d.id == 'sim_watch_001');
    expect(hub.permissions.watchMayControlPhoneCamera(watch), isFalse);
    await hub.connect(watch);
    final med = hub.registry.findDriver(
      (await hub.discover()).firstWhere((d) => d.id == 'sim_med_001'),
    )! as VirtualDevice;
    await med.connect(med.connection);
    med.injectSimulatedMeasurement('temperature', 36.7);
    final state = await med.readState();
    expect(state.values['simulated'], isTrue);
    final live = await med.sendCommand(
      DeviceCommand(
        id: 'm',
        deviceId: med.deviceId,
        action: 'readMeasurement',
        timestamp: DateTime.now(),
      ),
    );
    expect(live.ok, isFalse);
    expect(live.reason, 'no_live_sensor');
  });

  test('USB وBLE وWi-Fi غير مربوطة لا تكتشف كتالوج مصانع', () async {
    final usb = UnboundUsbConnection();
    final phantom = ConnectionDevice(
      id: 'cam',
      name: 'USB Camera',
      connectionType: ConnectionType.usb,
      state: ConnectionState.disconnected,
    );
    expect(await usb.connect(phantom), ConnectionState.unbound);
    expect(usb.isConnected, isFalse);
    expect((await usb.send([1])).accepted, isFalse);

    final serial = UnboundSerialConnection();
    expect(
      await serial.connect(phantom, baudRate: 4800),
      ConnectionState.error,
    );

    final ble = BleManager();
    expect(await ble.scan(), isEmpty);
    expect((await ble.subscribe(const BleCharacteristic(uuid: 'x'))).accepted,
        isFalse);

    final wifi = UnboundWifiConnection();
    expect(await wifi.connect('hospital.local', 443), ConnectionState.unbound);

    const nfc = NfcManager();
    expect(await nfc.readTag(), isNull);
    expect(await nfc.bootstrapPairing(), ConnectionState.unbound);
  });

  test('قياس وارد ليس تشخيصاً وإعادة الاتصال محدودة', () {
    const proto = DeviceProtocol();
    final packet = proto.decoder.decode(
      proto.encoder.encode(
        MessagePacket(
          messageId: 'm1',
          deviceId: 'sensor_001',
          command: 'measurement',
          timestamp: DateTime.utc(2026, 9, 17),
          payload: const {'type': 'temperature', 'value': 36.7, 'unit': 'C'},
        ),
      ),
    )!;
    final health = proto.decoder.toHealthData(packet);
    expect(health.ok, isTrue);
    expect(health.clinicalInterpretation, isFalse);

    final session = ConnectionSession(
      ConnectionDevice(
        id: 'd',
        name: 'x',
        connectionType: ConnectionType.ble,
        state: ConnectionState.disconnected,
      ),
      maxReconnects: 1,
    );
    expect(session.canReconnect(), isTrue);
  });
}
