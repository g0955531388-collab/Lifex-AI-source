/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: smart_home_medical_driver.dart
/// أجهزة منزلية وطبية خلف جسر عتاد أو أي نقل مربوط (MQTT/BLE/USB عند اعتماد حزمها).
/// الطبي: قراءة فقط — القياس ملاحظة، والتحكم بالجهاز الطبي ممنوع.
/// المنزلي: تحكم بأوامر يعلنها الجهاز، والحساس منها (أقفال...) يحتاج تأكيداً.
/// =============================================================
library lifex_ai.core.device_integration.drivers.smart_home_medical_driver;

import '../../connectivity/connection_device.dart';
import '../../connectivity/device_capability.dart';
import '../../device_control_center/control_types.dart';
import 'bridge_device_driver.dart';

enum ApplianceClass { home, medical }

class SmartHomeMedicalDriver extends BridgeDeviceDriver {
  SmartHomeMedicalDriver({
    required super.transport,
    required this.applianceClass,
    super.pipeline,
    super.states,
    super.permissions,
    super.ackTimeout,
  });

  final ApplianceClass applianceClass;

  static const lowRiskHomeActions = {
    'POWER_ON',
    'POWER_OFF',
    'SET_LEVEL',
    'SET_COLOR',
    'SET_MODE',
  };

  @override
  String get driverId => 'lifex.appliance.${applianceClass.name}';

  @override
  String get name => applianceClass == ApplianceClass.medical
      ? 'Medical device (read only)'
      : 'Smart home device';

  @override
  DeviceCapability? get controlCapability => DeviceCapability.writeData;

  @override
  CommandRisk riskOf(String action) {
    if (isReadAction(action)) return CommandRisk.low;
    if (applianceClass == ApplianceClass.medical) return CommandRisk.medical;
    if (lowRiskHomeActions.contains(action)) return CommandRisk.low;
    return CommandRisk.sensitive;
  }

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == transport.type &&
      device.capabilities.contains(DeviceCapability.readData);

  @override
  bool supports(DeviceCapability capability) => {
        DeviceCapability.readData,
        DeviceCapability.streamData,
        if (applianceClass == ApplianceClass.home) DeviceCapability.writeData,
      }.contains(capability);
}
