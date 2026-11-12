/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: screen_display_driver.dart
/// شاشات: تطبيق Lifex آخر (LAN) أو شاشة طبية/صناعية خلف جسر عتاد.
/// الشاشة الطبية في وضع المشاهدة فقط: تُقرأ ولا يُرسل إليها أمر.
/// =============================================================
library lifex_ai.core.device_integration.drivers.screen_display_driver;

import '../../connectivity/connection_device.dart';
import '../../connectivity/device_capability.dart';
import '../../device_control_center/control_types.dart';
import 'bridge_device_driver.dart';

class ScreenDisplayDriver extends BridgeDeviceDriver {
  ScreenDisplayDriver({
    required super.transport,
    super.pipeline,
    super.states,
    super.permissions,
    super.ackTimeout,
    this.viewOnly = false,
    this.explicitGrant = true,
    this.peerDeclaresActions = true,
  });

  /// شاشات المراقبة الطبية والصناعية: مشاهدة فقط.
  final bool viewOnly;
  final bool explicitGrant;
  final bool peerDeclaresActions;

  @override
  String get driverId => 'lifex.screen.display';

  @override
  String get name => 'Screen display';

  @override
  DeviceCapability? get controlCapability =>
      viewOnly ? null : DeviceCapability.display;

  @override
  bool get requiresExplicitGrant => explicitGrant;

  @override
  bool get requiresDeclaredActions => peerDeclaresActions;

  @override
  CommandRisk riskOf(String action) => CommandRisk.low;

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == transport.type &&
      device.capabilities.contains(DeviceCapability.display);

  @override
  bool supports(DeviceCapability capability) => {
        DeviceCapability.display,
        DeviceCapability.readData,
        DeviceCapability.streamData,
        if (!viewOnly) DeviceCapability.writeData,
      }.contains(capability);
}
