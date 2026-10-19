/// =============================================================
/// Lifex-AI — مركز التحكم
/// الملف: device_control_center.dart
/// لا يمنح صلاحيات لم تثبتها طبقات 41–46.
/// النجاح = نتيجة الجهاز + تحقق الحالة، لا مجرد إرسال.
/// الأتمتة لا ترفع الصلاحية. الطوارئ لا تتصل بـ 112 ولا تشغّل مضخة.
/// =============================================================
library lifex_ai.core.device_control_center.device_control_center;

import '../device_protocol/lifex_protocol.dart';
import '../device_protocol/protocol_packet.dart';
import '../device_services/device_service_registry.dart';
import '../device_services/service_record.dart';
import '../device_services/service_types.dart';
import 'command_queue.dart';
import 'control_types.dart';

class DeviceControlCenter {
  DeviceControlCenter({
    DeviceServiceRegistry? registry,
    LifexProtocol? protocol,
  })  : registry = registry ?? DeviceServiceRegistry(),
        protocol = protocol ?? LifexProtocol();

  final DeviceServiceRegistry registry;
  final LifexProtocol protocol;
  final queue = DeviceCommandQueue();
  final devices = <String, ManagedDevice>{};
  final groups = <String, DeviceGroup>{};
  final history = <ControlCommandResult>[];
  final audit = <String>[];
  final rules = <AutomationRule>[];
  final scenes = <String, ControlScene>{};

  void attachScene(ControlScene scene) {
    scenes[scene.sceneId] = scene;
  }

  void attachDevice(ManagedDevice device) {
    devices[device.deviceId] = device;
  }

  void attachGroup(DeviceGroup group) {
    groups[group.groupId] = group;
  }

  void adoptService(ServiceRecord service) {
    final d = devices.putIfAbsent(
      service.deviceId,
      () => ManagedDevice(
        deviceId: service.deviceId,
        name: service.personalLabel ?? service.deviceId,
        category: service.category.name,
      ),
    );
    if (!d.serviceIds.contains(service.serviceId)) {
      d.serviceIds = [...d.serviceIds, service.serviceId];
    }
    d.status = _statusFromService(service);
    d.authenticated = service.trusted;
    d.authorized = service.allows(AccessScope.control) ||
        service.allows(AccessScope.read);
    registry.register(service);
  }

  DeviceControlStatus _statusFromService(ServiceRecord s) {
    if (!s.connected) return DeviceControlStatus.disconnected;
    if (s.status == ServiceStatus.unauthorized) {
      return DeviceControlStatus.unavailable;
    }
    if (!s.allows(AccessScope.read) && !s.allows(AccessScope.control)) {
      return DeviceControlStatus.discovered;
    }
    if (s.status == ServiceStatus.degraded) return DeviceControlStatus.degraded;
    if (s.allows(AccessScope.stream) &&
        s.capabilities.any((c) => c.streamable)) {
      return DeviceControlStatus.authorized;
    }
    if (s.allows(AccessScope.control)) return DeviceControlStatus.authorized;
    if (s.allows(AccessScope.read)) return DeviceControlStatus.connected;
    return DeviceControlStatus.discovered;
  }

  List<DashboardTile> dashboard() {
    return devices.values.map((d) {
      final streaming = registry.all().any(
            (s) =>
                s.deviceId == d.deviceId &&
                s.capabilities.any((c) => c.streamable) &&
                s.connected,
          );
      String label;
      if (!d.authorized || d.status == DeviceControlStatus.unauthorized) {
        label = 'UNAUTHORIZED';
      } else {
        label = d.status.name.toUpperCase();
      }
      if (streaming && d.authorized) label = 'STREAMING';
      return DashboardTile(
        deviceId: d.deviceId,
        title: d.name,
        statusLabel: label,
        streaming: streaming,
      );
    }).toList();
  }

