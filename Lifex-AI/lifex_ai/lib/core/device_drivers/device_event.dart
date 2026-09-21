/// =============================================================
/// Lifex-AI — سواقات
/// الملف: device_event.dart
/// حدث من الجهاز. ليس تشخيصاً.
/// =============================================================
library lifex_ai.core.device_drivers.device_event;

class DeviceEvent {
  const DeviceEvent({
    required this.deviceId,
    required this.kind,
    required this.timestamp,
    this.payload = const {},
    this.clinicalInterpretation = false,
  });

  final String deviceId;
  final String kind;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final bool clinicalInterpretation;
}
