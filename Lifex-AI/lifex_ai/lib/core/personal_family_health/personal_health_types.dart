/// =============================================================
/// Lifex-AI — أنواع
/// الملف: personal_health_types.dart
/// =============================================================
enum RecordStatus { active, inactive, deceased, merged, enteredInError, restricted }

enum IdentityType {
  private,
  verified,
  pseudonymous,
  anonymous,
  dependent,
  guardianManaged,
}

enum FamilyRole {
  member,
  parent,
  child,
  spouse,
  guardian,
  dependent,
  caregiver,
  authorizedRelative,
}

enum FamilyRelationshipType {
  parent,
  child,
  spouse,
  sibling,
  halfSibling,
  grandparent,
  grandchild,
  other,
  unknown,
}

enum ConditionStatus {
  suspected,
  active,
  inactive,
  resolved,
  remission,
  historical,
  enteredInError,
  unknown,
}

enum MedicationUsageStatus { active, completed, stopped, paused, historical, unknown }

enum HealthDataScope {
  profile,
  conditions,
  medications,
  allergies,
  laboratory,
  imaging,
  vitals,
  familyHistory,
  devices,
  encounters,
  documents,
  emergency,
  timeline,
}

enum ConsentPurpose { care, familyCare, emergency, research, sharing, monitoring, administration }

enum ConsentDecision { permit, deny }

enum HistoryStatus { reported, confirmed, unknown, conflicting }

class ProvenanceRef {
  const ProvenanceRef({required this.sourceId, this.verification = 'unverified'});
  final String sourceId;
  final String verification;
}

class PersonRecord {
  const PersonRecord({
    required this.personId,
    required this.createdAt,
    this.status = RecordStatus.active,
  });
  final String personId;
  final DateTime createdAt;
  final RecordStatus status;
}

class PersonHealthIdentity {
  const PersonHealthIdentity({
    required this.identityId,
    required this.personId,
    required this.accountId,
    required this.type,
  });
  final String identityId;
  final String personId;
  final String accountId;
  final IdentityType type;
}

class PatientAlias {
  const PatientAlias({
    required this.aliasId,
    required this.patientId,
    required this.displayName,
    this.publicVisible = false,
    required this.createdAt,
  });
  final String aliasId;
  final String patientId;
  final String displayName;
  final bool publicVisible;
  final DateTime createdAt;
}