  Future<ControlCommandResult> submit(
    ControlCommand command, {
    bool userConfirmed = false,
  }) async {
    audit.add('submit:${command.commandId}:${command.action}');
    if (queue.isCancelled(command.commandId)) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.cancelled,
        reason: 'cancelled',
      ));
    }
    if (command.medicalControl || command.risk == CommandRisk.medical) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.failed,
        reason: 'medicalControlForbidden',
      ));
    }
    if (command.risk == CommandRisk.emergency &&
        command.action.toLowerCase().contains('dial')) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.failed,
        reason: 'emergency_auto_call_forbidden',
      ));
    }
    // STOP / EMERGENCY_STOP: أولوية — لا تنتظر تأكيداً.
    final isStop = command.action == 'STOP' ||
        command.action == 'EMERGENCY_STOP';
    final confirmed = userConfirmed || isStop || command.confirmed;
    final service = registry.byId(command.serviceId);
    if (service == null) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.failed,
        reason: 'service_not_in_registry',
      ));
    }
    if (!service.allows(AccessScope.control) &&
        !service.allows(AccessScope.execute)) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.awaitingAuthorization,
        reason: 'unauthorized',
      ));
    }
    if (!service.commands.any((c) => c.commandId == command.action)) {
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.failed,
        reason: 'unsupportedCommand',
      ));
    }
    final needsConfirm = !isStop &&
        (command.requiresConfirmation ||
            command.risk == CommandRisk.sensitive ||
            command.risk == CommandRisk.motion ||
            service.commands.any(
              (c) => c.commandId == command.action && c.requiresConfirmation,
            ));
    if (needsConfirm && !confirmed) {
      queue.enqueue(command);
      return _store(ControlCommandResult(
        commandId: command.commandId,
        status: CommandStatus.awaitingConfirmation,
        reason: 'confirmation_required',
      ));
    }
    queue.enqueue(command);
    return processNext(command.deviceId);
  }

  Future<ControlCommandResult> processNext(String deviceId) async {
    final cmd = queue.dequeue(deviceId);
    if (cmd == null) {
      return const ControlCommandResult(
        commandId: '',
        status: CommandStatus.failed,
        reason: 'empty_queue',
      );
    }
    if (queue.isCancelled(cmd.commandId)) {
      return _store(ControlCommandResult(
        commandId: cmd.commandId,
        status: CommandStatus.cancelled,
        reason: 'cancelled',
      ));
    }
    final proto = protocol.execute(
      CommandRequest(
        commandId: cmd.commandId,
        deviceId: cmd.deviceId,
        action: cmd.action,
        timestamp: DateTime.now(),
        idempotencyKey: cmd.commandId,
        parameters: cmd.parameters,
        medicalControl: cmd.medicalControl,
      ),
    );
    if (!proto.ok) {
      return _store(ControlCommandResult(
        commandId: cmd.commandId,
        status: CommandStatus.failed,
        reason: proto.reason,
        sentOnly: true,
        executedOnDevice: false,
      ));
    }
    if (!proto.executedOnDevice) {
      return _store(ControlCommandResult(
        commandId: cmd.commandId,
        status: CommandStatus.acknowledged,
        reason: proto.reason,
        sentOnly: true,
        executedOnDevice: false,
      ));
    }
    final snap = protocol.readState(cmd.deviceId);
    final verified = snap != null &&
        cmd.parameters.entries.every(
          (e) => snap.values[e.key] == e.value,
        );
    final device = devices[cmd.deviceId];
    if (device != null && verified) {
      device.state = {...device.state, ...cmd.parameters};
    }
    return _store(ControlCommandResult(
      commandId: cmd.commandId,
      status: verified ? CommandStatus.succeeded : CommandStatus.executing,
      ok: verified,
      executedOnDevice: true,
      stateVerified: verified,
      values: snap?.values ?? const {},
      reason: verified ? '' : 'state_unverified',
    ));
  }

  Future<ControlCommandResult> confirm(String commandId) async {
    for (final d in devices.keys) {
      final pending = queue.dequeue(d);
      if (pending != null && pending.commandId == commandId) {
        return submit(pending.copyConfirmed(), userConfirmed: true);
      }
    }
    return ControlCommandResult(
      commandId: commandId,
      status: CommandStatus.failed,
      reason: 'not_awaiting_confirmation',
    );
  }

  ControlCommandResult runAutomation(String triggerEvent) {
    AutomationRule? hit;
    for (final r in rules) {
      if (r.triggerEvent == triggerEvent) {
        hit = r;
        break;
      }
    }
    if (hit == null) {
      return const ControlCommandResult(
        commandId: '',
        status: CommandStatus.failed,
        reason: 'no_rule',
      );
    }
    if (hit.action.medicalControl || hit.action.risk == CommandRisk.medical) {
      return ControlCommandResult(
        commandId: hit.action.commandId,
        status: CommandStatus.failed,
        reason: 'automation_cannot_grant_medical_control',
      );
    }
    if (hit.action.risk == CommandRisk.sensitive && !hit.action.confirmed) {
      return ControlCommandResult(
        commandId: hit.action.commandId,
        status: CommandStatus.awaitingConfirmation,
        reason: 'automation_sensitive_needs_user',
      );
    }
    return ControlCommandResult(
      commandId: hit.action.commandId,
      status: CommandStatus.queued,
      reason: 'automation_queued_same_permissions',
    );
  }

  List<ControlCommandResult> commandGroup({
    required String groupId,
    required String action,
    Map<String, dynamic> parameters = const {},
  }) {
    final g = groups[groupId];
    if (g == null) return const [];
    final out = <ControlCommandResult>[];
    for (final id in g.deviceIds) {
      final services = registry.all().where((s) => s.deviceId == id);
      if (services.isEmpty) {
        out.add(ControlCommandResult(
          commandId: 'g_$id',
          status: CommandStatus.failed,
          reason: 'no_service',
        ));
        continue;
      }
      // لا ننفّذ هنا؛ نعيد رفضاً إن لم تُستدع submit لكل جهاز بصلاحياته.
      out.add(ControlCommandResult(
        commandId: 'g_$id',
        status: CommandStatus.validating,
        reason: 'group_does_not_bypass_device_auth',
      ));
    }
    return out;
  }

  Map<String, dynamic> emergencyNotice(String event) {
    return {
      'event': event,
      'autoDial': false,
      'medicalActuator': false,
      'reason': 'emergency_policy_observe_only',
    };
  }

  /// المشهد لا يتجاوز صلاحية أي جهاز. البدء ≠ النجاح.
  Future<SceneExecution> executeScene(
    String sceneId, {
    bool userConfirmed = false,
  }) async {
    final scene = scenes[sceneId];
    if (scene == null || scene.actions.isEmpty) {
      return SceneExecution(
        sceneId: sceneId,
        status: SceneRunStatus.invalid,
        notes: const ['validate_failed'],
      );
    }
    audit.add('scene_start:$sceneId');
    final steps = <ControlCommandResult>[];
    final notes = <String>['validated'];

    for (final step in scene.actions) {
      notes.add('check_device:${step.deviceId}');
      final service = registry.byId(step.serviceId);
      if (service == null) {
        steps.add(ControlCommandResult(
          commandId: step.actionId,
          status: CommandStatus.failed,
          reason: 'device_or_service_missing',
        ));
        continue;
      }
      if (!service.connected) {
        steps.add(ControlCommandResult(
          commandId: step.actionId,
          status: CommandStatus.failed,
          reason: 'device_not_connected',
        ));
        continue;
      }
      notes.add('check_permissions:${step.serviceId}');
      if (step.kind == SceneStepKind.observe) {
        if (!service.allows(AccessScope.read)) {
          steps.add(ControlCommandResult(
            commandId: step.actionId,
            status: CommandStatus.awaitingAuthorization,
            reason: 'unauthorized',
          ));
          continue;
        }
        steps.add(ControlCommandResult(
          commandId: step.actionId,
          status: CommandStatus.succeeded,
          ok: true,
          reason: 'observed',
          values: {
            'clinicalInterpretation': false,
            'action': step.action,
          },
        ));
        continue;
      }
      if (step.risk == CommandRisk.medical) {
        steps.add(ControlCommandResult(
          commandId: step.actionId,
          status: CommandStatus.failed,
          reason: 'medicalControlForbidden',
        ));
        continue;
      }
      final result = await submit(
        ControlCommand(
          commandId: '${scene.sceneId}_${step.actionId}',
          deviceId: step.deviceId,
          serviceId: step.serviceId,
          action: step.action,
          parameters: step.parameters,
          risk: step.risk,
          requiresConfirmation: step.risk == CommandRisk.sensitive,
        ),
        userConfirmed: userConfirmed,
      );
      steps.add(result);
    }

    final okCount = steps.where((s) => s.ok).length;
    SceneRunStatus status;
    if (okCount == 0) {
      status = SceneRunStatus.failed;
    } else if (okCount == steps.length) {
      status = SceneRunStatus.succeeded;
    } else {
      status = SceneRunStatus.partial;
    }
    return SceneExecution(
      sceneId: scene.sceneId,
      status: status,
      steps: steps,
      notes: notes,
    );
  }

  ControlCommandResult _store(ControlCommandResult r) {
    history.add(r);
    return r;
  }
}
