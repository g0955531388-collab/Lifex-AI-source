/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_phone.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_phone;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualPhone extends LabActor {
  VirtualPhone({String? id})
      : super(id: id ?? 'lab_phone', kind: LabKind.phone);
}
