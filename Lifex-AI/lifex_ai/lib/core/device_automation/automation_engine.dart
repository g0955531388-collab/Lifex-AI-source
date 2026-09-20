/// =============================================================
/// Lifex-AI — أتمتة أجهزة
/// الملف: automation_engine.dart
/// لا تتجاوز الصلاحية. لا تحكّم طبي تلقائي. dry-run بلا أوامر.
/// =============================================================
library lifex_ai.core.device_automation.automation_engine;

import '../device_control_center/control_types.dart';
import '../device_control_center/device_control_center.dart';
import '../device_services/service_types.dart';
import 'automation_types.dart';

class AutomationEngine {
  AutomationEngine({DeviceControlCenter? control})
      : control = control ?? DeviceControlCenter();

  final DeviceControlCenter control;
  final rules = <String, DeviceAutomationRule>{};
  final history = <AutomationExecutionResult>[];
  final _seenEvents = <String, DateTime>{};
  final _execCounts = <String, List<DateTime>>{};
  final _paused = <String, AutomationContext>{};
  static const dedupWindow = Duration(seconds: 2);
  static const maxPerMinute = 8;
  static const maxChain = 4;

  void registerRule(DeviceAutomationRule rule) => rules[rule.ruleId] = rule;

  void removeRule(String ruleId) => rules.remove(ruleId);

  DeviceAutomationRule? _copyEnabled(DeviceAutomationRule r, bool enabled) {
    return DeviceAutomationRule(
      ruleId: r.ruleId,
      name: r.name,
      trigger: r.trigger,
      composite: r.composite,
      conditions: r.conditions,
      actions: r.actions,
      enabled: enabled,
      priority: r.priority,
    );
  }

  void enableRule(String ruleId) {
    final r = rules[ruleId];
    if (r != null) rules[ruleId] = _copyEnabled(r, true)!;
  }

  void disableRule(String ruleId) {
    final r = rules[ruleId];
    if (r != null) rules[ruleId] = _copyEnabled(r, false)!;
  }

  bool conditionsHold(
    List<AutomationCondition> conditions,
    Map<String, dynamic> vars,
  ) {
    for (final c in conditions) {
      if (!_one(c, vars)) return false;
    }
    return true;
  }

  bool _one(AutomationCondition c, Map<String, dynamic> vars) {
    final left = vars[c.key];
    switch (c.operator) {
      case ConditionOperator.exists:
        return left != null;
      case ConditionOperator.equals:
        return left == c.value;
      case ConditionOperator.notEquals:
        return left != c.value;
      case ConditionOperator.contains:
        return left is String &&
            c.value is String &&
            left.contains(c.value! as String);
      case ConditionOperator.greaterThan:
        return left is num && c.value is num && left > (c.value! as num);
      case ConditionOperator.lessThan:
        return left is num && c.value is num && left < (c.value! as num);
      case ConditionOperator.greaterOrEqual:
        return left is num && c.value is num && left >= (c.value! as num);
      case ConditionOperator.lessOrEqual:
        return left is num && c.value is num && left <= (c.value! as num);
      case ConditionOperator.changed:
      case ConditionOperator.increased:
      case ConditionOperator.decreased:
        return vars['${c.key}_delta'] == true;
    }
  }

