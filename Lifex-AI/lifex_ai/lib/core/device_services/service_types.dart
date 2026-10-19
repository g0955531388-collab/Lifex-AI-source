/// =============================================================
/// Lifex-AI — سجل خدمات
/// الملف: service_types.dart
/// الخدمة وظيفة معلَنة. ليست إذناً ولا حكماً طبياً.
/// =============================================================
library lifex_ai.core.device_services.service_types;

enum ServiceCategory {
  communication,
  display,
  audio,
  camera,
  sensor,
  medical,
  laboratory,
  navigation,
  location,
  storage,
  printing,
  input,
  output,
  security,
  emergency,
  vehicle,
  homeAutomation,
  industrial,
  accessibility,
  system,
  network,
  unknown,
}

enum ServiceStatus {
  unknown,
  discovering,
  available,
  degraded,
  busy,
  unavailable,
  unauthorized,
  disconnected,
  error,
}

enum EndpointType {
  state,
  command,
  event,
  data,
  stream,
  configuration,
  diagnostic,
}

enum DataQuality {
  unknown,
  unavailable,
  poor,
  fair,
  good,
  excellent,
}

enum AccessScope {
  discover,
  read,
  subscribe,
  stream,
  configure,
  execute,
  control,
  administer,
}

enum HeartbeatHealth {
  unknown,
  healthy,
  degraded,
  lost,
}

/// أسماء محلية → مفهوم موحّد. الاسم الأصلي يُحفظ في السجل.
const kCapabilityAliases = <String, String>{
  'pulse': 'HEART_RATE',
  'heart_rate': 'HEART_RATE',
  'hr': 'HEART_RATE',
  'heartrate': 'HEART_RATE',
  'spo2': 'OXYGEN_SATURATION',
  'oxygensaturation': 'OXYGEN_SATURATION',
  'oxygen_saturation': 'OXYGEN_SATURATION',
  'ecg': 'ECG',
  'camera': 'CAMERA',
  'display': 'DISPLAY',
  'microphone': 'MICROPHONE',
  'speaker': 'SPEAKER',
  'location': 'LOCATION',
  'printer': 'PRINTER',
  'alarm': 'ALARM',
};

String canonicalizeCapability(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(' ', '');
  return kCapabilityAliases[key] ?? raw.trim().toUpperCase();
}
