/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_tv.dart
/// =============================================================
library lifex_ai.core.device_lab.virtual_tv;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualTv extends LabActor {
  VirtualTv({String? id})
      : super(id: id ?? 'lab_tv', kind: LabKind.tv, linkKind: 'wifi');
}
