/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: device_integration.dart
/// مدخل طبقة التكامل. الأسماء المعمارية أسماء بديلة لمحركات Lifex القائمة
/// (لا محرك مكرر):
///   BaseDeviceDriver        = UniversalDriver
///   DeviceConnectionManager = ConnectivityManager
///   TransportAdapter        = DeviceTransport
/// =============================================================
library lifex_ai.core.device_integration;

import '../connectivity/connectivity_manager.dart';
import '../connectivity/transport.dart';
import '../device_drivers/universal_driver.dart';

export '../connectivity/bridge/bridge_tcp_transport.dart';
export '../connectivity/connectivity_manager.dart';
export '../connectivity/lan/lan_transport.dart';
export '../connectivity/mqtt/mqtt_transport.dart';
export '../connectivity/transport.dart';
export '../connectivity/transport_streams.dart';
export '../device_drivers/local_screen_sync_driver.dart';
export '../device_drivers/universal_driver.dart';
export 'drivers/bridge_device_driver.dart';
export 'drivers/gps_navigation_driver.dart';
export 'drivers/robotics_drone_driver.dart';
export 'drivers/screen_display_driver.dart';
export 'drivers/smart_home_medical_driver.dart';
export 'pipeline/device_reading.dart';
export 'pipeline/reactive_data_pipeline.dart';
export 'pipeline/stream_data_pipeline.dart';
export 'protocols/byte_stream_decoder.dart';
export 'protocols/lifex_bridge_protocol.dart';
export 'protocols/mavlink_v2.dart';
export 'protocols/nmea_0183.dart';
export 'state/device_link_state.dart';

typedef BaseDeviceDriver = UniversalDriver;
typedef DeviceConnectionManager = ConnectivityManager;
typedef TransportAdapter = DeviceTransport;
