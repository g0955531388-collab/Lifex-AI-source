/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connection_type.dart
/// نوع النقل. ليس إثباتاً أن العتاد مربوط.
/// =============================================================
library lifex_ai.core.connectivity.connection_type;

enum ConnectionType {
  usb,
  serial,
  bluetooth,
  ble,
  wifi,
  wifiDirect,
  nfc,
  virtual,
}
