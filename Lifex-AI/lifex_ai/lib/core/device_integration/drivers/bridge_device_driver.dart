/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: bridge_device_driver.dart
/// أساس السواقات فوق أي DeviceScopedTransport (LAN، جسر TCP، ولاحقاً BLE/USB/MQTT).
/// ترتيب حراسة الأوامر:
///   تحكم طبي ممنوع ← أمر لم يعلنه الجهاز ممنوع ← بيانات صحية بلا موافقة ممنوعة
///   ← التحكم يحتاج تخويلاً وقناة آمنة ← الحركة والحساس يحتاجان تأكيد المستخدم
///   (الإيقاف لا ينتظر تأكيداً). تأكيد الجهاز = acknowledged، لا succeeded.
/// =============================================================
library lifex_ai.core.device_integration.drivers.bridge_device_driver;

import 'dart:async';

import '../../connectivity/connection_device.dart';
import '../../connectivity/connection_state.dart';
import '../../connectivity/device_capability.dart';
import '../../connectivity/permission_manager.dart';
import '../../connectivity/transport_streams.dart';
import '../../device_control_center/control_types.dart';
import '../../device_drivers/device_command.dart';
import '../../device_drivers/device_event.dart';
import '../../device_drivers/device_state.dart';
import '../../device_drivers/universal_driver.dart';
import '../pipeline/device_reading.dart';
import '../pipeline/stream_data_pipeline.dart';
import '../protocols/lifex_bridge_protocol.dart';
import '../state/device_link_state.dart';

abstract class BridgeDeviceDriver implements UniversalDriver {
  BridgeDeviceDriver({
    required this.transport,
    this.pipeline,
    DeviceLinkStateStore? states,
    this.permissions,
    this.ackTimeout = const Duration(seconds: 5),
  }) : states = states ?? DeviceLinkStateStore();

  final DeviceScopedTransport transport;
  final StreamDataPipeline? pipeline;
  final DeviceLinkStateStore states;
  final PermissionManager? permissions;
  final Duration ackTimeout;

  ConnectionDevice? _device;
  StreamSubscription<TransportInbound>? _inboundSub;
  StreamSubscription<TransportStateChange>? _stateSub;
  final _events = StreamController<DeviceEvent>.broadcast();
  final _readings = StreamController<DeviceReading>.broadcast();
  final _pendingAcks = <String, Completer<Map<String, dynamic>>>{};
  int _withheld = 0;

  late final LbpCodec lbp = LbpCodec(
    transport.preservesMessageBoundaries ? LbpFraming.message : LbpFraming.lines,
  );

  ConnectionDevice? get device => _device;
  Stream<DeviceReading> get readings => _readings.stream;

  /// قراءات لم تُمرَّر لأن القراءة غير مخوَّلة.
  int get withheldReadings => _withheld;

  @override
  Stream<DeviceEvent> get events => _events.stream;

  /// القدرة التي يجب منحها للتحكم. null = جهاز للقراءة فقط.
  DeviceCapability? get controlCapability;

  /// true: القراءة والتحكم يحتاجان منحاً صريحاً في PermissionManager.
  bool get requiresExplicitGrant => true;

  /// true: لا يُرسل إلا ما أعلنه الجهاز في رسالة caps.
  bool get requiresDeclaredActions => true;

  CommandRisk riskOf(String action);

  bool isReadAction(String action) =>
      action == 'readState' || action.startsWith('READ_');

  /// البايتات الواردة من الجهاز. الافتراضي: LBP.
  void onBytes(List<int> bytes) => lbp.feed(bytes).forEach(handleLbpMessage);

  /// إرسال أمر اجتاز الحراسة. الافتراضي: LBP مع انتظار التأكيد.
  Future<CommandResult> transmit(DeviceCommand command) => transmitLbp(command);

  void resetDecoder() => lbp.reset();

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == transport.type;

  bool _allowed(ConnectionDevice device, DeviceCapability capability) {
    final p = permissions;
    if (p == null) return !requiresExplicitGrant;
    return p.allows(device, capability);
  }

  bool get readAuthorized {
    final d = _device;
    return d != null && _allowed(d, DeviceCapability.readData);
  }

