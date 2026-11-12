/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_device.dart
/// نموذج محاكاة. ليس سواقاً لمصنّع حقيقي.
/// =============================================================
library lifex_ai.core.device_lab.virtual_device;

import 'dart:async';

import '../../connectivity/device_capability.dart';
import '../control_stage.dart';
import '../lab_command.dart';
import '../lab_kind.dart';
import '../simulation/connection_simulator.dart';
import 'virtual_display.dart';

abstract class VirtualDevice {
  String get id;
  String get name;
  String get category;
  LabDeviceState get snapshot;
  List<DeviceCapability> get capabilities;
  Future<void> initialize();
  Future<void> connect();
  Future<void> disconnect();
  Future<LabResponse> execute(LabCommand command);
  Stream<LabEvent> get events;
  Future<void> reset();
}

class LabActor implements VirtualDevice {
  LabActor({
    required this.id,
    required this.kind,
    String? name,
    List<DeviceCapability>? capabilities,
    List<String>? actions,
    this.linkKind = 'virtual',
  })  : name = name ?? 'Lifex Lab ${kind.category}',
        capabilities = capabilities ?? _capsFor(kind),
        actions = actions ?? _actionsFor(kind);

  @override
  final String id;
  @override
  final String name;
  final LabKind kind;
  final String linkKind;
  @override
  final List<DeviceCapability> capabilities;
  final List<String> actions;
  final display = VirtualDisplay();
  final battery = BatterySimulator();
  final link = ConnectionSimulator();
  final sensors = <String, VirtualSensor>{};
  final firmware = 'lab.1.0';
  final protocol = 'lifex.virtual.v1';
  DeviceControlStage stage = DeviceControlStage.identified;
  bool powered = false;
  bool initialized = false;
  final _values = <String, dynamic>{};
  final _events = StreamController<LabEvent>.broadcast();

  @override
  String get category => kind.category;

  @override
  LabDeviceState get snapshot => LabDeviceState(
        deviceId: id,
        powered: powered,
        connected: stage.index >= DeviceControlStage.connected.index &&
            !link.simulateDisconnect,
        stage: stage,
        values: Map<String, dynamic>.from(_values)
          ..['simulated'] = true
          ..['firmware'] = firmware
          ..['protocol'] = protocol
          ..['link'] = linkKind
          ..addAll({
            for (final s in sensors.entries)
              s.key: s.value.value,
          }),
        batteryPercent: battery.percent,
        displayContent: display.content,
      );