class PatientRecord {
  const PatientRecord({
    required this.patientId,
    required this.personId,
    required this.identityId,
    this.status = RecordStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });
  final String patientId;
  final String personId;
  final String identityId;
  final RecordStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class FamilyGroup {
  const FamilyGroup({
    required this.familyId,
    required this.name,
    this.primaryPatientId,
    required this.createdAt,
  });
  final String familyId;
  final String name;
  final String? primaryPatientId;
  final DateTime createdAt;
}

class FamilyMembership {
  const FamilyMembership({
    required this.membershipId,
    required this.familyId,
    required this.personId,
    required this.role,
    required this.joinedAt,
    this.endedAt,
  });
  final String membershipId;
  final String familyId;
  final String personId;
  final FamilyRole role;
  final DateTime joinedAt;
  final DateTime? endedAt;
}

class FamilyRelationship {
  const FamilyRelationship({
    required this.relationshipId,
    required this.personAId,
    required this.personBId,
    required this.type,
    this.confidence = 1,
  });
  final String relationshipId;
  final String personAId;
  final String personBId;
  final FamilyRelationshipType type;
  final double confidence;
}

class FamilyHealthHistory {
  const FamilyHealthHistory({
    required this.historyId,
    required this.patientId,
    required this.diseaseId,
    required this.relationship,
    this.relatedPersonId,
    this.status = HistoryStatus.reported,
    required this.provenance,
  });
  final String historyId;
  final String patientId;
  final String? relatedPersonId;
  final FamilyRelationshipType relationship;
  final String diseaseId;
  final HistoryStatus status;
  final ProvenanceRef provenance;
}

class PatientCondition {
  const PatientCondition({
    required this.conditionId,
    required this.patientId,
    required this.diseaseConceptId,
    required this.status,
    this.onsetDate,
    this.resolvedDate,
    required this.provenance,
  });
  final String conditionId;
  final String patientId;
  final String diseaseConceptId;
  final ConditionStatus status;
  final DateTime? onsetDate;
  final DateTime? resolvedDate;
  final ProvenanceRef provenance;
}

class PatientMedication {
  const PatientMedication({
    required this.patientMedicationId,
    required this.patientId,
    required this.medicationId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.instructions,
    required this.provenance,
  });
  final String patientMedicationId;
  final String patientId;
  final String medicationId;
  final MedicationUsageStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? instructions;
  final ProvenanceRef provenance;
}

class PatientAllergy {
  const PatientAllergy({
    required this.allergyId,
    required this.patientId,
    required this.allergenConceptId,
    this.verification = 'patientReported',
    required this.provenance,
  });
  final String allergyId;
  final String patientId;
  final String allergenConceptId;
  final String verification;
  final ProvenanceRef provenance;
}

class PatientObservation {
  const PatientObservation({
    required this.observationId,
    required this.patientId,
    required this.conceptId,
    required this.value,
    this.unit,
    required this.observedAt,
    required this.source,
    required this.provenance,
  });
  final String observationId;
  final String patientId;
  final String conceptId;
  final Object? value;
  final String? unit;
  final DateTime observedAt;
  final String source;
  final ProvenanceRef provenance;
}

class PatientVital {
  const PatientVital({
    required this.vitalId,
    required this.patientId,
    required this.conceptId,
    required this.value,
    required this.unit,
    required this.observedAt,
    this.deviceId,
    required this.provenance,
  });
  final String vitalId;
  final String patientId;
  final String conceptId;
  final num value;
  final String unit;
  final DateTime observedAt;
  final String? deviceId;
  final ProvenanceRef provenance;
}

class PatientLabResult {
  const PatientLabResult({
    required this.resultId,
    required this.patientId,
    required this.laboratoryTestId,
    required this.value,
    required this.unit,
    required this.collectedAt,
    required this.reportedAt,
    this.laboratoryId,
    required this.provenance,
  });
  final String resultId;
  final String patientId;
  final String laboratoryTestId;
  final Object? value;
  final String unit;
  final DateTime collectedAt;
  final DateTime reportedAt;
  final String? laboratoryId;
  final ProvenanceRef provenance;
}

class HealthEncounter {
  const HealthEncounter({
    required this.encounterId,
    required this.patientId,
    required this.type,
    required this.startedAt,
    this.organizationId,
  });
  final String encounterId;
  final String patientId;
  final String type;
  final DateTime startedAt;
  final String? organizationId;
}

class PatientDevice {
  const PatientDevice({
    required this.patientDeviceId,
    required this.patientId,
    required this.deviceId,
    required this.relationship,
    required this.linkedAt,
  });
  final String patientDeviceId;
  final String patientId;
  final String deviceId;
  final String relationship;
  final DateTime linkedAt;
}

class HealthTimelineEvent {
  const HealthTimelineEvent({
    required this.eventId,
    required this.patientId,
    required this.type,
    required this.timestamp,
    required this.recordId,
    required this.provenance,
  });
  final String eventId;
  final String patientId;
  final String type;
  final DateTime timestamp;
  final String recordId;
  final ProvenanceRef provenance;
}

class PatientHealthSummary {
  const PatientHealthSummary({
    required this.patientId,
    required this.activeConditionIds,
    required this.activeMedicationIds,
    required this.allergyIds,
    required this.generatedAt,
    this.isSourceOfTruth = false,
  });
  final String patientId;
  final List<String> activeConditionIds;
  final List<String> activeMedicationIds;
  final List<String> allergyIds;
  final DateTime generatedAt;
  final bool isSourceOfTruth;
}

class PersonalHealthConsent {
  const PersonalHealthConsent({
    required this.consentId,
    required this.patientId,
    required this.grantorId,
    required this.granteeId,
    required this.decision,
    required this.scopes,
    required this.purposes,
    required this.validFrom,
    this.validUntil,
    this.revocable = true,
  });
  final String consentId;
  final String patientId;
  final String grantorId;
  final String granteeId;
  final ConsentDecision decision;
  final Set<HealthDataScope> scopes;
  final Set<ConsentPurpose> purposes;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool revocable;

  bool allows(HealthDataScope scope, ConsentPurpose purpose, DateTime at) {
    if (decision != ConsentDecision.permit) return false;
    if (at.isBefore(validFrom)) return false;
    if (validUntil != null && at.isAfter(validUntil!)) return false;
    if (!purposes.contains(purpose) && !purposes.contains(ConsentPurpose.care)) {
      return false;
    }
    return scopes.contains(scope);
  }
}

class HealthAccessAudit {
  const HealthAccessAudit({
    required this.auditId,
    required this.patientId,
    required this.actorId,
    required this.action,
    required this.timestamp,
    required this.result,
    this.consentId,
  });
  final String auditId;
  final String patientId;
  final String actorId;
  final String action;
  final DateTime timestamp;
  final String result;
  final String? consentId;
}

class HealthConflict {
  const HealthConflict({
    required this.conflictId,
    required this.patientId,
    required this.leftId,
    required this.rightId,
    required this.leftValue,
    required this.rightValue,
  });
  final String conflictId;
  final String patientId;
  final String leftId;
  final String rightId;
  final Object? leftValue;
  final Object? rightValue;
}
