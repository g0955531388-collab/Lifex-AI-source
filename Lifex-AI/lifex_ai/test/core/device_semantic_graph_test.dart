/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_semantic_graph_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/device_intelligence/device_semantic_graph.dart';
import 'package:lifex_ai/core/device_intelligence/semantic_types.dart';
import 'package:lifex_ai/core/device_services/service_record.dart';
import 'package:lifex_ai/core/device_services/service_types.dart';

void main() {
  test('ECG is a service on a device over BLE producing a stream', () {
    final g = DeviceSemanticGraph();
    g.ingestService(
      ServiceRecord(
        serviceId: 'mon.ecg',
        deviceId: 'monitor-01',
        name: 'ECG',
        category: ServiceCategory.medical,
        connected: true,
        capabilities: const [
          CapabilityRecord(
            universalId: 'ECG',
            nativeId: '0x10',
            deviceId: 'monitor-01',
            serviceId: 'mon.ecg',
            readable: true,
            streamable: true,
          ),
        ],
      ),
      transport: ConnectionType.ble,
      hardwareBound: false,
    );
    final svcs = g.servicesProviding('ECG');
    expect(svcs.single.kind, GraphNodeKind.service);
    expect(g.devicesHostingService(svcs.single.id).single.id, 'device:monitor-01');
    expect(g.transportOf('device:monitor-01'), 'ble');
    expect(
      g.edges.any((e) => e.kind == GraphEdgeKind.produces),
      isTrue,
    );
    expect(g.transportOf('device:monitor-01'), isNot(equals('proven_hardware')));
    expect(
      g.edges
          .firstWhere((e) => e.kind == GraphEdgeKind.connectedVia)
          .hardwareBound,
      isFalse,
    );
  });

  test('display can render ECG stream; path is not permission', () {
    final g = DeviceSemanticGraph();
    g.ingestService(
      ServiceRecord(
        serviceId: 'mon.ecg',
        deviceId: 'monitor-01',
        name: 'ECG',
        category: ServiceCategory.medical,
        capabilities: const [
          CapabilityRecord(
            universalId: 'ECG',
            nativeId: 'ecg',
            deviceId: 'monitor-01',
            serviceId: 'mon.ecg',
            streamable: true,
          ),
        ],
      ),
      transport: ConnectionType.ble,
    );
    g.ingestService(
      ServiceRecord(
        serviceId: 'phone.display',
        deviceId: 'phone',
        name: 'Display',
        category: ServiceCategory.display,
      ),
      transport: ConnectionType.wifi,
    );
    g.linkSinkCanRender(
      sinkDeviceId: 'phone',
      streamCapability: 'ECG',
      authorized: false,
    );
    final path = g.streamToDisplay(streamCapability: 'ECG');
    expect(path, isNotNull);
    expect(path!.usable, isFalse);
    expect(path.blockReason, 'graph_is_not_authorization');
  });

  test('query by HEART_RATE not by vendor name', () {
    final g = DeviceSemanticGraph();
    g.ingestService(
      ServiceRecord(
        serviceId: 'w.hr',
        deviceId: 'watch',
        name: 'pulse',
        category: ServiceCategory.sensor,
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
    expect(g.matchesVendorAgnostic('hr'), isTrue);
    expect(g.matchesVendorAgnostic('Samsung'), isFalse);
    expect(g.servicesProviding('heart_rate'), isNotEmpty);
  });
}
