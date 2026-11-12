/// =============================================================
/// Lifex-AI — اتصال
/// الملف: device_capability.dart
/// قدرة معلَنة. ليست إذناً تلقائياً ولا تشخيصاً.
/// =============================================================
library lifex_ai.core.connectivity.device_capability;

enum DeviceCapability {
  readData,
  writeData,
  streamData,
  camera,
  microphone,
  speaker,
  display,
  touch,
  keyboard,
  mouse,
  volume,
  mediaControl,
  powerOn,
  powerOff,
  restart,
  fileTransfer,
  screenShare,
  remoteInput,
  location,
  printing,
  storage,
  vitalSigns,
  temperature,
  bloodPressure,
  oxygenSaturation,
  glucose,
  ecg,
  infusionMonitoring,
  emergencySignal,
  /// حركة مساعدة (كرسي/روبوت) — ليست إذن تحكم تلقائي.
  mobility,
  obstacleDetection,
  seatControl,
}