  @override
  Stream<LabEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    initialized = true;
    stage = DeviceControlStage.identified;
    _seedSensors();
    _emit('initialized', {});
  }

  @override
  Future<void> connect() async {
    if (!initialized) await initialize();
    if (link.authFailure) {
      _emit('auth_failure', {});
      return;
    }
    if (link.simulateDisconnect) return;
    stage = DeviceControlStage.connected;
    _emit('connected', {'link': linkKind});
  }

  Future<LabResponse> authorize() async {
    if (stage.index < DeviceControlStage.connected.index) {
      return const LabResponse(ok: false, reason: 'not_connected');
    }
    stage = DeviceControlStage.authorized;
    _emit('authorized', {});
    return const LabResponse(ok: true);
  }

  Future<LabResponse> grantControl() async {
    if (stage != DeviceControlStage.authorized) {
      return const LabResponse(ok: false, reason: 'not_authorized');
    }
    stage = DeviceControlStage.controllable;
    _emit('controllable', {});
    return const LabResponse(ok: true);
  }

  @override
  Future<void> disconnect() async {
    stage = DeviceControlStage.identified;
    _emit('disconnected', {});
  }

  @override
  Future<void> reset() async {
    powered = false;
    display.content = '';
    battery.percent = 100;
    battery.low = false;
    link.simulateDisconnect = false;
    link.packetLoss = 0;
    link.latency = Duration.zero;
    stage = DeviceControlStage.identified;
    _values.clear();
    _seedSensors();
    _emit('reset', {});
  }

  @override
  Future<LabResponse> execute(LabCommand command) async {
    if (link.latency > Duration.zero) {
      await Future<void>.delayed(link.latency);
    }
    if (link.timeout) {
      return const LabResponse(ok: false, reason: 'timeout');
    }
    if (link.malformed) {
      return const LabResponse(ok: false, reason: 'malformed_packet');
    }
    if (link.dropNow) {
      return const LabResponse(ok: false, reason: 'link_down');
    }
    if (command.action == 'startInfusion' ||
        command.action == 'shock' ||
        command.action == 'ventilate') {
      return const LabResponse(ok: false, reason: 'real_actuator_forbidden');
    }
    if (command.action == 'readState') {
      if (!stage.mayRead) {
        return const LabResponse(ok: false, reason: 'not_connected');
      }
      return LabResponse(ok: true, values: snapshot.values);
    }
    if (command.action == 'authorize') return authorize();
    if (command.action == 'grantControl') return grantControl();
    if (!actions.contains(command.action) && command.action != 'show') {
      return const LabResponse(ok: false, reason: 'unsupported_command');
    }
    if (!stage.mayControl &&
        command.action != 'readState' &&
        command.action != 'authorize' &&
        command.action != 'grantControl' &&
        command.action != 'injectSimulatedVital') {
      return const LabResponse(ok: false, reason: 'not_controllable');
    }
    switch (command.action) {
      case 'powerOn':
        powered = true;
        _emit('power_changed', {'powered': true});
        return const LabResponse(ok: true);
      case 'powerOff':
        powered = false;
        _emit('power_changed', {'powered': false});
        return const LabResponse(ok: true);
      case 'setVolume':
        _values['volume'] = command.parameters['value'] ??
            command.parameters['volume'];
        _emit('volume', {'volume': _values['volume']});
        return const LabResponse(ok: true);
      case 'mute':
        _values['muted'] = true;
        return const LabResponse(ok: true);
      case 'show':
        await display.show('${command.parameters['content'] ?? ''}');
        _emit('display', {'content': display.content});
        return const LabResponse(ok: true);
      case 'injectSimulatedVital':
        if (!kind.medicalSimulation &&
            kind != LabKind.watch &&
            kind != LabKind.fitnessBand) {
          return const LabResponse(ok: false, reason: 'not_medical_sim');
        }
        final key = '${command.parameters['key']}';
        final value = command.parameters['value'];
        if (value == null || key.isEmpty) {
          return const LabResponse(ok: false, reason: 'missing_vital');
        }
        sensors.putIfAbsent(key, () => VirtualSensor(key)).setSimulated(value);
        _values[key] = value;
        _values['simulated'] = true;
        _emit('measurement', {key: value, 'simulated': true});
        return const LabResponse(ok: true);
      case 'simulateFlow':
        if (kind != LabKind.infusionPump) {
          return const LabResponse(ok: false, reason: 'not_pump_sim');
        }
        _values['flow'] = command.parameters['flow'];
        _values['simulated'] = true;
        _emit('flow', {'flow': _values['flow'], 'simulated': true});
        return const LabResponse(ok: true);
      default:
        _values[command.action] = command.parameters;
        _emit('command', {'action': command.action});
        return const LabResponse(ok: true);
    }
  }

  void emitPeer(String kind, Map<String, dynamic> payload) {
    _emit(kind, payload);
  }

  void _seedSensors() {
    sensors.clear();
    if (kind == LabKind.watch || kind == LabKind.patientMonitor) {
      sensors['hr'] = VirtualSensor('hr', unit: 'bpm')..value = 72;
      sensors['spo2'] = VirtualSensor('spo2', unit: '%')..value = 98;
    }
    if (kind == LabKind.patientMonitor) {
      sensors['rr'] = VirtualSensor('rr')..value = 16;
      sensors['temperature'] = VirtualSensor('temperature', unit: 'C')
        ..value = 36.8;
    }
    if (kind == LabKind.ecg) {
      sensors['sample_rate'] = VirtualSensor('sample_rate')..value = 250;
    }
  }

  void _emit(String kind, Map<String, dynamic> payload) {
    _events.add(
      LabEvent(
        deviceId: id,
        kind: kind,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
  }

  static List<DeviceCapability> _capsFor(LabKind kind) {
    switch (kind) {
      case LabKind.tv:
        return [
          DeviceCapability.display,
          DeviceCapability.volume,
          DeviceCapability.mediaControl,
          DeviceCapability.powerOn,
          DeviceCapability.powerOff,
        ];
      case LabKind.phone:
      case LabKind.tablet:
        return [
          DeviceCapability.display,
          DeviceCapability.camera,
          DeviceCapability.microphone,
          DeviceCapability.speaker,
        ];
      case LabKind.watch:
        return [DeviceCapability.readData, DeviceCapability.vitalSigns];
      case LabKind.patientMonitor:
      case LabKind.ecg:
      case LabKind.spo2:
        return [DeviceCapability.readData, DeviceCapability.vitalSigns];
      case LabKind.infusionPump:
        return [DeviceCapability.infusionMonitoring, DeviceCapability.readData];
      case LabKind.light:
        return [DeviceCapability.powerOn, DeviceCapability.powerOff];
      default:
        return [DeviceCapability.readData];
    }
  }

  static List<String> _actionsFor(LabKind kind) {
    switch (kind) {
      case LabKind.tv:
        return [
          'powerOn',
          'powerOff',
          'setVolume',
          'mute',
          'show',
          'play',
          'pause',
          'stop',
        ];
      case LabKind.light:
        return ['powerOn', 'powerOff'];
      case LabKind.phone:
        return ['show', 'speak'];
      case LabKind.infusionPump:
        return ['simulateFlow', 'readState'];
      case LabKind.patientMonitor:
      case LabKind.ecg:
      case LabKind.watch:
        return ['injectSimulatedVital', 'readState'];
      default:
        return ['readState', 'show', 'powerOn', 'powerOff'];
    }
  }
}