  void _syncLink(ConnectionState state) {
    final d = _device;
    if (d == null) return;
    final control = controlCapability;
    states.update(
      d.id,
      (s) => s.copyWith(
        connection: state,
        secureChannel: transport.secureSession(d.id),
        readAuthorized: _allowed(d, DeviceCapability.readData),
        controlAuthorized: control != null && _allowed(d, control),
      ),
    );
  }

  Future<void> _detach() async {
    await _inboundSub?.cancel();
    await _stateSub?.cancel();
    _inboundSub = null;
    _stateSub = null;
  }

  @override
  Future<CommandResult> connect(ConnectionDevice device) async {
    if (!await detect(device)) {
      return const CommandResult(ok: false, reason: 'driver_does_not_match');
    }
    await _detach();
    _device = device;
    resetDecoder();
    _inboundSub = transport.inbound.where((m) => m.deviceId == device.id).listen(
      (m) {
        states.update(device.id, (s) => s.copyWith(lastSeen: DateTime.now()));
        onBytes(m.bytes);
      },
    );
    _stateSub = transport.stateChanges
        .where((c) => c.deviceId == device.id)
        .listen((c) => _syncLink(c.state));
    final state = await transport.connect(device);
    _syncLink(state);
    final ok = state == ConnectionState.connected;
    return CommandResult(ok: ok, reason: ok ? '' : 'connect_${state.name}');
  }

  @override
  Future<void> disconnect() async {
    final d = _device;
    if (d != null) await transport.disconnect(d);
    for (final pending in _pendingAcks.values) {
      if (!pending.isCompleted) {
        pending.complete({'ok': false, 'reason': 'disconnected'});
      }
    }
    _pendingAcks.clear();
  }

  @override
  Future<DeviceState> readState() async {
    final d = _device;
    if (d == null) return DeviceState.empty();
    final s = states.of(d.id);
    return DeviceState(
      deviceId: d.id,
      connected: s.connected,
      powered: s.connected,
      values: Map.unmodifiable(s.values),
    );
  }

