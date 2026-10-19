/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_vehicle.dart
/// محاكاة معلومات. ليست قيادة مركبة.
/// =============================================================
library lifex_ai.core.device_lab.virtual_vehicle;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualVehicle extends LabActor {
  VirtualVehicle({String? id})
      : super(id: id ?? 'lab_vehicle', kind: LabKind.vehicle);
}
