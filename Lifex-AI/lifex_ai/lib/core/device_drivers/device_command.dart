/// =============================================================
/// Lifex-AI — سواقات
/// الملف: device_command.dart
/// أمر. القبول ليس نجاح تشغيل العتاد الحقيقي.
/// =============================================================
library lifex_ai.core.device_drivers.device_command;

class DeviceCommand {
  const DeviceCommand({
    required this.id,
    required this.deviceId,
    required this.action,
    required this.timestamp,
    this.parameters = const {},
  });

  final String id;
  final String deviceId;
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;
}
