/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: simulated_transports.dart
/// روابط محاكاة. ليست مآخذ USB/BLE حقيقية.
/// =============================================================
library lifex_ai.core.device_lab.simulated_transports;

class SimulatedTransport {
  SimulatedTransport(this.kind);
  final String kind;
  bool boundToHardware = false;
}

class VirtualUsb extends SimulatedTransport {
  VirtualUsb() : super('usb');
}

class VirtualSerial extends SimulatedTransport {
  VirtualSerial() : super('serial');
}

class VirtualBluetooth extends SimulatedTransport {
  VirtualBluetooth() : super('bluetooth');
}

class VirtualBle extends SimulatedTransport {
  VirtualBle() : super('ble');
}

class VirtualWifi extends SimulatedTransport {
  VirtualWifi() : super('wifi');
}

class VirtualWifiDirect extends SimulatedTransport {
  VirtualWifiDirect() : super('wifiDirect');
}

class VirtualNfc extends SimulatedTransport {
  VirtualNfc() : super('nfc');
}

class VirtualEthernet extends SimulatedTransport {
  VirtualEthernet() : super('ethernet');
}

class VirtualCloudLink extends SimulatedTransport {
  VirtualCloudLink() : super('cloud');
}
