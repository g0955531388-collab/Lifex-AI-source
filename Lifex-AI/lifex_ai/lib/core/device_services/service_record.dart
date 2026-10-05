/// =============================================================
/// Lifex-AI — سجل خدمات
/// الملف: service_record.dart
/// =============================================================
library lifex_ai.core.device_services.service_record;

import 'service_types.dart';

class RegistryVersion {
  const RegistryVersion({this.major = 1, this.minor = 0, this.revision = 0});

  final int major;
  final int minor;
  final int revision;
}

class ServiceEndpoint {
  const ServiceEndpoint({
    required this.endpointId,
    required this.serviceId,
    required this.type,
    this.readable = false,
    this.writable = false,
    this.subscribable = false,
    this.streamable = false,
  });

  final String endpointId;
  final String serviceId;
  final EndpointType type;
  final bool readable;
  final bool writable;
  final bool subscribable;
  final bool streamable;
}

class CapabilityRecord {
  const CapabilityRecord({
    required this.universalId,
    required this.nativeId,
    required this.deviceId,
    required this.serviceId,
    this.readable = false,
    this.writable = false,
    this.controllable = false,
    this.streamable = false,
  });

  final String universalId;
  final String nativeId;
  final String deviceId;
  final String serviceId;
  final bool readable;
  final bool writable;
  final bool controllable;
  final bool streamable;
}

class CommandDefinition {
  const CommandDefinition({
    required this.commandId,
    required this.serviceId,
    this.parameters = const [],
    this.requiresAuthorization = true,
    this.requiresConfirmation = false,
  });

  final String commandId;
  final String serviceId;
  final List<String> parameters;
  final bool requiresAuthorization;
  final bool requiresConfirmation;
}

class DataField {
  const DataField({
    required this.name,
    this.unit = '',
    this.required = false,
  });

  final String name;
  final String unit;
  final bool required;
}

class ServiceDataSchema {
  const ServiceDataSchema({
    required this.schemaId,
    required this.serviceId,
    this.fields = const [],
  });

  final String schemaId;
  final String serviceId;
  final List<DataField> fields;
}

class CapabilityQuery {
  const CapabilityQuery({
    required this.capability,
    this.requireRead = false,
    this.requireWrite = false,
    this.requireControl = false,
    this.requireStream = false,
  });

  final String capability;
  final bool requireRead;
  final bool requireWrite;
  final bool requireControl;
  final bool requireStream;
}

class ServiceRecord {
  ServiceRecord({
    required this.serviceId,
    required this.deviceId,
    required this.name,
    required this.category,
    this.status = ServiceStatus.unknown,
    this.capabilities = const [],
    this.endpoints = const [],
    this.commands = const [],
    this.schema,
    this.dataQuality = DataQuality.unknown,
    this.connected = false,
    this.authorizedScopes = const {},
    this.trusted = false,
    this.virtual = false,
    this.signalStrength,
    this.latencyMs,
    this.heartbeat = HeartbeatHealth.unknown,
    this.personalLabel,
    this.updatedAt,
  });

  final String serviceId;
  final String deviceId;
  final String name;
  final ServiceCategory category;
  ServiceStatus status;
  final List<CapabilityRecord> capabilities;
  final List<ServiceEndpoint> endpoints;
  final List<CommandDefinition> commands;
  final ServiceDataSchema? schema;
  DataQuality dataQuality;
  bool connected;
  Set<AccessScope> authorizedScopes;
  bool trusted;
  bool virtual;
  double? signalStrength;
  int? latencyMs;
  HeartbeatHealth heartbeat;
  String? personalLabel;
  DateTime? updatedAt;

  bool get listedInRegistry => true;

  bool allows(AccessScope scope) => authorizedScopes.contains(scope);
}

class ServiceMatch {
  const ServiceMatch({
    required this.record,
    required this.usable,
    required this.exclusionReason,
    this.rankScore = 0,
  });

  final ServiceRecord record;
  final bool usable;
  final String exclusionReason;
  final int rankScore;
}
