/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_device_session.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_device_session;

import 'base/virtual_device.dart';
import 'control_stage.dart';

class VirtualDeviceSession {
  VirtualDeviceSession(this.device);

  final VirtualDevice device;
  DateTime? openedAt;
  int reconnects = 0;

  bool get open =>
      device.snapshot.stage.index >= DeviceControlStage.connected.index &&
      device.snapshot.connected;

  Future<void> openSession() async {
    await device.connect();
    openedAt = DateTime.now();
  }

  Future<void> closeSession() async {
    await device.disconnect();
    openedAt = null;
  }
}
