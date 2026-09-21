/// =============================================================
/// Lifex-AI — InMemory HealthObservationRepository (اختبارات فقط)
/// ممنوع في LifexProductionComposition / مسار الإنتاج.
/// =============================================================
library lifex_ai.core.health_data.in_memory_health_observation_repository;

import 'health_data_types.dart';
import 'health_observation_repository.dart';

/// تنفيذ اختباري فقط — لا يدخل Production Composition.
class InMemoryHealthObservationRepository
    implements HealthObservationRepository {
  InMemoryHealthObservationRepository();

  static const implementationId = 'InMemoryHealthObservationRepository';
  static const testOnlyMarker = 'TEST_ONLY_IN_MEMORY_HEALTH_OBSERVATION';

  final Map<String, HealthObservation> observations = {};
  final Map<String, ProvenanceRecord> provenance = {};

  @override
  Future<void> ensureProvenance(ProvenanceRecord record) async {
    provenance[record.sourceId] = record;
  }

  @override
  Future<HealthObservation?> saveObservation(
    HealthObservation observation,
  ) async {
    if (observation.provenanceId.isEmpty ||
        !provenance.containsKey(observation.provenanceId)) {
      return null;
    }
    observations[observation.observationId] = observation;
    if (observation.supersedesId != null) {
      final old = observations[observation.supersedesId];
      if (old != null && old.status == HealthRecordStatus.active) {
        observations[old.observationId] = HealthObservation(
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
    return observations[observation.observationId];
  }

  @override
  Future<HealthObservation?> getObservation(String observationId) async =>
      observations[observationId];

  @override
  Future<List<HealthObservation>> listObservationsForPatient(
    String patientId,
  ) async {
    return observations.values
        .where((o) => o.patientId == patientId)
        .toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  }

  @override
  Future<HealthObservation?> updateObservation(
    HealthObservation observation,
  ) async {
    if (!observations.containsKey(observation.observationId)) return null;
    return saveObservation(observation);
  }

  @override
  Future<HealthObservation?> archiveObservation(String observationId) async {
    final old = observations[observationId];
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
    observations[observationId] = archived;
    return archived;
  }

  @override
  Future<bool> deleteObservation(String observationId) async {
    return observations.remove(observationId) != null;
  }
}
