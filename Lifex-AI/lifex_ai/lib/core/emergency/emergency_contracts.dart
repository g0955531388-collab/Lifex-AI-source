/// =============================================================
/// GAP-005 — Emergency Architecture (مسار مستقل ≠ Notification)
/// =============================================================
library lifex_ai.core.emergency.emergency_contracts;

import '../contracts/lifex_core_contracts.dart';

enum EmergencyPriority { low, medium, high, critical }

class EmergencySignal {
  const EmergencySignal({
    required this.id,
    required this.source,
    required this.detectedAt,
    this.rawPayload,
  });

  final LifexId id;
  final String source;
  final DateTime detectedAt;
  final Map<String, Object?>? rawPayload;
}

class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.signalId,
    required this.patientId,
    required this.priority,
    required this.status,
    required this.provenance,
  });

  final LifexId id;
  final LifexId signalId;
  final LifexId patientId;
  final EmergencyPriority priority;
  final String status;
  final EntityProvenance provenance;

  String get canonicalOwner => 'emergency_coordination';
  bool get equalsNotification => false;
  bool get equalsUnlimitedAccess => false;
}

class EmergencyAccess {
  const EmergencyAccess({
    required this.id,
    required this.eventId,
    required this.actorId,
    required this.scope,
    required this.expiresAt,
  });

  final LifexId id;
  final LifexId eventId;
  final LifexId actorId;
  final String scope;
  final DateTime expiresAt;
}

class EmergencyHandoff {
  const EmergencyHandoff({
    required this.id,
    required this.eventId,
    required this.toOrganizationId,
    required this.at,
  });

  final LifexId id;
  final LifexId eventId;
  final LifexId toOrganizationId;
  final DateTime at;
}

abstract class EmergencyDetectionService {
  Future<LifexResult<EmergencySignal>> ingest(EmergencySignal signal);
  Future<LifexResult<EmergencyEvent>> validateAndOpen({
    required EmergencySignal signal,
    required LifexId patientId,
    required bool userConfirmed,
  });
}

abstract class EmergencyCoordinationService {
  Future<LifexResult<void>> escalate(EmergencyEvent event);
  Future<LifexResult<EmergencyHandoff>> handoff(EmergencyHandoff handoff);
  Future<LifexResult<void>> resolve(LifexId eventId);
}

abstract class EmergencyAccessService {
  Future<LifexResult<EmergencyAccess>> grantMinimumNecessary({
    required LifexId eventId,
    required LifexId actorId,
    required Duration ttl,
  });
  bool get breakGlassEqualsUnlimited => false;
}
