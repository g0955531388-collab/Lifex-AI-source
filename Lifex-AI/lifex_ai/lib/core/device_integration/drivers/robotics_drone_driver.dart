/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: robotics_drone_driver.dart
/// روبوتات ودرون:
///   MAVLink v2: قراءة القياس عن بُعد فقط (نبض، موقع، تأكيد أوامر).
///   LBP عبر جسر عتاد: تحكم بأوامر يعلنها الجسر نفسه.
/// الحركة تحتاج تخويلاً وقناة آمنة وتأكيد المستخدم. الإيقاف أولوية بلا تأكيد.
/// =============================================================
library lifex_ai.core.device_integration.drivers.robotics_drone_driver;

import '../../connectivity/connection_device.dart';
import '../../connectivity/device_capability.dart';
import '../../device_control_center/control_types.dart';
import '../pipeline/device_reading.dart';
import '../protocols/mavlink_v2.dart';
import 'bridge_device_driver.dart';

enum RoboticsProtocol { lbp, mavlink }

class RoboticsDroneDriver extends BridgeDeviceDriver {
  RoboticsDroneDriver({
    required super.transport,
    this.protocol = RoboticsProtocol.lbp,
    super.pipeline,
    super.states,
    super.permissions,
    super.ackTimeout,
  });

  final RoboticsProtocol protocol;
  final mavlink = MavlinkV2Decoder();

  static const stopActions = {'STOP', 'EMERGENCY_STOP'};
  static const motionActions = {
    'MOVE_FORWARD',
    'MOVE_BACKWARD',
    'TURN_LEFT',
    'TURN_RIGHT',
    'SET_SPEED',
    'GOTO',
    'TAKEOFF',
    'LAND',
    'RETURN_HOME',
    'ARM',
  };
  static const lowRiskActions = {'LIGHT_ON', 'LIGHT_OFF', 'CAMERA_START', 'CAMERA_STOP'};

  @override
  String get driverId => 'lifex.robotics.${protocol.name}';

  @override
  String get name => 'Robotics / drone';

  /// MAVLink هنا قراءة فقط.
  @override
  DeviceCapability? get controlCapability =>
      protocol == RoboticsProtocol.mavlink ? null : DeviceCapability.mobility;

  @override
  CommandRisk riskOf(String action) {
    if (stopActions.contains(action)) return CommandRisk.emergency;
    if (isReadAction(action) || lowRiskActions.contains(action)) {
      return CommandRisk.low;
    }
    if (motionActions.contains(action)) return CommandRisk.motion;
    return CommandRisk.sensitive;
  }

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == transport.type &&
      device.capabilities.contains(DeviceCapability.mobility);

  @override
  void resetDecoder() {
    super.resetDecoder();
    mavlink.reset();
  }

  @override
  void onBytes(List<int> bytes) {
    if (protocol == RoboticsProtocol.lbp) return super.onBytes(bytes);
    for (final frame in mavlink.feed(bytes)) {
      switch (frame.messageId) {
        case MavlinkV2Decoder.msgHeartbeat:
          final hb = MavlinkV2Decoder.heartbeat(frame);
          mergeValues({
            'armed': hb.armed,
            'vehicleType': hb.vehicleType,
            'autopilot': hb.autopilot,
            'systemStatus': hb.systemStatus,
            'mavSystemId': frame.systemId,
            'signedUnverified': frame.signed,
          });
        case MavlinkV2Decoder.msgGlobalPositionInt:
          final p = MavlinkV2Decoder.globalPosition(frame);
          emitReading(
            channel: 'position',
            kind: ReadingKind.position,
            protocol: mavlink.protocolName,
            value: {
              'lat': p.latitude,
              'lon': p.longitude,
              'altMslM': p.altitudeMslM,
              'relAltM': p.relativeAltitudeM,
              'vxMs': p.vxMs,
              'vyMs': p.vyMs,
              'vzMs': p.vzMs,
              if (p.headingDeg != null) 'headingDeg': p.headingDeg!,
            },
          );
        case MavlinkV2Decoder.msgCommandAck:
          final ack = MavlinkV2Decoder.commandAck(frame);
          emitEvent('command_ack', {
            'command': ack.command,
            'result': ack.result,
            'accepted': ack.accepted,
          });
      }
    }
  }

  @override
  bool supports(DeviceCapability capability) => {
        DeviceCapability.readData,
        DeviceCapability.streamData,
        DeviceCapability.location,
        if (protocol == RoboticsProtocol.lbp) DeviceCapability.mobility,
      }.contains(capability);
}
