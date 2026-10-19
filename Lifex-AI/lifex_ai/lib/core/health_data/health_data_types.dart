/// =============================================================
/// Lifex-AI — أنواع
/// الملف: health_data_types.dart
/// =============================================================
enum HealthRecordStatus {
  draft,
  active,
  corrected,
  superseded,
  enteredInError,
  archived,
}

enum ObservationQuality { unknown, poor, fair, good, excellent }

enum DataLayer { globalKnowledge, patientRecord, interpretation, decision }

class ProvenanceRecord {
  const ProvenanceRecord({
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    required this.version,
    required this.retrievedAt,
    this.effectiveAt,
    this.verificationStatus = 'unverified',
  });

  final String sourceId;
  final String sourceName;
  final String sourceType;
  final String version;
  final DateTime retrievedAt;
  final DateTime? effectiveAt;
  final String verificationStatus;
}

class HealthConcept {
  const HealthConcept({
    required this.conceptId,
    required this.category,
    required this.canonicalName,
    this.synonyms = const [],
    this.languages = const ['ar', 'en'],
    this.code,
    this.codingSystem,
    this.sourceId = '',
    this.version = '1',
  });

  final String conceptId;
  final String category;
  final String canonicalName;
  final List<String> synonyms;
  final List<String> languages;
  final String? code;
  final String? codingSystem;
  final String sourceId;
  final String version;
}

class Disease {
  const Disease({
    required this.diseaseId,
    required this.concept,
    this.definition = '',
    this.symptomIds = const [],
    this.signIds = const [],
    this.riskFactorIds = const [],
    this.complicationIds = const [],
    this.testIds = const [],
    this.medicationIds = const [],
    this.deviceIds = const [],
    this.evidenceIds = const [],
  });

  final String diseaseId;
  final HealthConcept concept;
  final String definition;
  final List<String> symptomIds;
  final List<String> signIds;
  final List<String> riskFactorIds;
  final List<String> complicationIds;
  final List<String> testIds;
  final List<String> medicationIds;
  final List<String> deviceIds;
  final List<String> evidenceIds;
}

class Medication {
  const Medication({
    required this.medicationId,
    required this.genericName,
    this.activeIngredientIds = const [],
    this.indicationIds = const [],
    this.contraindicationIds = const [],
    this.interactionIds = const [],
    this.warningIds = const [],
    this.evidenceIds = const [],
  });

  final String medicationId;
  final String genericName;
  final List<String> activeIngredientIds;
  final List<String> indicationIds;
  final List<String> contraindicationIds;
  final List<String> interactionIds;
  final List<String> warningIds;
  final List<String> evidenceIds;
}

class MedicalDeviceRecord {
  const MedicalDeviceRecord({
    required this.deviceId,
    required this.manufacturer,
    required this.model,
    required this.deviceCategory,
    this.capabilityIds = const [],
    this.measurementIds = const [],
    this.protocolIds = const [],
    this.warningIds = const [],
    this.evidenceIds = const [],
  });

  final String deviceId;
  final String manufacturer;
  final String model;
  final String deviceCategory;
  final List<String> capabilityIds;
  final List<String> measurementIds;
  final List<String> protocolIds;
  final List<String> warningIds;
  final List<String> evidenceIds;
}

