/// =============================================================
/// Lifex-AI — Persistent HealthObservationRepository
/// يقرأ/يكتب عبر HealthObservationPersistentStore فقط.
/// =============================================================
library lifex_ai.core.health_data.persistent_health_observation_repository;

import 'dart:convert';

import 'health_data_types.dart';
import 'health_observation_codecs.dart';
import 'health_observation_repository.dart';

/// تنفيذ إنتاجي دائم — المالك القانوني خلف الواجهة.
class PersistentHealthObservationRepository
    implements HealthObservationRepository {
  PersistentHealthObservationRepository({required this.store});

  static const implementationId = 'PersistentHealthObservationRepository';

  final HealthObservationPersistentStore store;

  Map<String, HealthObservation> _observations = {};
  Map<String, ProvenanceRecord> _provenance = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await store.readRaw();
    if (raw == null) {
      _observations = {};
      _provenance = {};
      _loaded = true;
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _observations = {};
      _provenance = {};
      _loaded = true;
      return;
    }
    final map = Map<String, dynamic>.from(decoded);
    final obsRaw = map['observations'];
    final provRaw = map['provenance'];
    _observations = {};
    if (obsRaw is Map) {
      obsRaw.forEach((key, value) {
        if (value is Map) {
          _observations[key.toString()] =
              HealthObservationCodecs.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }
    _provenance = {};
    if (provRaw is Map) {
      provRaw.forEach((key, value) {
        if (value is Map) {
          _provenance[key.toString()] =
              ProvenanceCodecs.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final payload = <String, dynamic>{
      'observations': {
        for (final e in _observations.entries)
          e.key: HealthObservationCodecs.toJson(e.value),
      },
      'provenance': {
        for (final e in _provenance.entries)
          e.key: ProvenanceCodecs.toJson(e.value),
      },
    };
    await store.writeRaw(jsonEncode(payload));
  }

  @override
  Future<void> ensureProvenance(ProvenanceRecord provenance) async {
    await _ensureLoaded();
    _provenance[provenance.sourceId] = provenance;
    await _persist();
  }

  @override
  Future<HealthObservation?> saveObservation(
    HealthObservation observation,
  ) async {
    await _ensureLoaded();
    if (observation.provenanceId.isEmpty ||
        !_provenance.containsKey(observation.provenanceId)) {
      return null;
    }
    _observations[observation.observationId] = observation;
    if (observation.supersedesId != null) {
      final old = _observations[observation.supersedesId];
      if (old != null && old.status == HealthRecordStatus.active) {
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
    await _persist();
    return _observations[observation.observationId];
  }

  @override
  Future<HealthObservation?> getObservation(String observationId) async {
    await _ensureLoaded();
    return _observations[observationId];
  }

  @override
  Future<List<HealthObservation>> listObservationsForPatient(
    String patientId,
  ) async {
    await _ensureLoaded();
    return _observations.values
        .where((o) => o.patientId == patientId)
        .toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  }

  @override
  Future<HealthObservation?> updateObservation(
    HealthObservation observation,
  ) async {
    await _ensureLoaded();
    if (!_observations.containsKey(observation.observationId)) {
      return null;
    }
    return saveObservation(observation);
  }

  @override
  Future<HealthObservation?> archiveObservation(String observationId) async {
    await _ensureLoaded();
    final old = _observations[observationId];
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
    _observations[observationId] = archived;
    await _persist();
    return archived;
  }

  @override
  Future<bool> deleteObservation(String observationId) async {
    await _ensureLoaded();
    final removed = _observations.remove(observationId) != null;
    if (removed) {
      await _persist();
    }
    return removed;
  }
}
