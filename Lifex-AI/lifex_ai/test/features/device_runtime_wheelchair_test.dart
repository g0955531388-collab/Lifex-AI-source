/// =============================================================
/// Lifex-AI — اختبار ربط منظومة الأجهزة + الكرسي
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_control_center/control_types.dart';
import 'package:lifex_ai/core/device_drivers/smart_wheelchair_profile.dart';
import 'package:lifex_ai/core/device_protocol/packet_type.dart';
import 'package:lifex_ai/features/devices/lifex_device_runtime.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('attach wheelchair walks protocol ladder to controllable', () async {
    final runtime = LifexDeviceRuntime();
    final o = await runtime.attachSimulatedWheelchair();
    expect(o.ok, isTrue);
    expect(
      runtime.protocol.stageOf(SmartWheelchairDeviceProfile.deviceId),
      ProtocolSessionStage.controllable,
    );
    expect(runtime.dashboard(), isNotEmpty);
  });

  test('motion requires confirmation then verifies state', () async {
    final runtime = LifexDeviceRuntime();
    await runtime.attachSimulatedWheelchair();

    final pending = await runtime.runWheelchairAction('MOVE_FORWARD');
    expect(pending.ok, isFalse);
    expect(pending.result?.status, CommandStatus.awaitingConfirmation);

    final confirmed = await runtime.confirmPendingMotion();
    expect(confirmed.ok, isTrue);
    expect(confirmed.result?.stateVerified, isTrue);
    final snap =
        runtime.protocol.readState(SmartWheelchairDeviceProfile.deviceId);
    expect(snap?.values['motion'], 'MOVE_FORWARD');
  });

  test('emergency stop bypasses confirmation', () async {
    final runtime = LifexDeviceRuntime();
    await runtime.attachSimulatedWheelchair();
    final o = await runtime.runWheelchairAction('EMERGENCY_STOP');
    expect(o.ok, isTrue);
    expect(o.result?.status, CommandStatus.succeeded);
    final snap =
        runtime.protocol.readState(SmartWheelchairDeviceProfile.deviceId);
    expect(snap?.values['motion'], 'stopped');
  });

  test('obstacle policy blocks motion', () async {
    final runtime = LifexDeviceRuntime()..obstacleBlocksMotion = true;
    await runtime.attachSimulatedWheelchair();
    final o = await runtime.runWheelchairAction(
      'MOVE_FORWARD',
      userConfirmed: true,
    );
    expect(o.ok, isFalse);
    expect(o.spokenAr, contains('العوائق'));
  });

  test('read battery does not claim hardware', () async {
    final runtime = LifexDeviceRuntime();
    await runtime.attachSimulatedWheelchair();
    final o = await runtime.runWheelchairAction('READ_BATTERY');
    expect(o.ok, isTrue);
    expect(o.spokenAr, contains('محاكاة'));
    expect(SmartWheelchairDeviceProfile.realHardwareAdapterBound, isFalse);
  });

  test('voice parser routes wheelchair and device center', () {
    final p = CommandParser();
    expect(
      p.parse('ليفكس أظهر الكرسي').intent,
      VoiceCommandIntent.showWheelchair,
    );
    expect(
      p.parse('ليفكس تقدم').intent,
      VoiceCommandIntent.wheelchairMoveForward,
    );
    expect(
      p.parse('ليفكس أكّد الحركة').intent,
      VoiceCommandIntent.confirmDeviceMotion,
    );
    expect(
      p.parse('ليفكس مركز الأجهزة').intent,
      VoiceCommandIntent.openDeviceCenter,
    );
    expect(
      p.parse('ليفكس فرملة الكرسي').intent,
      VoiceCommandIntent.wheelchairEmergencyStop,
    );
  });

  test('transport matrix never claims allow-all hardware', () {
    final runtime = LifexDeviceRuntime();
    final usb = runtime.transportMatrix().firstWhere((t) => t.transport == 'USB');
    expect(usb.support, AndroidTransportSupport.requiresUserAction);
    expect(
      runtime.transportMatrix().any(
            (t) => t.support == AndroidTransportSupport.supported &&
                t.transport == 'Virtual / Lab',
          ),
      isTrue,
    );
  });

  test('discovery returns simulators without claiming real market catalog',
      () async {
    final runtime = LifexDeviceRuntime();
    final found = await runtime.discover();
    expect(found, isNotEmpty);
    expect(found.any((d) => d.virtual), isTrue);
  });
}
