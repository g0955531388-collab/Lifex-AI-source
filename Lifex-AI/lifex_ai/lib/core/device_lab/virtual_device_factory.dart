/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_device_factory.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_device_factory;

import 'base/virtual_device.dart';
import 'lab_kind.dart';

class VirtualDeviceFactory {
  int _n = 0;

  LabActor create(String type, {String? id}) {
    final kind = _parse(type);
    _n += 1;
    return LabActor(
      id: id ?? 'lab_${kind.name}_$_n',
      kind: kind,
      linkKind: _linkFor(kind),
    );
  }

  static LabKind _parse(String type) {
    switch (type) {
      case 'medical_monitor':
        return LabKind.patientMonitor;
      case 'smart_tv':
        return LabKind.tv;
      default:
        return LabKind.values.firstWhere(
          (k) => k.name == type || k.category == type,
          orElse: () => LabKind.generic,
        );
    }
  }

  static String _linkFor(LabKind kind) {
    switch (kind) {
      case LabKind.watch:
      case LabKind.earbuds:
      case LabKind.ecg:
      case LabKind.spo2:
        return 'ble';
      case LabKind.tv:
      case LabKind.router:
      case LabKind.patientMonitor:
        return 'wifi';
      case LabKind.plc:
      case LabKind.analyzer:
        return 'ethernet';
      default:
        return 'virtual';
    }
  }
}
