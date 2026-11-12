/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_service_registry_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_services/device_service_registry.dart';
import 'package:lifex_ai/core/device_services/service_record.dart';
import 'package:lifex_ai/core/device_services/service_types.dart';
import 'package:lifex_ai/core/device_services/virtual_service.dart';

void main() {
  test('alias pulse maps to HEART_RATE and listing is not permission', () {
    final r = DeviceServiceRegistry();
    r.register(
      ServiceRecord(
        serviceId: 'w.hr',
        deviceId: 'watch',
        name: 'pulse',
        category: ServiceCategory.sensor,
        status: ServiceStatus.available,
        connected: true,
        trusted: true,
        capabilities: const [
          CapabilityRecord(
            universalId: 'HEART_RATE',
            nativeId: 'pulse',
            deviceId: 'watch',
            serviceId: 'w.hr',
            readable: true,
          ),
        ],
      ),
    );
    final listed = r.query(
      const CapabilityQuery(capability: 'hr', requireRead: true),
    );
    expect(listed, isNotEmpty);
    expect(listed.first.usable, isFalse);
    expect(listed.first.exclusionReason, 'no_read_permission');
  });

  test('read query prefers connected authorized source technically not medically', () {
    final r = DeviceServiceRegistry();
    r.register(
      ServiceRecord(
        serviceId: 'virt.spo2',
        deviceId: 'v',
        name: 'SpO2',
        category: ServiceCategory.medical,
        status: ServiceStatus.available,
        connected: true,
        trusted: true,
        virtual: true,
        dataQuality: DataQuality.good,
        latencyMs: 80,
        authorizedScopes: {AccessScope.read},
        capabilities: const [
          CapabilityRecord(
            universalId: 'OXYGEN_SATURATION',
            nativeId: 'spo2',
            deviceId: 'v',
            serviceId: 'virt.spo2',
            readable: true,
          ),
        ],
      ),
    );
    r.register(
      ServiceRecord(
        serviceId: 'mon.spo2',
        deviceId: 'mon',
        name: 'SpO2',
        category: ServiceCategory.medical,
        status: ServiceStatus.available,
        connected: true,
        trusted: true,
        dataQuality: DataQuality.good,
        latencyMs: 10,
        authorizedScopes: {AccessScope.read},
        capabilities: const [
          CapabilityRecord(
            universalId: 'OXYGEN_SATURATION',
            nativeId: 'spo2',
            deviceId: 'mon',
            serviceId: 'mon.spo2',
            readable: true,
          ),
        ],
      ),
    );
    final usable = r.findUsable(
      const CapabilityQuery(capability: 'oxygenSaturation', requireRead: true),
    );
    expect(usable.first.deviceId, 'mon');
    expect(usable.first.virtual, isFalse);
  });

  test('router cannot execute without command and control scope', () {
    final r = DeviceServiceRegistry();
    final tv = ServiceRecord(
      serviceId: 'tv.media',
      deviceId: 'tv',
      name: 'TV',
      category: ServiceCategory.display,
      status: ServiceStatus.available,
      connected: true,
      trusted: true,
      authorizedScopes: {AccessScope.read},
      capabilities: const [
        CapabilityRecord(
          universalId: 'DISPLAY',
          nativeId: 'display',
          deviceId: 'tv',
          serviceId: 'tv.media',
          readable: true,
        ),
      ],
      commands: const [
        CommandDefinition(commandId: 'SET_VOLUME', serviceId: 'tv.media'),
      ],
    );
    r.register(tv);
    final router = ServiceRouter(r);
    expect(router.read(tv)['clinicalInterpretation'], isFalse);
    expect(router.execute(service: tv, command: 'SET_VOLUME')['reason'], 'unauthorized');
    tv.authorizedScopes = {AccessScope.control};
    expect(router.execute(service: tv, command: 'POWER_OFF')['reason'], 'unsupportedCommand');
  });

  test('heartbeat lost degrades service not device death claim', () {
    final r = DeviceServiceRegistry();
    r.register(
      ServiceRecord(
        serviceId: 'ecg',
        deviceId: 'mon',
        name: 'ECG',
        category: ServiceCategory.medical,
        status: ServiceStatus.available,
        connected: true,
      ),
    );
    expect(r.noteHeartbeat(serviceId: 'ecg', responded: false), HeartbeatHealth.lost);
    expect(r.byId('ecg')!.status, ServiceStatus.degraded);
  });

  test('virtual monitor registers aliases and personal label stays local', () {
    final r = DeviceServiceRegistry();
    VirtualServiceProvider(r).registerMonitor(deviceId: 'lab_monitor');
    expect(
      r.findUsable(const CapabilityQuery(capability: 'spo2', requireRead: true)),
      isNotEmpty,
    );
    r.setPersonalLabel('lab_monitor.ecg', 'جهاز الغرفة');
    expect(r.byId('lab_monitor.ecg')!.personalLabel, 'جهاز الغرفة');
    expect(r.revision, greaterThan(0));
  });
}
