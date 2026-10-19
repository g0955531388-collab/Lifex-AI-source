import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_lab/control_stage.dart';
import 'package:lifex_ai/core/device_lab/device_lab.dart';
import 'package:lifex_ai/core/device_lab/lab_command.dart';
import 'package:lifex_ai/core/device_lab/medical/virtual_infusion_pump.dart';
import 'package:lifex_ai/core/device_lab/medical/virtual_patient_monitor.dart';

void main() {
  test('الحزمة 43 مختبر فئات لا كتالوج السوق', () {
    final pack = jsonDecode(
      File(
        'lib/data/encyclopedia/lifex_universal_virtual_device_lab_v1.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(pack['pack'], 43);
    expect(pack['not_every_device_in_the_world'], isTrue);
    expect(pack['identified_is_not_connected'], isTrue);
    expect(DeviceLab.notAMarketCatalog, isTrue);
  });

  test('التعرف ثم الاتصال ثم الإذن ثم التحكم', () async {
    final lab = DeviceLab();
    final tv = lab.spawn('tv', id: 'tv1');
    await tv.initialize();
    expect(tv.stage, DeviceControlStage.identified);
    final early = await tv.execute(
      LabCommand(
        id: 'v',
        deviceId: tv.id,
        action: 'setVolume',
        timestamp: DateTime.now(),
        parameters: {'value': 35},
      ),
    );
    expect(early.reason, 'not_controllable');
    await tv.connect();
    expect(tv.stage, DeviceControlStage.connected);
    await tv.execute(
      LabCommand(
        id: 'a',
        deviceId: tv.id,
        action: 'authorize',
        timestamp: DateTime.now(),
      ),
    );
    expect(tv.stage, DeviceControlStage.authorized);
    await tv.execute(
      LabCommand(
        id: 'g',
        deviceId: tv.id,
        action: 'grantControl',
        timestamp: DateTime.now(),
      ),
    );
    expect(tv.stage, DeviceControlStage.controllable);
    final vol = await tv.execute(
      LabCommand(
        id: 'v2',
        deviceId: tv.id,
        action: 'setVolume',
        timestamp: DateTime.now(),
        parameters: {'value': 35},
      ),
    );
    expect(vol.ok, isTrue);
    expect(vol.executedOnHardware, isFalse);
    expect(tv.snapshot.values['volume'], 35);
  });

  test('المضخة الافتراضية لا تشغّل مضخة حقيقية', () async {
    final pump = VirtualInfusionPump(id: 'p1');
    await pump.initialize();
    await pump.connect();
    await pump.authorize();
    await pump.grantControl();
    final start = await pump.execute(
      LabCommand(
        id: 's',
        deviceId: pump.id,
        action: 'startInfusion',
        timestamp: DateTime.now(),
      ),
    );
    expect(start.ok, isFalse);
    expect(start.reason, 'real_actuator_forbidden');
    final flow = await pump.execute(
      LabCommand(
        id: 'f',
        deviceId: pump.id,
        action: 'simulateFlow',
        timestamp: DateTime.now(),
        parameters: {'flow': 10},
      ),
    );
    expect(flow.ok, isTrue);
    expect(pump.snapshot.values['simulated'], isTrue);
  });

  test('المراقب يبث قيماً محاكاة بلا تفسير سريري', () async {
    final mon = VirtualPatientMonitor(id: 'm1');
    await mon.initialize();
    await mon.connect();
    final r = await mon.execute(
      LabCommand(
        id: 'i',
        deviceId: mon.id,
        action: 'injectSimulatedVital',
        timestamp: DateTime.now(),
        parameters: {'key': 'hr', 'value': 72},
      ),
    );
    expect(r.ok, isTrue);
    expect(mon.snapshot.values['simulated'], isTrue);
    expect(mon.snapshot.values['hr'], 72);
    final ecg = VirtualEcgDevice(id: 'e1');
    await ecg.initialize();
    await ecg.startStreaming();
    expect(ecg.streaming, isTrue);
  });

  test('فقدان الحزم وانقطاع الساعة ثم استعادة الجلسة', () async {
    final lab = DeviceLab();
    final watch = lab.spawn('watch', id: 'w1');
    await watch.initialize();
    await watch.connect();
    await lab.failures.dropPackets('w1');
    final lost = await watch.execute(
      LabCommand(
        id: 'r',
        deviceId: watch.id,
        action: 'readState',
        timestamp: DateTime.now(),
      ),
    );
    expect(lost.reason, 'link_down');
    await lab.failures.clear('w1');
    await lab.failures.disconnectDevice('w1');
    expect(watch.snapshot.connected, isFalse);
    await lab.failures.clear('w1');
    await watch.connect();
    final ok = await watch.execute(
      LabCommand(
        id: 'r2',
        deviceId: watch.id,
        action: 'readState',
        timestamp: DateTime.now(),
      ),
    );
    expect(ok.ok, isTrue);
  });

  test('مدينة المختبر أنواع محاكاة والنوع المجهول Generic', () async {
    final lab = DeviceLab();
    await lab.spawnCity();
    expect(lab.deviceCount, 25);
    final unknown = lab.spawn('samsung_unobtainium');
    expect(unknown.category, 'generic');
  });
}
