/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: device_lab.dart
/// مدينة محاكاة. ليست شبكة أجهزة حقيقية.
/// =============================================================
library lifex_ai.core.device_lab.device_lab;

import 'base/virtual_device.dart';
import 'lab_command.dart';
import 'lab_kind.dart';
import 'simulation/connection_simulator.dart';
import 'virtual_device_factory.dart';
import 'virtual_device_registry.dart';
import 'virtual_device_session.dart';

class DeviceLab {
  DeviceLab({
    VirtualDeviceFactory? factory,
    VirtualDeviceRegistry? registry,
  })  : factory = factory ?? VirtualDeviceFactory(),
        registry = registry ?? VirtualDeviceRegistry();

  final VirtualDeviceFactory factory;
  final VirtualDeviceRegistry registry;
  final sessions = <String, VirtualDeviceSession>{};
  final failures = FailureSimulator({});

  void _refreshFailures() {
    for (final d in registry.all().whereType<LabActor>()) {
      failures.links[d.id] = d.link;
    }
  }

  LabActor spawn(String type, {String? id}) {
    final device = factory.create(type, id: id);
    registry.register(device);
    sessions[device.id] = VirtualDeviceSession(device);
    _refreshFailures();
    return device;
  }

  /// بيئة اختبار متعددة الفئات — ليست العالم الحقيقي.
  Future<void> spawnCity() async {
    const kinds = [
      'phone',
      'tablet',
      'laptop',
      'desktop',
      'tv',
      'watch',
      'earbuds',
      'light',
      'lock',
      'ac',
      'homeCamera',
      'car',
      'infotainment',
      'patientMonitor',
      'ecg',
      'spo2',
      'infusionPump',
      'analyzer',
      'barcodeScanner',
      'plc',
      'motor',
      'weatherStation',
      'brailleDisplay',
      'securityCamera',
      'router',
    ];
    for (final k in kinds) {
      final d = spawn(k);
      await d.initialize();
    }
  }

  Future<void> startAll() async {
    for (final d in registry.all()) {
      await d.initialize();
      await d.connect();
    }
  }

  Future<void> stopAll() async {
    for (final d in registry.all()) {
      await d.disconnect();
    }
  }

  Future<void> resetAll() async {
    for (final d in registry.all()) {
      await d.reset();
    }
  }

  Future<List<LabDeviceState>> readAllStates() async {
    return registry.all().map((d) => d.snapshot).toList();
  }

  Future<List<LabResponse>> broadcast(LabCommand command) async {
    final out = <LabResponse>[];
    for (final d in registry.all()) {
      out.add(
        await d.execute(
          LabCommand(
            id: command.id,
            deviceId: d.id,
            action: command.action,
            timestamp: command.timestamp,
            parameters: command.parameters,
          ),
        ),
      );
    }
    return out;
  }

  int get deviceCount => registry.devices.length;

  static bool get notAMarketCatalog => true;
}
