/// =============================================================
/// Lifex-AI — واجهة مستودع HealthObservation (المالك القانوني)
/// Application → Domain → HealthObservationRepository → Persistent Store
/// AI/LLM/UI/LIO ليست مالكة لهذه البيانات.
/// =============================================================
library lifex_ai.core.health_data.health_observation_repository;

import 'health_data_types.dart';

/// المالك القانوني الوحيد لبيانات HealthObservation.
abstract class HealthObservationRepository {
  static const ownerId = 'HealthObservationRepository';

  Future<void> ensureProvenance(ProvenanceRecord provenance);
  Future<HealthObservation?> saveObservation(HealthObservation observation);
  Future<HealthObservation?> getObservation(String observationId);
  Future<List<HealthObservation>> listObservationsForPatient(String patientId);
  Future<HealthObservation?> updateObservation(HealthObservation observation);

  /// ARCHIVE — soft status. ليس DELETE.
  Future<HealthObservation?> archiveObservation(String observationId);

  /// DELETE — إزالة صلبة من المخزن. ليس ARCHIVE.
  Future<bool> deleteObservation(String observationId);
}

/// تجريد البنية التحتية — يُستبدل دون لمس Domain/Application.
abstract class HealthObservationPersistentStore {
  static const storeId = 'HealthObservationPersistentStore';

  Future<String?> readRaw();
  Future<void> writeRaw(String contents);
}
