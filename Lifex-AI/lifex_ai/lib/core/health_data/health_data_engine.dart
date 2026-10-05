/// =============================================================
/// Lifex-AI — محرك
/// الملف: health_data_engine.dart
/// =============================================================
import 'health_data_types.dart';

/// Hybrid store: keyed entity maps + semantic relationship list.
class LifexHealthDataEngine {
  LifexHealthDataEngine({this.neverAutoPrescribe = true});

  final bool neverAutoPrescribe;
  final Map<String, Disease> _diseases = {};
  final Map<String, Medication> _medications = {};
  final Map<String, MedicalDeviceRecord> _devices = {};
  final Map<String, PatientProfile> _patients = {};
  final Map<String, HealthObservation> _observations = {};
  final Map<String, LaboratoryResult> _labs = {};
  final Map<String, ProvenanceRecord> _provenance = {};
  final Map<String, HealthConsent> _consents = {};
  final List<HealthRelationship> _edges = [];

  void putProvenance(ProvenanceRecord record) =>
      _provenance[record.sourceId] = record;

  void putDisease(Disease disease) => _diseases[disease.diseaseId] = disease;

  void putMedication(Medication medication) =>
      _medications[medication.medicationId] = medication;

  void putDevice(MedicalDeviceRecord device) =>
      _devices[device.deviceId] = device;

  void putPatient(PatientProfile patient) =>
      _patients[patient.patientId] = patient;

  void putConsent(HealthConsent consent) =>
      _consents[consent.consentId] = consent;

  void link(HealthRelationship edge) => _edges.add(edge);

  Disease? getDisease(String id) => _diseases[id];
  Medication? getMedication(String id) => _medications[id];
  MedicalDeviceRecord? getMedicalDevice(String id) => _devices[id];

  DataLayer layerOf(Object record) {
    if (record is Disease || record is Medication || record is MedicalDeviceRecord) {
      return DataLayer.globalKnowledge;
    }
    if (record is HealthObservation || record is LaboratoryResult) {
      return DataLayer.patientRecord;
    }
    return DataLayer.interpretation;
  }

  bool observationIsDiagnosis(HealthObservation _) => false;

  bool atcIsIndication(String _) => false;

  bool symptomOverlapIsDiagnosis(List<String> _) => false;

  bool canReadPatient(
    String patientId,
    String scope,
    DateTime at, {
    String? actorId,
  }) {
    return _consents.values.any(
      (c) =>
          c.subjectId == patientId &&
          c.covers(scope, at, actorId: actorId),
    );
  }

  String? addObservation(HealthObservation observation) {
    if (!canReadPatient(
      observation.patientId,
      'observation.write',
      observation.observedAt,
    )) {
      return null;
    }
    if (observation.provenanceId.isEmpty ||
        !_provenance.containsKey(observation.provenanceId)) {
      return null;
    }
    _observations[observation.observationId] = observation;
    if (observation.supersedesId != null) {
      final old = _observations[observation.supersedesId];
      if (old != null) {
        _observations[old.observationId] = HealthObservation(
          observationId: old.observationId,
          patientId: old.patientId,
          conceptId: old.conceptId,
          value: old.value,
          unit: old.unit,
          observedAt: old.observedAt,
          sourceType: old.sourceType,
          sourceId: old.sourceId,
          provenanceId: old.provenanceId,
          method: old.method,
          quality: old.quality,
          status: HealthRecordStatus.superseded,
          supersedesId: old.supersedesId,
        );
      }
    }
    return observation.observationId;
  }

