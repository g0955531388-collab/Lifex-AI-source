/// =============================================================
/// Lifex-AI — استعلام
/// الملف: health_query_service.dart
/// =============================================================
import 'health_data_engine.dart';
import 'health_data_types.dart';
import 'health_schema.dart';

/// AI / UI must not open patient tables. Knowledge may be queried.
class HealthQueryService {
  HealthQueryService(this.engine);

  final LifexHealthDataEngine engine;

  bool allowDirectTable(String table) => HealthSchemaCatalog.aiMayAccessDirectly(table);

  Disease? getDisease(String id) => engine.getDisease(id);

  List<HealthObservation> getObservations({
    required String actorId,
    required String patientId,
    required DateTime at,
  }) {
    if (!engine.canReadPatient(
      patientId,
      'observation.read',
      at,
      actorId: actorId,
    )) {
      return const [];
    }
    return engine.getObservations(patientId, at: at);
  }

  HealthTimeline? getTimeline({
    required String actorId,
    required String patientId,
    required DateTime at,
  }) {
    if (!engine.canReadPatient(
      patientId,
      'timeline.read',
      at,
      actorId: actorId,
    )) {
      return null;
    }
    return engine.getHealthTimeline(patientId, at: at);
  }
}
