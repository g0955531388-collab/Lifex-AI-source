/// =============================================================
/// Lifex-AI — سجل خدمات
/// الملف: virtual_service.dart
/// محاكاة للحزمة 43. ليست جهازاً حقيقياً.
/// =============================================================
library lifex_ai.core.device_services.virtual_service;

import 'device_service_registry.dart';
import 'service_record.dart';
import 'service_types.dart';

class VirtualService {
  VirtualService({
    required this.serviceId,
    required this.name,
    required this.deviceId,
    required this.category,
    this.universalCapability = '',
  });

  final String serviceId;
  final String name;
  final String deviceId;
  final ServiceCategory category;
  final String universalCapability;
  bool running = false;

  Future<void> start() async => running = true;

  Future<void> stop() async => running = false;

  Map<String, dynamic> read() => {
        'simulated': true,
        'running': running,
        'clinicalInterpretation': false,
      };
}

class VirtualServiceProvider {
  VirtualServiceProvider(this.registry);

  final DeviceServiceRegistry registry;

  void registerMonitor({required String deviceId}) {
    _add(
      deviceId: deviceId,
      serviceId: '$deviceId.ecg',
      name: 'ECG',
      category: ServiceCategory.medical,
      universal: 'ECG',
      native: '0x10',
      stream: true,
      schema: const ServiceDataSchema(
        schemaId: 'ecg_v1',
        serviceId: 'ecg',
        fields: [
          DataField(name: 'timestamp', required: true),
          DataField(name: 'lead'),
          DataField(name: 'sample'),
          DataField(name: 'sampleRate'),
          DataField(name: 'unit'),
        ],
      ),
    );
    _add(
      deviceId: deviceId,
      serviceId: '$deviceId.spo2',
      name: 'SpO2',
      category: ServiceCategory.medical,
      universal: 'OXYGEN_SATURATION',
      native: 'spo2',
    );
    _add(
      deviceId: deviceId,
      serviceId: '$deviceId.hr',
      name: 'HeartRate',
      category: ServiceCategory.medical,
      universal: 'HEART_RATE',
      native: 'pulse',
    );
    _add(
      deviceId: deviceId,
      serviceId: '$deviceId.alarm',
      name: 'Alarm',
      category: ServiceCategory.emergency,
      universal: 'ALARM',
      native: 'alarm',
    );
  }

  void registerPhone({required String deviceId}) {
    for (final e in [
      ['camera', 'CAMERA', ServiceCategory.camera],
      ['microphone', 'MICROPHONE', ServiceCategory.audio],
      ['speaker', 'SPEAKER', ServiceCategory.audio],
      ['display', 'DISPLAY', ServiceCategory.display],
      ['location', 'LOCATION', ServiceCategory.location],
    ]) {
      _add(
        deviceId: deviceId,
        serviceId: '$deviceId.${e[0]}',
        name: '${e[0]}',
        category: e[2] as ServiceCategory,
        universal: e[1] as String,
        native: e[0] as String,
      );
    }
  }

  void _add({
    required String deviceId,
    required String serviceId,
    required String name,
    required ServiceCategory category,
    required String universal,
    required String native,
    bool stream = false,
    ServiceDataSchema? schema,
  }) {
    registry.register(
      ServiceRecord(
        serviceId: serviceId,
        deviceId: deviceId,
        name: name,
        category: category,
        status: ServiceStatus.available,
        connected: true,
        trusted: true,
        virtual: true,
        dataQuality: DataQuality.fair,
        authorizedScopes: {AccessScope.discover, AccessScope.read},
        capabilities: [
          CapabilityRecord(
            universalId: universal,
            nativeId: native,
            deviceId: deviceId,
            serviceId: serviceId,
            readable: true,
            streamable: stream,
          ),
        ],
        endpoints: [
          ServiceEndpoint(
            endpointId: '$serviceId.state',
            serviceId: serviceId,
            type: EndpointType.state,
            readable: true,
          ),
          if (stream)
            ServiceEndpoint(
              endpointId: '$serviceId.stream',
              serviceId: serviceId,
              type: EndpointType.stream,
              streamable: true,
            ),
        ],
        schema: schema,
      ),
    );
  }
}
