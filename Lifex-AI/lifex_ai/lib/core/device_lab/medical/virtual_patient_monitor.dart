/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_patient_monitor.dart
/// قراءات محاكاة. ليست حالة مريض.
/// =============================================================
library lifex_ai.core.device_lab.virtual_patient_monitor;

import '../base/virtual_device.dart';
import '../lab_kind.dart';

class VirtualPatientMonitor extends LabActor {
  VirtualPatientMonitor({String? id})
      : super(
          id: id ?? 'lab_monitor',
          kind: LabKind.patientMonitor,
          linkKind: 'wifi',
        );
}

class VirtualEcgDevice extends LabActor {
  VirtualEcgDevice({String? id})
      : super(id: id ?? 'lab_ecg', kind: LabKind.ecg, linkKind: 'ble');

  bool streaming = false;

  Future<void> startStreaming() async {
    streaming = true;
    emitPeer('ecg_stream', {'simulated': true, 'streaming': true});
  }

  Future<void> stopStreaming() async {
    streaming = false;
    emitPeer('ecg_stream', {'simulated': true, 'streaming': false});
  }
}
