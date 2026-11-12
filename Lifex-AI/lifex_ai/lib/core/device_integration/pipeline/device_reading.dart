/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: device_reading.dart
/// قراءة جهاز = ملاحظة. ليست تفسيراً ولا تشخيصاً.
/// =============================================================
library lifex_ai.core.device_integration.pipeline.device_reading;

enum ReadingKind { measurement, position, telemetry, status, displayState }

class DeviceReading {
  const DeviceReading({
    required this.deviceId,
    required this.channel,
    required this.value,
    required this.timestamp,
    this.unit = '',
    this.kind = ReadingKind.measurement,
    this.protocol = '',
    this.secureLink = false,
  });

  final String deviceId;
  final String channel;

  /// رقم، نص، أو خريطة قيم كما وصلت من الجهاز.
  final Object value;
  final DateTime timestamp;
  final String unit;
  final ReadingKind kind;
  final String protocol;

  /// هل وصلت عبر قناة مشفّرة ومصادَقة.
  final bool secureLink;

  bool get clinicalInterpretation => false;
}
