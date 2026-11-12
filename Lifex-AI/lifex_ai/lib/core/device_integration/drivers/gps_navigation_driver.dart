/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: gps_navigation_driver.dart
/// أجهزة GPS/GNSS خارجية (NMEA 0183) عبر TCP أو تسلسلي. قراءة فقط.
/// بلا تثبيت صالح: حالة "لا تثبيت" دون إحداثيات.
/// =============================================================
library lifex_ai.core.device_integration.drivers.gps_navigation_driver;

import '../../connectivity/connection_device.dart';
import '../../connectivity/device_capability.dart';
import '../../device_control_center/control_types.dart';
import '../pipeline/device_reading.dart';
import '../protocols/nmea_0183.dart';
import 'bridge_device_driver.dart';

class GpsNavigationDriver extends BridgeDeviceDriver {
  GpsNavigationDriver({
    required super.transport,
    super.pipeline,
    super.states,
    super.permissions,
  });

  final nmea = NmeaDecoder();

  @override
  String get driverId => 'lifex.navigation.nmea';

  @override
  String get name => 'GPS / GNSS (NMEA 0183)';

  @override
  DeviceCapability? get controlCapability => null;

  @override
  CommandRisk riskOf(String action) => CommandRisk.low;

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == transport.type &&
      device.capabilities.contains(DeviceCapability.location);

  @override
  void resetDecoder() => nmea.reset();

  @override
  void onBytes(List<int> bytes) {
    for (final sentence in nmea.feed(bytes)) {
      final fix = NmeaDecoder.toFix(sentence);
      if (fix == null) continue;
      emitReading(
        channel: 'gnss_status',
        kind: ReadingKind.status,
        protocol: nmea.protocolName,
        value: {
          'source': fix.source,
          'valid': fix.valid,
          if (fix.fixQuality != null) 'fixQuality': fix.fixQuality!,
          if (fix.satellites != null) 'satellites': fix.satellites!,
        },
      );
      if (fix.valid) {
        emitReading(
          channel: 'position',
          kind: ReadingKind.position,
          protocol: nmea.protocolName,
          value: fix.toValues(),
        );
      }
    }
  }

  @override
  bool supports(DeviceCapability capability) => const {
        DeviceCapability.location,
        DeviceCapability.readData,
        DeviceCapability.streamData,
      }.contains(capability);
}