  Future<AutomationExecutionResult> handleEvent(
    IncomingDeviceEvent event, {
    Map<String, dynamic> variables = const {},
    List<String> chain = const [],
    bool dryRun = false,
  }) async {
    final now = event.at ?? DateTime.now();
    final last = _seenEvents[event.eventId];
    if (last != null && now.difference(last) < dedupWindow) {
      return const AutomationExecutionResult(
        executionId: 'dedup',
        ruleId: '',
        state: AutomationExecutionState.blocked,
        notes: ['deduplicated'],
      );
    }
    _seenEvents[event.eventId] = now;

    final matches = rules.values.where((r) {
      if (!r.enabled) return false;
      if (r.trigger.eventName.isNotEmpty && r.trigger.eventName != event.name) {
        return false;
      }
      if (r.trigger.deviceId.isNotEmpty && r.trigger.deviceId != event.deviceId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (matches.isEmpty) {
      return const AutomationExecutionResult(
        executionId: '',
        ruleId: '',
        state: AutomationExecutionState.blocked,
        notes: ['no_rule'],
      );
    }
    return executeRule(
      matches.first.ruleId,
      variables: {...event.payload, ...variables},
      chain: chain,
      dryRun: dryRun,
    );
  }

  Future<AutomationExecutionResult> dryRun(String ruleId) {
    return executeRule(ruleId, dryRun: true);
  }

  Future<AutomationExecutionResult> executeRule(
    String ruleId, {
    Map<String, dynamic> variables = const {},
    List<String> chain = const [],
    bool dryRun = false,
  }) async {
    final rule = rules[ruleId];
    final executionId = 'ax_${DateTime.now().microsecondsSinceEpoch}';
    if (rule == null || !rule.enabled) {
      return AutomationExecutionResult(
        executionId: executionId,
        ruleId: ruleId,
        state: AutomationExecutionState.blocked,
        notes: const ['rule_disabled_or_missing'],
      );
    }
    if (chain.contains(ruleId) || chain.length >= maxChain) {
      return AutomationExecutionResult(
        executionId: executionId,
        ruleId: ruleId,
        state: AutomationExecutionState.blocked,
        notes: const ['loop_detected'],
      );
    }
    final window = DateTime.now().subtract(const Duration(minutes: 1));
    final stamps =
        (_execCounts[ruleId] ?? []).where((t) => t.isAfter(window)).toList();
    if (stamps.length >= maxPerMinute) {
      return AutomationExecutionResult(
        executionId: executionId,
        ruleId: ruleId,
        state: AutomationExecutionState.blocked,
        notes: const ['rate_limited'],
      );
    }
    if (!conditionsHold(rule.conditions, variables)) {
      return AutomationExecutionResult(
        executionId: executionId,
        ruleId: ruleId,
        state: AutomationExecutionState.blocked,
        notes: const ['conditions_false'],
      );
    }

    _execCounts[ruleId] = [...stamps, DateTime.now()];
    var unsupported = 0;
    var permissionErrors = 0;
    var ok = 0;
    final reasons = <String>[];
    final devices = <String>{};
    final nextChain = [...chain, ruleId];

    for (final action in rule.actions) {
      if (action.deviceId.isNotEmpty) devices.add(action.deviceId);
      if (action.medicalControl || action.risk == ActionRisk.critical) {
        permissionErrors++;
        reasons.add('medical_or_critical_blocked');
        continue;
      }
      if (action.type == AutomationActionType.notify) {
        ok++;
        reasons.add(dryRun ? 'notify_simulated' : 'notify');
        continue;
      }
      if (action.type == AutomationActionType.readState) {
        if (control.registry.byId(action.serviceId) == null) {
          unsupported++;
          reasons.add('service_missing');
          continue;
        }
        ok++;
        reasons.add(dryRun ? 'read_simulated' : 'read');
        continue;
      }
      if (action.type == AutomationActionType.runScene) {
        if (dryRun) {
          ok++;
          reasons.add('scene_dry');
          continue;
        }
        final scene = await control.executeScene(action.command);
        reasons.add(scene.status.name);
        if (scene.status == SceneRunStatus.succeeded) ok++;
        continue;
      }
      if (action.type == AutomationActionType.enableRule &&
          action.command.isNotEmpty) {
        if (nextChain.contains(action.command)) {
          reasons.add('loop_detected');
          continue;
        }
        if (!dryRun) enableRule(action.command);
        ok++;
        continue;
      }
      if (action.type != AutomationActionType.executeCommand) {
        reasons.add('skipped:${action.type.name}');
        continue;
      }
      if (action.risk == ActionRisk.high && !dryRun) {
        permissionErrors++;
        reasons.add('high_needs_confirmation');
        continue;
      }
      final svc = control.registry.byId(action.serviceId);
      if (svc == null) {
        unsupported++;
        reasons.add('unsupported_or_missing');
        continue;
      }
      if (!svc.commands.any((c) => c.commandId == action.command)) {
        unsupported++;
        reasons.add('unsupportedCommand');
        continue;
      }
      if (!svc.allows(AccessScope.control) && !svc.allows(AccessScope.execute)) {
        permissionErrors++;
        reasons.add('unauthorized');
        continue;
      }
      if (dryRun) {
        ok++;
        reasons.add('dry_would_submit');
        continue;
      }
      if (action.retrySafety == RetrySafety.forbidden) {
        // تنفيذ مرة واحدة فقط؛ لا إعادة تلقائية بعد الفشل.
      }
      final result = await control.submit(
        ControlCommand(
          commandId: '${executionId}_${action.command}',
          deviceId: action.deviceId,
          serviceId: action.serviceId,
          action: action.command,
          parameters: action.parameters,
          medicalControl: false,
        ),
      );
      reasons.add(result.reason.isEmpty ? result.status.name : result.reason);
      if (result.ok) {
        ok++;
      } else if (result.reason.contains('unauthorized')) {
        permissionErrors++;
      } else if (result.reason == 'unsupportedCommand') {
        unsupported++;
      }
    }

    AutomationExecutionState state;
    if (ok == rule.actions.length && rule.actions.isNotEmpty) {
      state = AutomationExecutionState.succeeded;
    } else if (ok > 0) {
      state = AutomationExecutionState.partiallySucceeded;
    } else {
      state = AutomationExecutionState.failed;
    }

    final out = AutomationExecutionResult(
      executionId: executionId,
      ruleId: ruleId,
      state: state,
      dryRun: dryRun,
      affectedDevices: devices.length,
      actionCount: rule.actions.length,
      unsupported: unsupported,
      permissionErrors: permissionErrors,
      notes: dryRun ? const ['dry_run_no_device_commands'] : const [],
      stepReasons: reasons,
    );
    history.add(out);
    return out;
  }

  void pause(String executionId, AutomationContext ctx) {
    _paused[executionId] = ctx;
  }

  AutomationContext? resume(String executionId) => _paused.remove(executionId);
}
