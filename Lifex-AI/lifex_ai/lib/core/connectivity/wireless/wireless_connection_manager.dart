/// =============================================================
/// Lifex-AI — اتصال لاسلكي
/// الملف: wireless_connection_manager.dart
/// =============================================================
library lifex_ai.core.connectivity.wireless.wireless_connection_manager;

import 'ble/ble_manager.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'nfc/nfc_manager.dart';
import 'wifi/wifi_manager.dart';

class WirelessConnectionManager {
  WirelessConnectionManager({
    BluetoothManager? bluetooth,
    BleManager? ble,
    WifiManager? wifi,
    WifiDirectManager? wifiDirect,
    NfcManager? nfc,
  })  : bluetooth = bluetooth ?? UnboundBluetoothManager(),
        ble = ble ?? BleManager(),
        wifi = wifi ?? WifiManager(),
        wifiDirect = wifiDirect ?? const WifiDirectManager(),
        nfc = nfc ?? const NfcManager();

  final BluetoothManager bluetooth;
  final BleManager ble;
  final WifiManager wifi;
  final WifiDirectManager wifiDirect;
  final NfcManager nfc;

  bool get hardwareBound => false;
}
