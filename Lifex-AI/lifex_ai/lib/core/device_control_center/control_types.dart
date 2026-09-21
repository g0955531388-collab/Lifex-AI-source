/// =============================================================
/// Lifex-AI — مركز التحكم
/// الملف: control_types.dart
/// المركز لا يمنح صلاحيات جديدة.
/// =============================================================
library lifex_ai.core.device_control_center.control_types;

enum DeviceControlStatus {
  unknown,
  discovered,
  connecting,
  connected,
  authenticated,
  authorized,
  partiallyAvailable,
  busy,
  degraded,
  unavailable,
  unauthorized,
  disconnected,
  error,
}

enum CommandStatus {
  queued,
  validating,
  awaitingAuthorization,
  awaitingConfirmation,
  sending,
  acknowledged,
  executing,
  succeeded,
  failed,
  cancelled,
  timedOut,
}

enum CommandRisk {
  low,
  /// حركة مساعدة — تتطلب تأكيداً وحالة سلامة.
  motion,
  sensitive,
  medical,
  emergency,
}

class ControlCommand {
  const ControlCommand({
    required this.commandId,
    required this.deviceId,
    required this.serviceId,
    required this.action,
    this.parameters = const {},
    this.requiresConfirmation = false,
    this.confirmed = false,
    this.medicalControl = false,
    this.risk = CommandRisk.low,
  });

  final String commandId;
  final String deviceId;
  final String serviceId;
  final String action;
  final Map<String, dynamic> parameters;
  final bool requiresConfirmation;
  final bool confirmed;
  final bool medicalControl;
  final CommandRisk risk;

  ControlCommand copyConfirmed() => ControlCommand(
        commandId: commandId,
        deviceId: deviceId,
        serviceId: serviceId,
        action: action,
        parameters: parameters,
        requiresConfirmation: requiresConfirmation,
        confirmed: true,
        medicalControl: medicalControl,
        risk: risk,
      );
}

class ControlCommandResult {
  const ControlCommandResult({
    required this.commandId,
    required this.status,
    this.ok = false,
    this.reason = '',
    this.sentOnly = false,
    this.executedOnDevice = false,
    this.stateVerified = false,
    this.values = const {},
  });

  final String commandId;
  final CommandStatus status;
  final bool ok;
  final String reason;
  /// إرسال الحزمة وحده ليس نجاحاً.
  final bool sentOnly;
  final bool executedOnDevice;
  final bool stateVerified;
  final Map<String, dynamic> values;
}

class ManagedDevice {
  ManagedDevice({
    required this.deviceId,
    required this.name,
    required this.category,
    this.status = DeviceControlStatus.unknown,
    this.authenticated = false,
    this.authorized = false,
    this.serviceIds = const [],
    this.state = const {},
  });

  final String deviceId;
  final String name;
  final String category;
  DeviceControlStatus status;
  bool authenticated;
  bool authorized;
  List<String> serviceIds;
  Map<String, dynamic> state;

  bool get controllable =>
      authorized && status != DeviceControlStatus.unauthorized;
}

class DeviceGroup {
  const DeviceGroup({
    required this.groupId,
    required this.name,
    this.deviceIds = const [],
  });

  final String groupId;
  final String name;
  final List<String> deviceIds;
}

class DashboardTile {
  const DashboardTile({
    required this.deviceId,
    required this.title,
    required this.statusLabel,
    this.streaming = false,
  });

  final String deviceId;
  final String title;
  final String statusLabel;
  final bool streaming;
}

class AutomationRule {
  const AutomationRule({
    required this.ruleId,
    required this.triggerEvent,
    required this.action,
  });

  final String ruleId;
  final String triggerEvent;
  final ControlCommand action;
}

enum SceneStepKind { command, observe }

enum SceneRunStatus {
  invalid,
  blocked,
  running,
  partial,
  succeeded,
  failed,
}

class SceneAction {
  const SceneAction({
    required this.actionId,
    required this.deviceId,
    required this.serviceId,
    required this.action,
    this.parameters = const {},
    this.kind = SceneStepKind.command,
    this.risk = CommandRisk.low,
  });

  final String actionId;
  final String deviceId;
  final String serviceId;
  final String action;
  final Map<String, dynamic> parameters;
  final SceneStepKind kind;
  final CommandRisk risk;
}

class ControlScene {
  const ControlScene({
    required this.sceneId,
    required this.name,
    this.actions = const [],
  });

  final String sceneId;
  final String name;
  final List<SceneAction> actions;
}

class SceneExecution {
  const SceneExecution({
    required this.sceneId,
    required this.status,
    this.steps = const [],
    this.notes = const [],
  });

  final String sceneId;
  final SceneRunStatus status;
  final List<ControlCommandResult> steps;
  final List<String> notes;

  bool get startedDoesNotMeanSucceeded => status != SceneRunStatus.succeeded;
}
