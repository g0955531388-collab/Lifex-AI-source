/// =============================================================
/// Lifex-AI — تعريف كرسي ذكي (تصميم Lifex)
/// الملف: smart_wheelchair_profile.dart
/// تعريف قدرات ≠ دعم عتاد حقيقي. الحركة تمر عبر Control Center.
/// =============================================================
library lifex_ai.core.device_drivers.smart_wheelchair_profile;

import '../device_control_center/control_types.dart';
import '../device_protocol/protocol_packet.dart';
import '../device_services/service_record.dart';
import '../device_services/service_types.dart';

/// تصنيف مخاطر أوامر الكرسي.
enum WheelchairCommandClass {
  read,
  lowRiskControl,
  motionControl,
  highRiskControl,
  emergencyStop,
}

class SmartWheelchairDeviceProfile {
  static const deviceId = 'sim_wheelchair_001';
  static const definitionId = 'lifex.smart_wheelchair.v1';

  static const manufacturer = 'Lifex';
  static const model = 'Lifex-SW-Sim';
  static const category = 'smart_wheelchair';

  /// هل يوجد Adapter عتاد حقيقي مربوط؟ حالياً: محاكاة فقط.
  static const bool realHardwareAdapterBound = false;

  static const services = <String>[
    'Mobility',
    'Navigation',
    'VoiceControl',
    'ObstacleDetection',
    'Battery',
    'SeatControl',
    'Lighting',
    'Diagnostics',
    'Emergency',
  ];

  static const mobilityServiceId = 'wc.mobility';
  static const batteryServiceId = 'wc.battery';
  static const emergencyServiceId = 'wc.emergency';

  static WheelchairCommandClass classify(String action) {
    switch (action) {
      case 'READ_BATTERY':
      case 'READ_SPEED':
      case 'READ_OBSTACLE':
      case 'READ_POSITION':
      case 'readState':
        return WheelchairCommandClass.read;
      case 'LIGHT_ON':
      case 'LIGHT_OFF':
      case 'CONTROL_SEAT':
        return WheelchairCommandClass.lowRiskControl;
      case 'MOVE_FORWARD':
      case 'MOVE_BACKWARD':
      case 'TURN_LEFT':
      case 'TURN_RIGHT':
      case 'SET_SPEED':
        return WheelchairCommandClass.motionControl;
      case 'STOP':
        return WheelchairCommandClass.highRiskControl;
      case 'EMERGENCY_STOP':
        return WheelchairCommandClass.emergencyStop;
      default:
        return WheelchairCommandClass.highRiskControl;
    }
  }

  static CommandRisk riskFor(String action) {
    switch (classify(action)) {
      case WheelchairCommandClass.read:
      case WheelchairCommandClass.lowRiskControl:
        return CommandRisk.low;
      case WheelchairCommandClass.motionControl:
        return CommandRisk.motion;
      case WheelchairCommandClass.highRiskControl:
        return CommandRisk.sensitive;
      case WheelchairCommandClass.emergencyStop:
        return CommandRisk.emergency;
    }
  }

  static List<CapabilityDescriptor> protocolCapabilities() => const [
        CapabilityDescriptor(
          id: 'mobility',
          name: 'mobility',
          category: 'assistive',
          readable: true,
          controllable: true,
          commands: [
            'MOVE_FORWARD',
            'MOVE_BACKWARD',
            'TURN_LEFT',
            'TURN_RIGHT',
            'STOP',
            'EMERGENCY_STOP',
            'SET_SPEED',
          ],
        ),
        CapabilityDescriptor(
          id: 'battery',
          name: 'battery',
          category: 'energy',
          readable: true,
          commands: ['READ_BATTERY'],
        ),
        CapabilityDescriptor(
          id: 'obstacle',
          name: 'obstacle',
          category: 'safety',
          readable: true,
          streamable: true,
          commands: ['READ_OBSTACLE'],
        ),
        CapabilityDescriptor(
          id: 'seat',
          name: 'seat',
          category: 'assistive',
          controllable: true,
          commands: ['CONTROL_SEAT'],
        ),
        CapabilityDescriptor(
          id: 'lighting',
          name: 'lighting',
          category: 'assistive',
          controllable: true,
          commands: ['LIGHT_ON', 'LIGHT_OFF'],
        ),
      ];

  static ServiceRecord mobilityService({
    required bool connected,
    required bool trusted,
    required Set<AccessScope> scopes,
  }) {
    return ServiceRecord(
      serviceId: mobilityServiceId,
      deviceId: deviceId,
      name: 'Mobility',
      category: ServiceCategory.accessibility,
      status: connected
          ? ServiceStatus.available
          : ServiceStatus.disconnected,
      connected: connected,
      trusted: trusted,
      authorizedScopes: scopes,
      capabilities: const [
        CapabilityRecord(
          universalId: 'MOVE_FORWARD',
          nativeId: 'fwd',
          deviceId: deviceId,
          serviceId: mobilityServiceId,
          controllable: true,
        ),
        CapabilityRecord(
          universalId: 'STOP',
          nativeId: 'stop',
          deviceId: deviceId,
          serviceId: mobilityServiceId,
          controllable: true,
        ),
        CapabilityRecord(
          universalId: 'EMERGENCY_STOP',
          nativeId: 'estop',
          deviceId: deviceId,
          serviceId: mobilityServiceId,
          controllable: true,
        ),
      ],
      commands: const [
        CommandDefinition(
          commandId: 'MOVE_FORWARD',
          serviceId: mobilityServiceId,
          requiresConfirmation: true,
        ),
        CommandDefinition(
          commandId: 'MOVE_BACKWARD',
          serviceId: mobilityServiceId,
          requiresConfirmation: true,
        ),
        CommandDefinition(
          commandId: 'TURN_LEFT',
          serviceId: mobilityServiceId,
          requiresConfirmation: true,
        ),
        CommandDefinition(
          commandId: 'TURN_RIGHT',
          serviceId: mobilityServiceId,
          requiresConfirmation: true,
        ),
        CommandDefinition(
          commandId: 'SET_SPEED',
          serviceId: mobilityServiceId,
          requiresConfirmation: true,
          parameters: ['speed'],
        ),
        CommandDefinition(
          commandId: 'STOP',
          serviceId: mobilityServiceId,
          requiresConfirmation: false,
        ),
        CommandDefinition(
          commandId: 'EMERGENCY_STOP',
          serviceId: mobilityServiceId,
          requiresConfirmation: false,
        ),
        CommandDefinition(
          commandId: 'LIGHT_ON',
          serviceId: mobilityServiceId,
        ),
        CommandDefinition(
          commandId: 'LIGHT_OFF',
          serviceId: mobilityServiceId,
        ),
        CommandDefinition(
          commandId: 'CONTROL_SEAT',
          serviceId: mobilityServiceId,
          parameters: ['position'],
        ),
        CommandDefinition(
          commandId: 'READ_BATTERY',
          serviceId: mobilityServiceId,
        ),
        CommandDefinition(
          commandId: 'READ_OBSTACLE',
          serviceId: mobilityServiceId,
        ),
        CommandDefinition(
          commandId: 'READ_SPEED',
          serviceId: mobilityServiceId,
        ),
        CommandDefinition(
          commandId: 'READ_POSITION',
          serviceId: mobilityServiceId,
        ),
      ],
    );
  }
}
