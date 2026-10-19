/// =============================================================
/// GAP-001 — إسقاطات المريض (مرجع/Projection) تحت Personal & Family Health
/// =============================================================
library lifex_ai.core.personal_family_health.models.patient_clinical_projections;

import '../../contracts/lifex_core_contracts.dart';

/// Patient-facing encounter reference — not competing SoT for hospital encounter.
class PatientEncounter {
  const PatientEncounter({
    required this.id,
    required this.patientId,
    required this.startedAt,
    this.originalEncounterId,
    this.sourceSystem,
  });

  final LifexId id;
  final LifexId patientId;
  final LifexId? originalEncounterId;
  final String? sourceSystem;
  final DateTime startedAt;

  String get canonicalOwner => 'personal_family_health';
  DataKind get dataKind => DataKind.projection;
}

class PatientProcedure {
  const PatientProcedure({
    required this.id,
    required this.patientId,
    required this.code,
    this.originalProcedureId,
  });

  final LifexId id;
  final LifexId patientId;
  final LifexId? originalProcedureId;
  final String code;

  String get canonicalOwner => 'personal_family_health';
  DataKind get dataKind => DataKind.projection;
}

class PatientTimelineEvent {
  const PatientTimelineEvent({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.refId,
    required this.at,
  });

  final LifexId id;
  final LifexId patientId;
  final String kind;
  final LifexId refId;
  final DateTime at;

  String get canonicalOwner => 'personal_family_health';
  DataKind get dataKind => DataKind.projection;
  bool get isSourceOfTruth => false;
}
