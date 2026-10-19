/// =============================================================
/// Lifex-AI — سواقات
/// الملف: virtual_device.dart
/// جهاز وهمي للاختبار. ليس جهازاً حقيقياً في السوق.
/// =============================================================
library lifex_ai.core.device_drivers.virtual_device;

import 'dart:async';

import '../connectivity/connection_device.dart';
import '../connectivity/connection_state.dart';
import '../connectivity/connection_type.dart';
import '../connectivity/device_capability.dart';
import 'device_command.dart';
import 'device_driver_profile.dart';
import 'device_event.dart';
import 'device_state.dart';
import 'universal_driver.dart';

class VirtualDevice implements UniversalDriver {
  VirtualDevice({
    required this.profile,
    required this.deviceId,
    required this.displayName,
  }) : connection = ConnectionDevice(
          id: deviceId,
          name: displayName,
          connectionType: ConnectionType.virtual,
          state: ConnectionState.disconnected,
          manufacturer: 'Lifex Simulator',
          model: profile.category,
          virtual: true,
          identityConfirmed: true,
          capabilities: profile.capabilities.toList(),
        );

  final DeviceDriverProfile profile;
  final String deviceId;
  final String displayName;
  final ConnectionDevice connection;
  final _controller = StreamController<DeviceEvent>.broadcast();
  DeviceState _state = DeviceState.empty();
  final List<String> displayLog = [];

  @override
  String get driverId => profile.driverId;

  @override
  String get name => profile.name;

  @override
  Stream<DeviceEvent> get events => _controller.stream;

  @override
  bool supports(DeviceCapability capability) =>
      profile.capabilities.contains(capability);

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.id == deviceId || profile.matches(device);

  @override
  Future<CommandResult> connect(ConnectionDevice device) async {
    if (device.id != deviceId) {
      return const CommandResult(ok: false, reason: 'wrong_device');
    }
    connection.state = ConnectionState.connected;
    _state = DeviceState(
      deviceId: deviceId,
      connected: true,
      powered: _state.powered,
      values: Map<String, dynamic>.from(_state.values),
    );
    _emit('connected', {});
    return const CommandResult(ok: true);
  }

  @override
  Future<void> disconnect() async {
    connection.state = ConnectionState.disconnected;
    _state = _state.copyWith(connected: false);
    _emit('disconnected', {});
  }

  @override
  Future<DeviceState> readState() async => _state;

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    if (!_state.connected) {
      return const CommandResult(ok: false, reason: 'not_connected');
    }
    if (!profile.supportedActions.contains(command.action)) {
      return const CommandResult(ok: false, reason: 'unsupported_action');
    }
    switch (command.action) {
      case 'powerOn':
        _state = _state.copyWith(powered: true);
        _emit('power', {'powered': true});
        return const CommandResult(ok: true);
      case 'powerOff':
        _state = _state.copyWith(powered: false);
        _emit('power', {'powered': false});
        return const CommandResult(ok: true);
      case 'setVolume':
        final v = command.parameters['volume'];
        final values = Map<String, dynamic>.from(_state.values)..['volume'] = v;
        _state = _state.copyWith(values: values);
        _emit('volume', {'volume': v});
        return const CommandResult(ok: true);
      case 'show':
        final content = '${command.parameters['content'] ?? ''}';
        displayLog.add(content);
        _emit('display', {'content': content});
        return const CommandResult(ok: true);
      case 'speak':
        _emit('speak', {'text': command.parameters['text']});
        return const CommandResult(ok: true);
      case 'readMeasurement':
        return const CommandResult(ok: false, reason: 'no_live_sensor');
      case 'readState':
        return const CommandResult(ok: true);
      case 'MOVE_FORWARD':
      case 'MOVE_BACKWARD':
      case 'TURN_LEFT':
      case 'TURN_RIGHT':
      case 'SET_SPEED':
      case 'CONTROL_SEAT':
      case 'LIGHT_ON':
      case 'LIGHT_OFF':
        final values = Map<String, dynamic>.from(_state.values)
          ..addAll(command.parameters)
          ..['lastAction'] = command.action
          ..['motion'] = command.action
          ..['executedOnHardware'] = false;
        _state = _state.copyWith(values: values);
        _emit('motion', values);
        return const CommandResult(ok: true, executedOnHardware: false);
      case 'STOP':
      case 'EMERGENCY_STOP':
        final stopValues = Map<String, dynamic>.from(_state.values)
          ..['motion'] = 'stopped'
          ..['lastAction'] = command.action
          ..['speed'] = 0;
        _state = _state.copyWith(values: stopValues);
        _emit('stop', stopValues);
        return const CommandResult(ok: true, executedOnHardware: false);
      case 'READ_BATTERY':
      case 'READ_SPEED':
      case 'READ_OBSTACLE':
      case 'READ_POSITION':
        return CommandResult(
          ok: true,
          reason: 'simulated_read',
          executedOnHardware: false,
        );
      case 'printUnbound':
      case 'startPreviewUnbound':
      case 'requestCameraDeniedByDefault':
        return const CommandResult(ok: false, reason: 'hardware_unbound');
      default:
        return const CommandResult(ok: false, reason: 'unknown_action');
    }
  }

  /// الجهاز الوهمي يطلب من الهاتف (تشغيل متبادل داخل المحاكاة).
  void requestFromPeer(String kind, Map<String, dynamic> payload) {
    _emit('peer_request', {'kind': kind, ...payload});
  }

  /// قياس محاكى — قيمة اختبار وليست قراءة مريض.
  void injectSimulatedMeasurement(String type, Object value) {
    final values = Map<String, dynamic>.from(_state.values);
    values[type] = value;
    values['simulated'] = true;
    _state = _state.copyWith(values: values);
    _controller.add(
      DeviceEvent(
        deviceId: deviceId,
        kind: 'measurement',
        timestamp: DateTime.now(),
        payload: {'type': type, 'value': value, 'simulated': true},
      ),
    );
  }

  void _emit(String kind, Map<String, dynamic> payload) {
    _controller.add(
      DeviceEvent(
        deviceId: deviceId,
        kind: kind,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
  }
}
