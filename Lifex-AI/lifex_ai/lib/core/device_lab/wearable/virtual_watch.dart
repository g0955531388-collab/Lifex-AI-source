/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_watch.dart
/// بيانات الساعة محاكاة للاختبار فقط.
/// =============================================================
library lifex_ai.core.device_lab.virtual_watch;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualWatch extends LabActor {
  VirtualWatch({String? id})
      : super(id: id ?? 'lab_watch', kind: LabKind.watch, linkKind: 'ble');
}
