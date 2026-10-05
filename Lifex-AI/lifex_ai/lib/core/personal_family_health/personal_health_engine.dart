/// =============================================================
/// Lifex-AI — محرك
/// الملف: personal_health_engine.dart
/// =============================================================
import '../health_data/health_data_engine.dart';
import '../health_data/health_data_types.dart';
import 'personal_health_types.dart';

class LifexPersonalFamilyHealthEngine {
  LifexPersonalFamilyHealthEngine({
    this.neverAutoDiagnose = true,
    this.knowledge,
  });

  final bool neverAutoDiagnose;
  /// Pack 54 — lookup only. Never copied into 55 maps.
  final LifexHealthDataEngine? knowledge;
  final Map<String, PersonRecord> persons = {};
  final Map<String, PersonHealthIdentity> identities = {};
  final Map<String, PatientRecord> patients = {};
  final Map<String, PatientAlias> aliases = {};
  final Map<String, FamilyGroup> families = {};
  final Map<String, FamilyMembership> memberships = {};
  final Map<String, FamilyRelationship> relationships = {};
  final Map<String, FamilyHealthHistory> familyHistory = {};
  final Map<String, PatientCondition> conditions = {};
  final Map<String, PatientMedication> medications = {};
  final Map<String, PatientAllergy> allergies = {};
  final Map<String, PatientObservation> observations = {};
  final Map<String, PatientVital> vitals = {};
  final Map<String, PatientLabResult> labs = {};
  final Map<String, HealthEncounter> encounters = {};
  final Map<String, PatientDevice> devices = {};
  final Map<String, PersonalHealthConsent> consents = {};
  final List<HealthAccessAudit> audits = [];
  bool _shutdown = false;

  Future<void> initialize() async {}

  Future<void> shutdown() async => _shutdown = true;

  bool get isShutdown => _shutdown;

  bool suspectedIsDiagnosed(ConditionStatus status) =>
      status == ConditionStatus.active || status == ConditionStatus.remission;

  bool observationIsDiagnosis(PatientObservation _) => false;

  Future<PersonRecord> createPerson(PersonRecord person) async {
    persons[person.personId] = person;
    return person;
  }

  Future<PatientRecord> createPatient(PatientRecord patient) async {
    patients[patient.patientId] = patient;
    return patient;
  }

  Future<void> addAlias(PatientAlias alias) async {
    aliases[alias.aliasId] = alias;
  }

  Future<FamilyGroup> createFamily(FamilyGroup family) async {
    families[family.familyId] = family;
    return family;
  }

  Future<void> addFamilyMember(FamilyMembership membership) async {
    memberships[membership.membershipId] = membership;
  }

  Future<void> addRelationship(FamilyRelationship relationship) async {
    relationships[relationship.relationshipId] = relationship;
  }

  Future<void> addCondition(PatientCondition condition) async {
    conditions[condition.conditionId] = condition;
  }

  Future<void> addMedication(PatientMedication medication) async {
    medications[medication.patientMedicationId] = medication;
  }

  Future<void> addAllergy(PatientAllergy allergy) async {
    allergies[allergy.allergyId] = allergy;
  }

  Future<void> addObservation(PatientObservation observation) async {
    observations[observation.observationId] = observation;
  }

  Future<void> addVital(PatientVital vital) async {
    vitals[vital.vitalId] = vital;
  }

  Future<void> addLabResult(PatientLabResult result) async {
    labs[result.resultId] = result;
  }

  Future<void> addEncounter(HealthEncounter encounter) async {
    encounters[encounter.encounterId] = encounter;
  }

  Future<void> addFamilyHistory(FamilyHealthHistory history) async {
    familyHistory[history.historyId] = history;
  }

  Future<void> addDevice(PatientDevice device) async {
    devices[device.patientDeviceId] = device;
  }

  Future<PersonalHealthConsent> createConsent(PersonalHealthConsent consent) async {
    consents[consent.consentId] = consent;
    return consent;
  }

  Future<void> revokeConsent(String consentId) async {
    consents.remove(consentId);
  }

  bool isFamilyMember(String familyId, String personId) {
    return memberships.values.any(
      (m) =>
          m.familyId == familyId &&
          m.personId == personId &&
          m.endedAt == null,
    );
  }

  bool familyMembershipGrantsAccess() => false;

  bool isOwner(String actorId, String patientId) {
    final p = patients[patientId];
    if (p == null) return false;
    return p.personId == actorId ||
        p.identityId == actorId ||
        p.patientId == actorId;
  }

  bool authorize({
    required String actorId,
    required String patientId,
    required HealthDataScope scope,
    required ConsentPurpose purpose,
    required DateTime at,
  }) {
    final ok = isOwner(actorId, patientId) ||
        consents.values.any(
          (c) =>
              c.patientId == patientId &&
              c.granteeId == actorId &&
              c.allows(scope, purpose, at),
        );
    audits.add(
      HealthAccessAudit(
        auditId: 'a${audits.length + 1}',
        patientId: patientId,
        actorId: actorId,
        action: 'authorize:$scope',
        timestamp: at,
        result: ok ? 'granted' : 'denied',
      ),
    );
    return ok;
  }

