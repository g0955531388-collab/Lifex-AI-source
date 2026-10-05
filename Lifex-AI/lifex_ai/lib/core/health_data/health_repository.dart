/// =============================================================
/// Lifex-AI — مستودع
/// الملف: health_repository.dart
/// =============================================================
import 'health_data_types.dart';

/// Relational maps are the source of truth. Graph and search are projections.
class RelationalHealthStore {
  final Map<String, Disease> diseases = {};
  final Map<String, Medication> medications = {};
  final Map<String, MedicalDeviceRecord> devices = {};
  final Map<String, PatientProfile> patients = {};
  final Map<String, HealthObservation> observations = {};
  final Map<String, LaboratoryResult> labs = {};
  final Map<String, ProvenanceRecord> provenance = {};
  final Map<String, HealthConsent> consents = {};
  final Map<String, PatientMedicationRecord> patientMedications = {};
  final List<HealthRelationship> relationships = [];
}

class HealthGraphProjection {
  final List<HealthGraphNode> nodes = [];
  final List<HealthGraphEdge> edges = [];

  void clear() {
    nodes.clear();
    edges.clear();
  }
}

class HealthSearchIndex {
  final Map<String, Set<String>> termToConceptIds = {};

  void clear() => termToConceptIds.clear();
}

abstract class HealthDataRepository {
  Future<void> saveDisease(Disease disease);
  Future<Disease?> getDisease(String id);
  Future<void> saveMedication(Medication medication);
  Future<void> savePatientMedication(PatientMedicationRecord record);
  Future<void> saveRelationship(HealthRelationship edge);
  Future<void> rebuildGraph();
  Future<void> rebuildSearchIndex();
  List<HealthGraphNode> graphNodes();
  List<String> searchIds(String query);

  /// —— HealthObservation (canonical patient-record ownership) ——
  Future<void> ensureProvenance(ProvenanceRecord provenance);
  Future<HealthObservation?> saveObservation(HealthObservation observation);
  Future<HealthObservation?> getObservation(String observationId);
  Future<List<HealthObservation>> listObservationsForPatient(String patientId);
  Future<HealthObservation?> updateObservation(HealthObservation observation);
  Future<HealthObservation?> archiveObservation(String observationId);
}

class InMemoryHealthRepository implements HealthDataRepository {
  InMemoryHealthRepository({RelationalHealthStore? store})
      : store = store ?? RelationalHealthStore();

  final RelationalHealthStore store;
  final HealthGraphProjection graph = HealthGraphProjection();
  final HealthSearchIndex search = HealthSearchIndex();

  @override
  Future<void> saveDisease(Disease disease) async {
    store.diseases[disease.diseaseId] = disease;
  }

  @override
  Future<Disease?> getDisease(String id) async => store.diseases[id];

  @override
  Future<void> saveMedication(Medication medication) async {
    store.medications[medication.medicationId] = medication;
  }

  @override
  Future<void> savePatientMedication(PatientMedicationRecord record) async {
    store.patientMedications[record.recordId] = record;
  }

  @override
  Future<void> saveRelationship(HealthRelationship edge) async {
    store.relationships.add(edge);
  }

  @override
  Future<void> rebuildGraph() async {
    graph.clear();
    for (final d in store.diseases.values) {
      graph.nodes.add(
        HealthGraphNode(
          id: d.diseaseId,
          kind: 'disease',
          label: d.concept.canonicalName,
        ),
      );
      for (final s in d.symptomIds) {
        graph.edges.add(
          HealthGraphEdge(
            sourceId: d.diseaseId,
            relation: 'hasSymptom',
            targetId: s,
          ),
        );
      }
      for (final m in d.medicationIds) {
        graph.edges.add(
          HealthGraphEdge(
            sourceId: d.diseaseId,
            relation: 'relatedTo',
            targetId: m,
          ),
        );
      }
    }
    for (final m in store.medications.values) {
      graph.nodes.add(
        HealthGraphNode(
          id: m.medicationId,
          kind: 'medication',
          label: m.genericName,
        ),
      );
    }
    for (final d in store.devices.values) {
      graph.nodes.add(
        HealthGraphNode(
          id: d.deviceId,
          kind: 'device',
          label: d.model,
        ),
      );
    }
    for (final e in store.relationships) {
      graph.edges.add(
        HealthGraphEdge(
          sourceId: e.sourceId,
          relation: e.relationshipType,
          targetId: e.targetId,
        ),
      );
    }
  }

  @override
  Future<void> rebuildSearchIndex() async {
    search.clear();
    void index(String id, Iterable<String> terms) {
      for (final t in terms) {
        final k = t.trim().toLowerCase();
        if (k.isEmpty) continue;
        search.termToConceptIds.putIfAbsent(k, () => <String>{}).add(id);
      }
    }

    for (final d in store.diseases.values) {
      index(d.diseaseId, [d.concept.canonicalName, ...d.concept.synonyms]);
    }
    for (final m in store.medications.values) {
      index(m.medicationId, [m.genericName]);
    }
  }

  @override
  List<HealthGraphNode> graphNodes() => List.unmodifiable(graph.nodes);

  @override
  List<String> searchIds(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final ids = <String>{};
    search.termToConceptIds.forEach((term, set) {
      if (term.contains(q)) ids.addAll(set);
    });
    return ids.toList();
  }

  @override
  Future<void> ensureProvenance(ProvenanceRecord provenance) async {
    store.provenance[provenance.sourceId] = provenance;
  }

  @override
  Future<HealthObservation?> saveObservation(HealthObservation observation) async {
    if (observation.provenanceId.isEmpty ||
        !store.provenance.containsKey(observation.provenanceId)) {
      return null;
    }
    store.observations[observation.observationId] = observation;
    if (observation.supersedesId != null) {
      final old = store.observations[observation.supersedesId];
      if (old != null && old.status == HealthRecordStatus.active) {
        store.observations[old.observationId] = HealthObservation(
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
    return store.observations[observation.observationId];
  }

  @override
  Future<HealthObservation?> getObservation(String observationId) async =>
      store.observations[observationId];

  @override
  Future<List<HealthObservation>> listObservationsForPatient(
    String patientId,
  ) async {
    return store.observations.values
        .where((o) => o.patientId == patientId)
        .toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  }

  @override
  Future<HealthObservation?> updateObservation(
    HealthObservation observation,
  ) async {
    if (!store.observations.containsKey(observation.observationId)) {
      return null;
    }
    return saveObservation(observation);
  }

  @override
  Future<HealthObservation?> archiveObservation(String observationId) async {
    final old = store.observations[observationId];
    if (old == null) return null;
    final archived = HealthObservation(
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
      status: HealthRecordStatus.archived,
      supersedesId: old.supersedesId,
    );
    store.observations[observationId] = archived;
    return archived;
  }

  /// Mutating the projection must not change relational truth.
  void corruptGraphOnly() {
    graph.nodes.clear();
    graph.edges.clear();
  }

  /// Graph edges come only from health_relationships, not a second store.
  Future<void> rebuildGraphFromRelationships() async {
    graph.clear();
    for (final e in store.relationships) {
      graph.edges.add(
        HealthGraphEdge(
          sourceId: e.sourceId,
          relation: e.relationshipType,
          targetId: e.targetId,
        ),
      );
    }
  }
}
