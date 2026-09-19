/// =============================================================
/// Lifex-AI — اتصال
/// الملف: device_discovery.dart
/// المسح لا يخترع أجهزة غير مكتشفة.
/// =============================================================
library lifex_ai.core.connectivity.device_discovery;

import 'connection_device.dart';
import 'connection_state.dart';
import 'connection_type.dart';
import 'transport.dart';

class DeviceDiscovery {
  DeviceDiscovery({
    Map<ConnectionType, DeviceTransport>? transports,
    List<ConnectionDevice>? virtualCatalog,
  }) : transports = transports ??
            {
              ConnectionType.usb: UnboundTransport(ConnectionType.usb),
              ConnectionType.serial: UnboundTransport(ConnectionType.serial),
              ConnectionType.bluetooth:
                  UnboundTransport(ConnectionType.bluetooth),
              ConnectionType.ble: UnboundTransport(ConnectionType.ble),
              ConnectionType.wifi: UnboundTransport(ConnectionType.wifi),
              ConnectionType.wifiDirect:
                  UnboundTransport(ConnectionType.wifiDirect),
              ConnectionType.nfc: UnboundTransport(ConnectionType.nfc),
              ConnectionType.virtual: VirtualLoopbackTransport(),
            },
        virtualCatalog = virtualCatalog ?? [];

  final Map<ConnectionType, DeviceTransport> transports;
  final List<ConnectionDevice> virtualCatalog;

  Future<List<ConnectionDevice>> scan({
    bool usb = true,
    bool bluetooth = true,
    bool ble = true,
    bool wifi = true,
    bool nfc = false,
    bool includeVirtual = true,
  }) async {
    final found = <ConnectionDevice>[];
    Future<void> add(ConnectionType type, bool enabled) async {
      if (!enabled) return;
      final t = transports[type];
      if (t == null) return;
      found.addAll(await t.scan());
    }

    await add(ConnectionType.usb, usb);
    await add(ConnectionType.bluetooth, bluetooth);
    await add(ConnectionType.ble, ble);
    await add(ConnectionType.wifi, wifi);
    await add(ConnectionType.nfc, nfc);
    if (includeVirtual) {
      for (final d in virtualCatalog) {
        if (d.state == ConnectionState.disconnected) {
          found.add(d);
        } else {
          found.add(d);
        }
      }
    }
    return found;
  }
}
