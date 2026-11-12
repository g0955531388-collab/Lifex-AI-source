/// =============================================================
/// Lifex-AI — أتمتة أجهزة
/// الملف: automation_types.dart
/// الأتمتة لا تتجاوز الصلاحية أو البروتوكول. القراءة ≠ التحكّم.
/// =============================================================
library lifex_ai.core.device_automation.automation_types;

enum AutomationTriggerType {
  deviceEvent,
  stateChanged,
  serviceAvailable,
  connectionChanged,
  schedule,
  timer,
  locationChanged,
  manual,
  workflowCompleted,
}

enum TriggerOperator { and, or, sequence }

enum ConditionOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterOrEqual,
  lessOrEqual,
  contains,
  exists,
  changed,
  increased,
  decreased,
}

enum AutomationActionType {
  executeCommand,
  readState,
  subscribe,
  notify,
  runScene,
  runWorkflow,
  wait,
  conditional,
  enableRule,
  disableRule,
}

enum ActionRisk {
  informational,
  low,
  moderate,
  high,
  critical,
}

enum RetrySafety { safe, conditional, forbidden }

enum AutomationExecutionState {
  pending,
  running,
  waiting,
  paused,
  succeeded,
  partiallySucceeded,
  failed,
  cancelled,
  timedOut,
  blocked,
}

class AutomationTrigger {
  const AutomationTrigger({
    required this.type,
    this.eventName = '',
    this.deviceId = '',
  });

  final AutomationTriggerType type;
  final String eventName;
  final String deviceId;
}

class CompositeTrigger {
  const CompositeTrigger({
    required this.triggers,
    this.operator = TriggerOperator.and,
  });

  final List<AutomationTrigger> triggers;
  final TriggerOperator operator;
}

class AutomationCondition {
  const AutomationCondition({
    required this.key,
    required this.operator,
    this.value,
  });

  final String key;
  final ConditionOperator operator;
  final Object? value;
}

class AutomationAction {
  const AutomationAction({
    required this.type,
    this.deviceId = '',
    this.serviceId = '',
    this.command = '',
    this.parameters = const {},
    this.risk = ActionRisk.low,
    this.retrySafety = RetrySafety.conditional,
    this.compensationSupported = false,
    this.medicalControl = false,
  });

  final AutomationActionType type;
  final String deviceId;
  final String serviceId;
  final String command;
  final Map<String, dynamic> parameters;
  final ActionRisk risk;
  final RetrySafety retrySafety;
  final bool compensationSupported;
  final bool medicalControl;
}

class DeviceAutomationRule {
  const DeviceAutomationRule({
    required this.ruleId,
    required this.name,
    required this.trigger,
    this.conditions = const [],
    this.actions = const [],
    this.enabled = true,
    this.priority = 0,
    this.composite,
  });

  final String ruleId;
  final String name;
  final AutomationTrigger trigger;
  final CompositeTrigger? composite;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final bool enabled;
  final int priority;
}

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.exponentialBackoff = true,
  });

  final int maxAttempts;
  final Duration delay;
  final bool exponentialBackoff;
}

class AutomationContext {
  AutomationContext({
    required this.executionId,
    required this.startedAt,
    this.variables = const {},
    this.chain = const [],
  });

  final String executionId;
  final DateTime startedAt;
  Map<String, dynamic> variables;
  List<String> chain;
}

class AutomationExecutionResult {
  const AutomationExecutionResult({
    required this.executionId,
    required this.ruleId,
    required this.state,
    this.dryRun = false,
    this.affectedDevices = 0,
    this.actionCount = 0,
    this.unsupported = 0,
    this.permissionErrors = 0,
    this.notes = const [],
    this.stepReasons = const [],
  });

  final String executionId;
  final String ruleId;
  final AutomationExecutionState state;
  final bool dryRun;
  final int affectedDevices;
  final int actionCount;
  final int unsupported;
  final int permissionErrors;
  final List<String> notes;
  final List<String> stepReasons;
}

class IncomingDeviceEvent {
  const IncomingDeviceEvent({
    required this.eventId,
    required this.name,
    this.deviceId = '',
    this.at,
    this.payload = const {},
  });

  final String eventId;
  final String name;
  final String deviceId;
  final DateTime? at;
  final Map<String, dynamic> payload;
}