class PatientProfile {
  const PatientProfile({
    required this.patientId,
    this.privateIdentityId,
    this.aliasId,
    this.dateOfBirth,
    this.sex,
    this.bloodType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String patientId;
  final String? privateIdentityId;
  final String? aliasId;
  final DateTime? dateOfBirth;
  final String? sex;
  final String? bloodType;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class HealthConsent {
  const HealthConsent({
    required this.consentId,
    required this.subjectId,
    required this.purpose,
    required this.scopes,
    required this.grantedAt,
    this.grantedTo = '',
    this.expiresAt,
    this.active = true,
  });

  final String consentId;
  final String subjectId;
  final String purpose;
  final List<String> scopes;
  final DateTime grantedAt;
  final String grantedTo;
  final DateTime? expiresAt;
  final bool active;

  bool covers(String scope, DateTime at, {String? actorId}) {
    if (!active) return false;
    if (expiresAt != null && at.isAfter(expiresAt!)) return false;
    if (grantedTo.isNotEmpty && actorId != null && actorId != grantedTo) {
      return false;
    }
    return scopes.contains(scope) || scopes.contains('*');
  }
}

class HealthObservation {
  const HealthObservation({
    required this.observationId,
    required this.patientId,
    required this.conceptId,
    required this.value,
    required this.unit,
    required this.observedAt,
    required this.sourceType,
    required this.sourceId,
    required this.provenanceId,
    this.method = '',
    this.quality = ObservationQuality.unknown,
    this.status = HealthRecordStatus.active,
    this.supersedesId,
  });

  final String observationId;
  final String patientId;
  final String conceptId;
  final Object? value;
  final String unit;
  final DateTime observedAt;
  final String sourceType;
  final String sourceId;
  final String provenanceId;
  final String method;
  final ObservationQuality quality;
  final HealthRecordStatus status;
  final String? supersedesId;
}

class LaboratoryResult {
  const LaboratoryResult({
    required this.resultId,
    required this.patientId,
    required this.testId,
    required this.value,
    required this.unit,
    required this.specimenCollectedAt,
    required this.resultAt,
    required this.laboratoryId,
    required this.provenanceId,
    this.referenceLow,
    this.referenceHigh,
    this.status = HealthRecordStatus.active,
    this.supersedesId,
  });

  final String resultId;
  final String patientId;
  final String testId;
  final Object? value;
  final String unit;
  final DateTime specimenCollectedAt;
  final DateTime resultAt;
  final String laboratoryId;
  final String provenanceId;
  final num? referenceLow;
  final num? referenceHigh;
  final HealthRecordStatus status;
  final String? supersedesId;
}

class HealthRelationship {
  const HealthRelationship({
    required this.relationshipId,
    required this.sourceId,
    required this.relationshipType,
    required this.targetId,
    required this.provenanceId,
    this.evidenceId,
  });

  final String relationshipId;
  final String sourceId;
  final String relationshipType;
  final String targetId;
  final String provenanceId;
  final String? evidenceId;
}

class DataConflict {
  const DataConflict({
    required this.leftId,
    required this.rightId,
    required this.field,
    required this.leftValue,
    required this.rightValue,
  });

  final String leftId;
  final String rightId;
  final String field;
  final Object? leftValue;
  final Object? rightValue;
}

class HealthTimeline {
  const HealthTimeline({
    required this.patientId,
    required this.observations,
    required this.labResults,
  });

  final String patientId;
  final List<HealthObservation> observations;
  final List<LaboratoryResult> labResults;
}

class DataQualityReport {
  const DataQualityReport({
    required this.recordId,
    required this.completeness,
    required this.hasProvenance,
    required this.conflicts,
  });

  final String recordId;
  final double completeness;
  final bool hasProvenance;
  final List<DataConflict> conflicts;
}

class PatientMedicationRecord {
  const PatientMedicationRecord({
    required this.recordId,
    required this.patientId,
    required this.medicationId,
    required this.startAt,
    this.endAt,
    this.sourceId = '',
    this.status = HealthRecordStatus.active,
  });

  final String recordId;
  final String patientId;
  final String medicationId;
  final DateTime startAt;
  final DateTime? endAt;
  final String sourceId;
  final HealthRecordStatus status;
}

class HealthGraphNode {
  const HealthGraphNode({
    required this.id,
    required this.kind,
    required this.label,
  });

  final String id;
  final String kind;
  final String label;
}

class HealthGraphEdge {
  const HealthGraphEdge({
    required this.sourceId,
    required this.relation,
    required this.targetId,
  });

  final String sourceId;
  final String relation;
  final String targetId;
}
