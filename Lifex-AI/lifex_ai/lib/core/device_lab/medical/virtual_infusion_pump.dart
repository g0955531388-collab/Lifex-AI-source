/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_infusion_pump.dart
/// حالة محاكاة. ليست أوامر مضخة حقيقية.
/// =============================================================
library lifex_ai.core.device_lab.virtual_infusion_pump;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualInfusionPump extends LabActor {
  VirtualInfusionPump({String? id})
      : super(
          id: id ?? 'lab_pump',
          kind: LabKind.infusionPump,
          linkKind: 'usb',
        );
}
