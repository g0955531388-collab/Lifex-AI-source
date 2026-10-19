/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_control_center_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_control_center/control_types.dart';
import 'package:lifex_ai/core/device_control_center/device_control_center.dart';
import 'package:lifex_ai/core/device_protocol/lifex_protocol.dart';
import 'package:lifex_ai/core/device_protocol/packet_type.dart';
import 'package:lifex_ai/core/device_protocol/protocol_packet.dart';
import 'package:lifex_ai/core/device_services/service_record.dart';
import 'package:lifex_ai/core/device_services/service_types.dart';

void main() {
  LifexProtocol readyTv() {
    final p = LifexProtocol();
    p.identify('tv', caps: const [
      CapabilityDescriptor(
        id: 'volume',
        name: 'volume',
        category: 'audio',
        controllable: true,
        commands: ['SET_VOLUME'],
      ),
    ]);
    p.connect('tv');
    p.authenticate('tv', credentialsOk: true);
    p.authorize('tv', scopes: {PermissionScope.read});
    p.grantControl('tv', scopes: {PermissionScope.control});
    return p;
  }

  ServiceRecord tvService() => ServiceRecord(
        serviceId: 'tv.media',
        deviceId: 'tv',
        name: 'TV',
        category: ServiceCategory.display,
        status: ServiceStatus.available,
        connected: true,
        trusted: true,
        authorizedScopes: {AccessScope.control, AccessScope.read},
        commands: const [
          CommandDefinition(commandId: 'SET_VOLUME', serviceId: 'tv.media'),
          CommandDefinition(
            commandId: 'POWER_OFF',
            serviceId: 'tv.media',
            requiresConfirmation: true,
          ),
        ],
      );

  test('unauthorized device appears but cannot execute', () async {
    final c = DeviceControlCenter();
    c.adoptService(
      ServiceRecord(
        serviceId: 'car.nav',
        deviceId: 'car',
        name: 'سيارة',
        category: ServiceCategory.vehicle,
        connected: true,
        status: ServiceStatus.available,
        trusted: true,
      ),
    );
    c.attachDevice(
      ManagedDevice(
        deviceId: 'car',
        name: 'السيارة',
        category: 'vehicle',
        status: DeviceControlStatus.discovered,
        authorized: false,
      ),
    );
    expect(c.dashboard().any((t) => t.statusLabel == 'UNAUTHORIZED'), isTrue);
    final r = await c.submit(
      const ControlCommand(
        commandId: '1',
        deviceId: 'car',
        serviceId: 'car.nav',
        action: 'START',
      ),
    );
    expect(r.status, CommandStatus.awaitingAuthorization);
  });

  test('success requires device execution and state verify not send-only', () async {
    final c = DeviceControlCenter(protocol: readyTv());
    c.adoptService(tvService());
    final r = await c.submit(
      const ControlCommand(
        commandId: 'v1',
        deviceId: 'tv',
        serviceId: 'tv.media',
        action: 'SET_VOLUME',
        parameters: {'volume': 35},
      ),
    );
    expect(r.ok, isTrue);
    expect(r.sentOnly, isFalse);
    expect(r.executedOnDevice, isTrue);
    expect(r.stateVerified, isTrue);
    expect(r.status, CommandStatus.succeeded);
  });

  test('sensitive command waits for confirmation', () async {
    final c = DeviceControlCenter(protocol: readyTv());
    c.adoptService(tvService());
    final r = await c.submit(
      const ControlCommand(
        commandId: 'off1',
        deviceId: 'tv',
        serviceId: 'tv.media',
        action: 'POWER_OFF',
        risk: CommandRisk.sensitive,
        requiresConfirmation: true,
      ),
    );
    expect(r.status, CommandStatus.awaitingConfirmation);
  });

  test('medical and emergency auto-dial blocked; automation cannot escalate', () async {
    final c = DeviceControlCenter();
    c.adoptService(tvService());
    final med = await c.submit(
      const ControlCommand(
        commandId: 'm1',
        deviceId: 'pump',
        serviceId: 'tv.media',
        action: 'SET_VOLUME',
        medicalControl: true,
      ),
    );
    expect(med.reason, 'medicalControlForbidden');
    expect(
      c.emergencyNotice('fall')['autoDial'],
      isFalse,
    );
    c.rules.add(
      AutomationRule(
        ruleId: 'a1',
        triggerEvent: 'night',
        action: const ControlCommand(
          commandId: 'a',
          deviceId: 'pump',
          serviceId: 'infusion',
          action: 'START',
          medicalControl: true,
        ),
      ),
    );
    expect(
      c.runAutomation('night').reason,
      'automation_cannot_grant_medical_control',
    );
  });

  test('group command does not bypass per-device auth', () {
    final c = DeviceControlCenter();
    c.attachGroup(
      const DeviceGroup(groupId: 'home', name: 'HOME', deviceIds: ['tv', 'light']),
    );
    final g = c.commandGroup(groupId: 'home', action: 'POWER_OFF');
    expect(g.every((x) => x.reason.contains('bypass') || x.reason == 'no_service'), isTrue);
  });

  test('HOME_SLEEP scene validates then runs each step with own permissions', () async {
    final p = LifexProtocol();
    for (final id in ['tv', 'ac']) {
      p.identify(id, caps: [
        CapabilityDescriptor(
          id: 'ctrl',
          name: 'ctrl',
          category: 'home',
          controllable: true,
          commands: id == 'tv' ? const ['SET_VOLUME'] : const ['SET_TEMP'],
        ),
      ]);
      p.connect(id);
      p.authenticate(id, credentialsOk: true);
      p.authorize(id, scopes: {PermissionScope.read});
      p.grantControl(id, scopes: {PermissionScope.control});
    }
    final c = DeviceControlCenter(protocol: p);
    c.adoptService(tvService());
    c.adoptService(
      ServiceRecord(
        serviceId: 'ac.climate',
        deviceId: 'ac',
        name: 'AC',
        category: ServiceCategory.homeAutomation,
        connected: true,
        trusted: true,
        status: ServiceStatus.available,
        authorizedScopes: {AccessScope.control, AccessScope.read},
        commands: const [
          CommandDefinition(commandId: 'SET_TEMP', serviceId: 'ac.climate'),
        ],
      ),
    );
    c.adoptService(
      ServiceRecord(
        serviceId: 'door.lock',
        deviceId: 'door',
        name: 'Door',
        category: ServiceCategory.security,
        connected: true,
        trusted: true,
        status: ServiceStatus.available,
        authorizedScopes: {AccessScope.read},
      ),
    );
    c.adoptService(
      ServiceRecord(
        serviceId: 'sec.arm',
        deviceId: 'security',
        name: 'Security',
        category: ServiceCategory.security,
        connected: true,
        trusted: true,
        status: ServiceStatus.available,
      ),
    );
    c.attachScene(
      const ControlScene(
        sceneId: 'HOME_SLEEP',
        name: 'HOME_SLEEP',
        actions: [
          SceneAction(
            actionId: 'tv_off',
            deviceId: 'tv',
            serviceId: 'tv.media',
            action: 'SET_VOLUME',
            parameters: {'volume': 0},
          ),
          SceneAction(
            actionId: 'lights_off',
            deviceId: 'lights',
            serviceId: 'lights.main',
            action: 'POWER_OFF',
          ),
          SceneAction(
            actionId: 'ac_set',
            deviceId: 'ac',
            serviceId: 'ac.climate',
            action: 'SET_TEMP',
            parameters: {'temp': 24},
          ),
          SceneAction(
            actionId: 'door_check',
            deviceId: 'door',
            serviceId: 'door.lock',
            action: 'CHECK',
            kind: SceneStepKind.observe,
          ),
          SceneAction(
            actionId: 'sec_arm',
            deviceId: 'security',
            serviceId: 'sec.arm',
            action: 'ARM',
            risk: CommandRisk.sensitive,
          ),
        ],
      ),
    );
    final run = await c.executeScene('HOME_SLEEP');
    expect(run.notes.first, 'validated');
    expect(run.status, SceneRunStatus.partial);
    expect(run.startedDoesNotMeanSucceeded, isTrue);
    expect(run.steps.where((s) => s.ok).length, 3);
    expect(
      run.steps.firstWhere((s) => s.commandId.endsWith('tv_off') || s.commandId == 'HOME_SLEEP_tv_off').ok,
      isTrue,
    );
    expect(
      run.steps.firstWhere((s) => s.commandId == 'lights_off').reason,
      'device_or_service_missing',
    );
    expect(
      run.steps.firstWhere((s) => s.commandId == 'door_check').reason,
      'observed',
    );
    expect(
      run.steps.firstWhere((s) => s.commandId == 'HOME_SLEEP_sec_arm' || s.commandId == 'sec_arm').reason,
      'unauthorized',
    );
  });

  test('empty scene is invalid not successful', () async {
    final c = DeviceControlCenter();
    c.attachScene(const ControlScene(sceneId: 'EMPTY', name: 'EMPTY'));
    final run = await c.executeScene('EMPTY');
    expect(run.status, SceneRunStatus.invalid);
  });
}
