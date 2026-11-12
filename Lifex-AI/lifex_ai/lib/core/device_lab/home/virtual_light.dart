/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_light.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_light;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualLight extends LabActor {
  VirtualLight({String? id})
      : super(id: id ?? 'lab_light', kind: LabKind.light);
}
