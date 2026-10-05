/// =============================================================
/// Lifex-AI — مستودع
/// الملف: personal_health_repository.dart
/// =============================================================
import 'personal_health_engine.dart';
import 'personal_health_types.dart';

abstract class PersonalHealthRepository {
  Future<void> savePatient(PatientRecord patient);
  Future<PatientRecord?> getPatient(String patientId);
  Future<void> saveCondition(PatientCondition condition);
  Future<void> saveMedication(PatientMedication medication);
  Future<void> saveObservation(PatientObservation observation);
  Future<void> saveLabResult(PatientLabResult result);
  Future<void> saveConsent(PersonalHealthConsent consent);

  Future<List<PatientCondition>> getConditions({
    required String actorId,
    required String patientId,
    required DateTime at,
  });

  Future<List<HealthTimelineEvent>> getTimeline({
    required String actorId,
    required String patientId,
    required DateTime at,
  });
}

class InMemoryPersonalHealthRepository implements PersonalHealthRepository {
  InMemoryPersonalHealthRepository(this.engine);

  final LifexPersonalFamilyHealthEngine engine;

  @override
  Future<void> savePatient(PatientRecord patient) => engine.createPatient(patient);

  @override
  Future<PatientRecord?> getPatient(String patientId) async =>
      engine.patients[patientId];

  @override
  Future<void> saveCondition(PatientCondition condition) =>
      engine.addCondition(condition);

  @override
  Future<void> saveMedication(PatientMedication medication) =>
      engine.addMedication(medication);

  @override
  Future<void> saveObservation(PatientObservation observation) =>
      engine.addObservation(observation);

  @override
  Future<void> saveLabResult(PatientLabResult result) =>
      engine.addLabResult(result);

  @override
  Future<void> saveConsent(PersonalHealthConsent consent) async {
    await engine.createConsent(consent);
  }

  @override
  Future<List<PatientCondition>> getConditions({
    required String actorId,
    required String patientId,
    required DateTime at,
  }) async {
    if (!engine.authorize(
      actorId: actorId,
      patientId: patientId,
      scope: HealthDataScope.conditions,
      purpose: ConsentPurpose.care,
      at: at,
    )) {
      return const [];
    }
    return engine.conditions.values
        .where((c) => c.patientId == patientId)
        .toList();
  }

  @override
  Future<List<HealthTimelineEvent>> getTimeline({
    required String actorId,
    required String patientId,
    required DateTime at,
  }) async {
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
}
