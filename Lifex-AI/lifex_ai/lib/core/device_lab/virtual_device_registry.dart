/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_device_registry.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_device_registry;

import 'base/virtual_device.dart';

class VirtualDeviceRegistry {
  final devices = <String, VirtualDevice>{};

  void register(VirtualDevice device) {
    devices[device.id] = device;
  }

  VirtualDevice? find(String id) => devices[id];

  List<VirtualDevice> all() => devices.values.toList();
}