  Set<HealthDataScope> emergencyMinimumScopes() => {
        HealthDataScope.emergency,
        HealthDataScope.allergies,
        HealthDataScope.medications,
        HealthDataScope.conditions,
      };

  List<HealthTimelineEvent> getTimeline(String patientId) {
    final events = <HealthTimelineEvent>[];
    for (final o in observations.values.where((e) => e.patientId == patientId)) {
      events.add(
        HealthTimelineEvent(
          eventId: o.observationId,
          patientId: patientId,
          type: 'observation',
          timestamp: o.observedAt,
          recordId: o.observationId,
          provenance: o.provenance,
        ),
      );
    }
    for (final v in vitals.values.where((e) => e.patientId == patientId)) {
      events.add(
        HealthTimelineEvent(
          eventId: v.vitalId,
          patientId: patientId,
          type: 'vital',
          timestamp: v.observedAt,
          recordId: v.vitalId,
          provenance: v.provenance,
        ),
      );
    }
    for (final l in labs.values.where((e) => e.patientId == patientId)) {
      events.add(
        HealthTimelineEvent(
          eventId: l.resultId,
          patientId: patientId,
          type: 'laboratory',
          timestamp: l.reportedAt,
          recordId: l.resultId,
          provenance: l.provenance,
        ),
      );
    }
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  PatientHealthSummary getSummary(String patientId, DateTime at) {
    return PatientHealthSummary(
      patientId: patientId,
      activeConditionIds: conditions.values
          .where(
            (c) =>
                c.patientId == patientId &&
                c.status == ConditionStatus.active,
          )
          .map((c) => c.conditionId)
          .toList(),
      activeMedicationIds: medications.values
          .where(
            (m) =>
                m.patientId == patientId &&
                m.status == MedicationUsageStatus.active,
          )
          .map((m) => m.patientMedicationId)
          .toList(),
      allergyIds: allergies.values
          .where((a) => a.patientId == patientId)
          .map((a) => a.allergyId)
          .toList(),
      generatedAt: at,
    );
  }

  List<FamilyHealthHistory> getFamilyHistory(String patientId) =>
      familyHistory.values.where((h) => h.patientId == patientId).toList();

  bool familyHistoryImpliesPatientHasDisease() => false;

  List<HealthConflict> getConflicts(String patientId) {
    final same = vitals.values.where((v) => v.patientId == patientId).toList();
    final out = <HealthConflict>[];
    for (var i = 0; i < same.length; i++) {
      for (var j = i + 1; j < same.length; j++) {
        if (same[i].conceptId == same[j].conceptId &&
            same[i].value != same[j].value) {
          out.add(
            HealthConflict(
              conflictId: '${same[i].vitalId}_${same[j].vitalId}',
              patientId: patientId,
              leftId: same[i].vitalId,
              rightId: same[j].vitalId,
              leftValue: same[i].value,
              rightValue: same[j].value,
            ),
          );
        }
      }
    }
    return out;
  }

  /// Last write does not delete the other reading.
  bool lastWriteWins() => false;

  Disease? knowledgeDisease(String diseaseConceptId) =>
      knowledge?.getDisease(diseaseConceptId);

  Medication? knowledgeMedication(String medicationId) =>
      knowledge?.getMedication(medicationId);

  MedicalDeviceRecord? knowledgeDevice(String deviceId) =>
      knowledge?.getMedicalDevice(deviceId);

  bool copiesKnowledgeIntoPersonalStore() => false;

  PatientLabResult? latestLab({
    required String patientId,
    required String laboratoryTestId,
  }) {
    final list = labs.values
        .where(
          (l) =>
              l.patientId == patientId &&
              l.laboratoryTestId == laboratoryTestId,
        )
        .toList()
      ..sort((a, b) => a.reportedAt.compareTo(b.reportedAt));
    return list.isEmpty ? null : list.last;
  }
}

class PersonalHealthQueryService {
  PersonalHealthQueryService(this.engine);
  final LifexPersonalFamilyHealthEngine engine;

  bool allowDirectPatientSql() => false;

  List<HealthTimelineEvent> timeline({
    required String actorId,
    required String patientId,
    required DateTime at,
  }) {
    if (!engine.authorize(
      actorId: actorId,
      patientId: patientId,
      scope: HealthDataScope.timeline,
      purpose: ConsentPurpose.care,
      at: at,
    )) {
      return const [];
    }
    return engine.getTimeline(patientId);
  }

  PatientLabResult? latestLab({
    required String actorId,
    required String patientId,
    required String laboratoryTestId,
    required DateTime at,
  }) {
    if (!engine.authorize(
      actorId: actorId,
      patientId: patientId,
      scope: HealthDataScope.laboratory,
      purpose: ConsentPurpose.care,
      at: at,
    )) {
      return null;
    }
    return engine.latestLab(
      patientId: patientId,
      laboratoryTestId: laboratoryTestId,
    );
  }
}
