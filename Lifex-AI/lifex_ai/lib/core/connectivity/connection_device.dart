/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connection_device.dart
/// نموذج موحّد. الاسم الظاهر ليس هوية مؤكَّدة.
/// =============================================================
library lifex_ai.core.connectivity.connection_device;

import 'connection_state.dart';
import 'connection_type.dart';
import 'device_capability.dart';

class ConnectionDevice {
  ConnectionDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.state,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.capabilities = const [],
    this.virtual = false,
    this.identityConfirmed = false,
  });

  final String id;
  final String name;
  final ConnectionType connectionType;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final List<DeviceCapability> capabilities;
  final bool virtual;
  final bool identityConfirmed;
  ConnectionState state;
}
