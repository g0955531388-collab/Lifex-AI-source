/// =============================================================
/// Lifex-AI — سواقات
/// الملف: device_driver_profile.dart
/// قالب قدرات. ليس سواقاً لكل شركة وموديل في العالم.
/// =============================================================
library lifex_ai.core.device_drivers.device_driver_profile;

import '../connectivity/connection_device.dart';
import '../connectivity/device_capability.dart';

class DeviceDriverProfile {
  const DeviceDriverProfile({
    required this.driverId,
    required this.name,
    required this.category,
    required this.capabilities,
    this.supportedActions = const [],
  });

  final String driverId;
  final String name;
  final String category;
  final Set<DeviceCapability> capabilities;
  final List<String> supportedActions;

  bool matches(ConnectionDevice device) {
    if (device.virtual && device.model == category) return true;
    return false;
  }
}

class DriverProfiles {
  static const phone = DeviceDriverProfile(
    driverId: 'profile.phone',
    name: 'Phone',
    category: 'phone',
    capabilities: {
      DeviceCapability.display,
      DeviceCapability.camera,
      DeviceCapability.microphone,
      DeviceCapability.speaker,
      DeviceCapability.touch,
    },
    supportedActions: ['show', 'speak', 'requestCameraDeniedByDefault'],
  );

  static const tv = DeviceDriverProfile(
    driverId: 'profile.smart_tv',
    name: 'Smart TV',
    category: 'smart_tv',
    capabilities: {
      DeviceCapability.display,
      DeviceCapability.speaker,
      DeviceCapability.volume,
      DeviceCapability.mediaControl,
      DeviceCapability.powerOn,
      DeviceCapability.powerOff,
    },
    supportedActions: ['powerOn', 'powerOff', 'setVolume', 'show'],
  );

  static const watch = DeviceDriverProfile(
    driverId: 'profile.watch',
    name: 'Smart Watch',
    category: 'watch',
    capabilities: {
      DeviceCapability.readData,
      DeviceCapability.display,
      DeviceCapability.vitalSigns,
    },
    supportedActions: ['readState'],
  );

  static const camera = DeviceDriverProfile(
    driverId: 'profile.camera',
    name: 'Camera',
    category: 'camera',
    capabilities: {DeviceCapability.camera, DeviceCapability.streamData},
    supportedActions: ['startPreviewUnbound', 'stopPreview'],
  );

  static const medical = DeviceDriverProfile(
    driverId: 'profile.medical_device',
    name: 'Medical device template',
    category: 'medical_device',
    capabilities: {
      DeviceCapability.readData,
      DeviceCapability.vitalSigns,
      DeviceCapability.temperature,
      DeviceCapability.oxygenSaturation,
      DeviceCapability.bloodPressure,
      DeviceCapability.glucose,
      DeviceCapability.ecg,
    },
    supportedActions: ['readMeasurement'],
  );

  static const computer = DeviceDriverProfile(
    driverId: 'profile.computer',
    name: 'Computer',
    category: 'computer',
    capabilities: {
      DeviceCapability.display,
      DeviceCapability.keyboard,
      DeviceCapability.mouse,
      DeviceCapability.fileTransfer,
    },
    supportedActions: ['show'],
  );

  static const speaker = DeviceDriverProfile(
    driverId: 'profile.speaker',
    name: 'Speaker',
    category: 'speaker',
    capabilities: {DeviceCapability.speaker, DeviceCapability.volume},
    supportedActions: ['setVolume', 'speak'],
  );

  static const printer = DeviceDriverProfile(
    driverId: 'profile.printer',
    name: 'Printer',
    category: 'printer',
    capabilities: {DeviceCapability.printing},
    supportedActions: ['printUnbound'],
  );

  static const vehicle = DeviceDriverProfile(
    driverId: 'profile.vehicle',
    name: 'Vehicle infotainment template',
    category: 'vehicle',
    capabilities: {DeviceCapability.display, DeviceCapability.speaker},
    supportedActions: ['show'],
  );

  static const smartHome = DeviceDriverProfile(
    driverId: 'profile.smart_home',
    name: 'Smart home template',
    category: 'smart_home',
    capabilities: {DeviceCapability.powerOn, DeviceCapability.powerOff},
    supportedActions: ['powerOn', 'powerOff'],
  );

  static const laboratory = DeviceDriverProfile(
    driverId: 'profile.laboratory',
    name: 'Laboratory template',
    category: 'laboratory',
    capabilities: {DeviceCapability.readData, DeviceCapability.display},
    supportedActions: ['readMeasurement'],
  );

  static const generic = DeviceDriverProfile(
    driverId: 'profile.generic',
    name: 'Unknown device',
    category: 'unknown',
    capabilities: {DeviceCapability.readData},
    supportedActions: [],
  );

  /// قالب كرسي ذكي Lifex — تعريف قدرات، ليس عتاداً مادياً مربوطاً.
  static const smartWheelchair = DeviceDriverProfile(
    driverId: 'profile.smart_wheelchair',
    name: 'Lifex Smart Wheelchair',
    category: 'smart_wheelchair',
    capabilities: {
      DeviceCapability.mobility,
      DeviceCapability.obstacleDetection,
      DeviceCapability.seatControl,
      DeviceCapability.readData,
      DeviceCapability.powerOn,
      DeviceCapability.powerOff,
      DeviceCapability.emergencySignal,
      DeviceCapability.microphone,
      DeviceCapability.speaker,
    },
    supportedActions: [
      'MOVE_FORWARD',
      'MOVE_BACKWARD',
      'TURN_LEFT',
      'TURN_RIGHT',
      'STOP',
      'EMERGENCY_STOP',
      'SET_SPEED',
      'READ_SPEED',
      'READ_BATTERY',
      'READ_OBSTACLE',
      'READ_POSITION',
      'CONTROL_SEAT',
      'LIGHT_ON',
      'LIGHT_OFF',
      'readState',
    ],
  );

  static const all = [
    phone,
    tv,
    watch,
    camera,
    medical,
    computer,
    speaker,
    printer,
    vehicle,
    smartHome,
    laboratory,
    smartWheelchair,
    generic,
  ];
}
