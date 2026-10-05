/// =============================================================
/// GAP-001 / GAP-006 — نماذج سريرية تحت health_data (أصل كانوني)
/// Original Clinical ≠ Patient Health Record ≠ Projection ≠ AI Context
/// =============================================================
library lifex_ai.core.health_data.models.clinical_models;

import '../../contracts/lifex_core_contracts.dart';

/// GAP-006 ladder: Disease(knowledge) ≠ PatientCondition ≠ Observation ≠
/// Interpretation ≠ Hypothesis ≠ Diagnosis.
enum ClinicalArtifactKind {
  observation,
  interpretation,
  hypothesis,
  diagnosis,
  assessment,
  note,
}

class ClinicalObservation {
  const ClinicalObservation({
    required this.id,
    required this.patientId,
    required this.code,
    required this.observedAt,
    required this.provenance,
    this.value,
    this.unit,
  });

  final LifexId id;
  final LifexId patientId;
  final String code;
  final String? value;
  final String? unit;
  final DateTime observedAt;
  final EntityProvenance provenance;

  String get canonicalOwner => 'health_data';
  DataKind get dataKind => DataKind.original;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.observation;
}

class HealthInterpretation {
  const HealthInterpretation({
    required this.id,
    required this.observationId,
    required this.summary,
    required this.provenance,
  });

  final LifexId id;
  final LifexId observationId;
  final String summary;
  final EntityProvenance provenance;

  String get canonicalOwner => 'health_data';
  DataKind get dataKind => DataKind.derived;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.interpretation;
  bool get equalsDiagnosis => false;
}

class ClinicalHypothesis {
  const ClinicalHypothesis({
    required this.id,
    required this.patientId,
    required this.statement,
    required this.provenance,
    this.confidence,
  });

  final LifexId id;
  final LifexId patientId;
  final String statement;
  final double? confidence;
  final EntityProvenance provenance;

  String get canonicalOwner => 'clinical_decision_support';
  DataKind get dataKind => DataKind.derived;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.hypothesis;
  bool get equalsDiagnosis => false;
}

class ClinicalDiagnosis {
  const ClinicalDiagnosis({
    required this.id,
    required this.patientId,
    required this.code,
    required this.display,
    required this.provenance,
    this.encounterId,
  });

  final LifexId id;
  final LifexId patientId;
  final LifexId? encounterId;
  final String code;
  final String display;
  final EntityProvenance provenance;

  /// Authored clinical diagnosis lives in health_data (not a vague Clinical Records dump).
  String get canonicalOwner => 'health_data';
  DataKind get dataKind => DataKind.original;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.diagnosis;
  bool get aiMayOwn => false;
}

class ClinicalAssessment {
  const ClinicalAssessment({
    required this.id,
    required this.patientId,
    required this.summary,
    required this.provenance,
    this.encounterId,
  });

  final LifexId id;
  final LifexId patientId;
  final LifexId? encounterId;
  final String summary;
  final EntityProvenance provenance;

  String get canonicalOwner => 'health_data';
  DataKind get dataKind => DataKind.original;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.assessment;
}

class ClinicalNote {
  const ClinicalNote({
    required this.id,
    required this.patientId,
    required this.body,
    required this.provenance,
    this.encounterId,
  });

  final LifexId id;
  final LifexId patientId;
  final LifexId? encounterId;
  final String body;
  final EntityProvenance provenance;

  String get canonicalOwner => 'health_data';
  DataKind get dataKind => DataKind.original;
  ClinicalArtifactKind get kind => ClinicalArtifactKind.note;
}

/// GAP-001 contract — no UI/AI SQL; ownership enforced.
abstract class ClinicalDataService {
  Future<LifexResult<ClinicalDiagnosis>> recordDiagnosis(ClinicalDiagnosis d);
  Future<LifexResult<ClinicalNote>> recordNote(ClinicalNote n);
  Future<LifexResult<ClinicalAssessment>> recordAssessment(ClinicalAssessment a);
  Future<LifexResult<ClinicalObservation>> recordObservation(ClinicalObservation o);
}

abstract class ClinicalConflictService {
  Future<LifexResult<List<String>>> detectConflicts({
    required LifexId patientId,
    required List<String> observationIds,
  });
  bool get newestEqualsCorrect => false;
  bool get aiEqualsCorrect => false;
  bool get hospitalAlwaysCorrect => false;
}
