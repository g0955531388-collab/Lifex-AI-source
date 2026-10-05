/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_automation_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_automation/automation_engine.dart';
import 'package:lifex_ai/core/device_automation/automation_types.dart';
import 'package:lifex_ai/core/device_control_center/device_control_center.dart';
import 'package:lifex_ai/core/device_services/service_record.dart';
import 'package:lifex_ai/core/device_services/service_types.dart';

void main() {
  DeviceAutomationRule nightLight() => const DeviceAutomationRule(
        ruleId: 'night_light',
        name: 'Night door light',
        trigger: AutomationTrigger(
          type: AutomationTriggerType.deviceEvent,
          eventName: 'DOOR_OPEN',
          deviceId: 'door',
        ),
        conditions: [
          AutomationCondition(
            key: 'period',
            operator: ConditionOperator.equals,
            value: 'night',
          ),
        ],
        actions: [
          AutomationAction(
            type: AutomationActionType.executeCommand,
            deviceId: 'light',
            serviceId: 'light.main',
            command: 'POWER_ON',
          ),
        ],
      );

  test('door open at night dry-run does not send commands', () async {
    final center = DeviceControlCenter();
    center.adoptService(
      ServiceRecord(
        serviceId: 'light.main',
        deviceId: 'light',
        name: 'Light',
        category: ServiceCategory.homeAutomation,
        connected: true,
        trusted: true,
        status: ServiceStatus.available,
        authorizedScopes: {AccessScope.control},
        commands: const [
          CommandDefinition(commandId: 'POWER_ON', serviceId: 'light.main'),
        ],
      ),
    );
    final engine = AutomationEngine(control: center);
    engine.registerRule(nightLight());
    final dry = await engine.handleEvent(
      const IncomingDeviceEvent(
        eventId: 'e1',
        name: 'DOOR_OPEN',
        deviceId: 'door',
      ),
      variables: {'period': 'night'},
      dryRun: true,
    );
    expect(dry.dryRun, isTrue);
    expect(dry.notes, contains('dry_run_no_device_commands'));
    expect(dry.stepReasons, contains('dry_would_submit'));
    expect(center.history, isEmpty);
  });

  test('conditions false stops; medical control blocked; duplicate events ignored',
      () async {
    final engine = AutomationEngine();
    engine.registerRule(nightLight());
    final stopped = await engine.handleEvent(
      const IncomingDeviceEvent(
        eventId: 'e2',
        name: 'DOOR_OPEN',
        deviceId: 'door',
      ),
      variables: {'period': 'day'},
    );
    expect(stopped.notes, contains('conditions_false'));

    engine.registerRule(
      const DeviceAutomationRule(
        ruleId: 'ecg',
        name: 'ecg',
        trigger: AutomationTrigger(
          type: AutomationTriggerType.deviceEvent,
          eventName: 'ECG',
        ),
        actions: [
          AutomationAction(
            type: AutomationActionType.executeCommand,
            medicalControl: true,
            command: 'CHANGE_SETTING',
            serviceId: 'ecg.s',
            deviceId: 'mon',
          ),
        ],
      ),
    );
    final med = await engine.executeRule('ecg');
    expect(med.stepReasons, contains('medical_or_critical_blocked'));

    final a = await engine.handleEvent(
      IncomingDeviceEvent(
        eventId: 'same',
        name: 'DOOR_OPEN',
        deviceId: 'door',
        at: DateTime(2026, 9, 18, 22),
      ),
      variables: const {'period': 'night'},
    );
    final b = await engine.handleEvent(
      IncomingDeviceEvent(
        eventId: 'same',
        name: 'DOOR_OPEN',
        deviceId: 'door',
        at: DateTime(2026, 9, 18, 22, 0, 1),
      ),
      variables: const {'period': 'night'},
    );
    expect(a.notes.contains('deduplicated'), isFalse);
    expect(b.notes, contains('deduplicated'));
  });

  test('loop detection when rule already in chain', () async {
    final engine = AutomationEngine();
    engine.registerRule(nightLight());
    final r = await engine.executeRule(
      'night_light',
      variables: {'period': 'night'},
      chain: ['night_light'],
    );
    expect(r.notes, contains('loop_detected'));
  });

  test('temperature condition and pause/resume context', () async {
    final engine = AutomationEngine();
    engine.registerRule(
      const DeviceAutomationRule(
        ruleId: 'ac',
        name: 'ac',
        trigger: AutomationTrigger(
          type: AutomationTriggerType.stateChanged,
          eventName: 'TEMP',
        ),
        conditions: [
          AutomationCondition(
            key: 'temperature',
            operator: ConditionOperator.greaterThan,
            value: 28,
          ),
          AutomationCondition(
            key: 'ac',
            operator: ConditionOperator.equals,
            value: 'off',
          ),
        ],
        actions: [
          AutomationAction(type: AutomationActionType.notify),
        ],
      ),
    );
    final r = await engine.handleEvent(
      const IncomingDeviceEvent(eventId: 't1', name: 'TEMP'),
      variables: {'temperature': 29, 'ac': 'off'},
    );
    expect(r.state, AutomationExecutionState.succeeded);
    engine.pause(
      r.executionId,
      AutomationContext(
        executionId: r.executionId,
        startedAt: DateTime.now(),
        variables: {'temperature': 29},
      ),
    );
    expect(engine.resume(r.executionId)!.variables['temperature'], 29);
  });
}