  String? addLaboratoryResult(LaboratoryResult result) {
    if (!canReadPatient(result.patientId, 'lab.write', result.resultAt)) {
      return null;
    }
    if (result.provenanceId.isEmpty || !_provenance.containsKey(result.provenanceId)) {
      return null;
    }
    _labs[result.resultId] = result;
    if (result.supersedesId != null) {
      final old = _labs[result.supersedesId];
      if (old != null) {
        _labs[old.resultId] = LaboratoryResult(
          resultId: old.resultId,
          patientId: old.patientId,
          testId: old.testId,
          value: old.value,
          unit: old.unit,
          specimenCollectedAt: old.specimenCollectedAt,
          resultAt: old.resultAt,
          laboratoryId: old.laboratoryId,
          provenanceId: old.provenanceId,
          referenceLow: old.referenceLow,
          referenceHigh: old.referenceHigh,
          status: HealthRecordStatus.superseded,
          supersedesId: old.supersedesId,
        );
      }
    }
    return result.resultId;
  }

  List<HealthObservation> getObservations(String patientId, {required DateTime at}) {
    if (!canReadPatient(patientId, 'observation.read', at)) return const [];
    return _observations.values.where((o) => o.patientId == patientId).toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  }

  HealthTimeline? getHealthTimeline(String patientId, {required DateTime at}) {
    if (!canReadPatient(patientId, 'timeline.read', at) &&
        !canReadPatient(patientId, 'observation.read', at)) {
      return null;
    }
    return HealthTimeline(
      patientId: patientId,
      observations: getObservations(patientId, at: at),
      labResults: _labs.values.where((l) => l.patientId == patientId).toList(),
    );
  }

  List<HealthConcept> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <HealthConcept>[];
    for (final d in _diseases.values) {
      if (_matches(d.concept, q)) out.add(d.concept);
    }
    for (final m in _medications.values) {
      if (m.genericName.toLowerCase().contains(q)) {
        out.add(
          HealthConcept(
            conceptId: m.medicationId,
            category: 'medication',
            canonicalName: m.genericName,
          ),
        );
      }
    }
    return out;
  }

  bool _matches(HealthConcept c, String q) {
    if (c.canonicalName.toLowerCase().contains(q)) return true;
    return c.synonyms.any((s) => s.toLowerCase().contains(q));
  }

  List<HealthRelationship> relatedTo(String id) =>
      _edges.where((e) => e.sourceId == id || e.targetId == id).toList();

  List<DataConflict> detectConflicts(String patientId, String conceptId) {
    final same = _observations.values
        .where(
          (o) =>
              o.patientId == patientId &&
              o.conceptId == conceptId &&
              o.status == HealthRecordStatus.active,
        )
        .toList();
    final conflicts = <DataConflict>[];
    for (var i = 0; i < same.length; i++) {
      for (var j = i + 1; j < same.length; j++) {
        if (same[i].value != same[j].value || same[i].unit != same[j].unit) {
          conflicts.add(
            DataConflict(
              leftId: same[i].observationId,
              rightId: same[j].observationId,
              field: conceptId,
              leftValue: same[i].value,
              rightValue: same[j].value,
            ),
          );
        }
      }
    }
    return conflicts;
  }

  DataQualityReport validateRecord(String recordId) {
    final obs = _observations[recordId];
    if (obs != null) {
      final complete = obs.unit.isNotEmpty && obs.provenanceId.isNotEmpty ? 1.0 : 0.5;
      return DataQualityReport(
        recordId: recordId,
        completeness: complete,
        hasProvenance: _provenance.containsKey(obs.provenanceId),
        conflicts: detectConflicts(obs.patientId, obs.conceptId),
      );
    }
    return DataQualityReport(
      recordId: recordId,
      completeness: 0,
      hasProvenance: false,
      conflicts: const [],
    );
  }

  String convertUnit({
    required num value,
    required String from,
    required String to,
  }) {
    if (from == to) return '$value $to';
    if (from == 'C' && to == 'F') return '${value * 9 / 5 + 32} F';
    if (from == 'F' && to == 'C') return '${(value - 32) * 5 / 9} C';
    return 'unconverted $value $from';
  }

  bool wouldAutoPrescribe() => !neverAutoPrescribe;
}