  CommandResult _trace(
    DeviceCommand command,
    CommandStatus status,
    String reason, {
    bool ok = false,
    bool executed = false,
  }) {
    final d = _device;
    if (d != null) {
      states.update(
        d.id,
        (s) => s.copyWith(
          lastCommand: CommandTrace(
            commandId: command.id,
            action: command.action,
            status: status,
            reason: reason,
            at: DateTime.now(),
          ),
        ),
      );
    }
    return CommandResult(ok: ok, reason: reason, executedOnHardware: executed);
  }

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    final d = _device;
    if (d == null || d.state != ConnectionState.connected) {
      return _trace(command, CommandStatus.failed, 'not_connected');
    }
    final action = command.action;
    final risk = riskOf(action);
    final read = isReadAction(action);
    final isStop = risk == CommandRisk.emergency;
    if (risk == CommandRisk.medical || command.parameters['medicalControl'] == true) {
      return _trace(command, CommandStatus.failed, 'medicalControlForbidden');
    }
    final control = controlCapability;
    if (!read && control == null) {
      return _trace(command, CommandStatus.failed, 'read_only_device');
    }
    final declared = states.of(d.id).declaredActions;
    if (requiresDeclaredActions && !(declared?.contains(action) ?? false)) {
      return _trace(command, CommandStatus.failed, 'unsupportedCommand');
    }
    final consent = LbpMessage.healthDataRefusal(command.parameters);
    if (consent != null) {
      return _trace(command, CommandStatus.failed, consent);
    }
    if (read) {
      if (!_allowed(d, DeviceCapability.readData)) {
        return _trace(command, CommandStatus.awaitingAuthorization, 'unauthorized');
      }
    } else {
      if (!_allowed(d, control!)) {
        return _trace(command, CommandStatus.awaitingAuthorization, 'unauthorized');
      }
      if (!isStop && !transport.secureSession(d.id)) {
        return _trace(command, CommandStatus.failed, 'insecure_channel');
      }
      final needsConfirm =
          !isStop && (risk == CommandRisk.motion || risk == CommandRisk.sensitive);
      if (needsConfirm && command.parameters['userConfirmed'] != true) {
        return _trace(
          command,
          CommandStatus.awaitingConfirmation,
          'confirmation_required',
        );
      }
    }
    _trace(command, CommandStatus.sending, '');
    final result = await transmit(command);
    final status = result.ok
        ? CommandStatus.acknowledged
        : result.reason == 'no_ack'
            ? CommandStatus.timedOut
            : CommandStatus.failed;
    return _trace(
      command,
      status,
      result.reason,
      ok: result.ok,
      executed: result.executedOnHardware,
    );
  }

  Future<CommandResult> transmitLbp(DeviceCommand command) async {
    final d = _device!;
    final ack = Completer<Map<String, dynamic>>();
    _pendingAcks[command.id] = ack;
    final sent = await transport.send(d, lbp.encodeCommand(command));
    if (!sent.accepted) {
      _pendingAcks.remove(command.id);
      return CommandResult(ok: false, reason: sent.reason);
    }
    try {
      final reply = await ack.future.timeout(ackTimeout);
      final ok = reply['ok'] == true;
      return CommandResult(
        ok: ok,
        reason: ok ? 'peer_ack' : (reply['reason']?.toString() ?? 'peer_refused'),
        executedOnHardware: ok,
      );
    } on TimeoutException {
      return const CommandResult(ok: false, reason: 'no_ack');
    } finally {
      _pendingAcks.remove(command.id);
    }
  }

  void handleLbpMessage(Map<String, dynamic> message) {
    final d = _device;
    if (d == null) return;
    switch (message['t']) {
      case 'ack':
        final pending = _pendingAcks[message['id']];
        if (pending != null && !pending.isCompleted) pending.complete(message);
      case 'state':
        final values = message['values'];
        if (values is Map<String, dynamic>) mergeValues(values);
      case 'event':
        final payload = message['payload'];
        emitEvent(
          message['kind']?.toString() ?? 'event',
          payload is Map<String, dynamic> ? payload : const {},
        );
      case 'reading':
        final channel = message['channel'];
        final value = message['value'];
        if (channel is String && value != null) {
          emitReading(
            channel: channel,
            value: value,
            unit: message['unit']?.toString() ?? '',
            kind: ReadingKind.values.asNameMap()[message['kind']] ??
                ReadingKind.measurement,
            protocol: lbp.protocolName,
          );
        }
      case 'caps':
        final actions = message['actions'];
        if (actions is List) {
          states.update(
            d.id,
            (s) => s.copyWith(declaredActions: actions.whereType<String>().toSet()),
          );
        }
    }
  }

  void mergeValues(Map<String, Object?> values) {
    final d = _device;
    if (d == null) return;
    if (!readAuthorized) {
      _withheld++;
      return;
    }
    states.update(d.id, (s) => s.copyWith(values: {...s.values, ...values}));
  }

  void emitEvent(String kind, Map<String, dynamic> payload) {
    final d = _device;
    if (d == null || _events.isClosed) return;
    if (!readAuthorized) {
      _withheld++;
      return;
    }
    _events.add(DeviceEvent(
      deviceId: d.id,
      kind: kind,
      timestamp: DateTime.now(),
      payload: payload,
    ));
  }

  void emitReading({
    required String channel,
    required Object value,
    String unit = '',
    ReadingKind kind = ReadingKind.measurement,
    String protocol = '',
  }) {
    final d = _device;
    if (d == null || _readings.isClosed) return;
    if (!readAuthorized) {
      _withheld++;
      return;
    }
    final reading = DeviceReading(
      deviceId: d.id,
      channel: channel,
      value: value,
      unit: unit,
      kind: kind,
      protocol: protocol,
      secureLink: transport.secureSession(d.id),
      timestamp: DateTime.now(),
    );
    pipeline?.ingest(reading);
    _readings.add(reading);
    states.update(d.id, (s) => s.copyWith(values: {...s.values, channel: value}));
  }

  Future<void> dispose() async {
    await disconnect();
    await _detach();
    await _events.close();
    await _readings.close();
  }
}
