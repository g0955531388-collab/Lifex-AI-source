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
