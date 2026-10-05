/// =============================================================
/// Lifex-AI — Application Service لملاحظات الصحة
/// UI → LIO Entry → هذا الخدمة → HealthDataRepository → Data
/// ليست مالكة البيانات؛ المالك الكانوني هو Repository/Data.
/// AI/LLM/UI ليست مصدراً للحقيقة الطبية.
/// =============================================================
library lifex_ai.core.health_data.health_observation_application_service;

import 'health_data_types.dart';
import 'health_repository.dart';

/// نتيجة تشغيل Application بعد تفويض LIO.
class HealthObservationOpResult {
  const HealthObservationOpResult({
    required this.success,
    required this.messageAr,
    this.observation,
    this.observations = const [],
  });

  final bool success;
  final String messageAr;
  final HealthObservation? observation;
  final List<HealthObservation> observations;

  factory HealthObservationOpResult.ok({
    required String messageAr,
    HealthObservation? observation,
    List<HealthObservation> observations = const [],
  }) {
    return HealthObservationOpResult(
      success: true,
      messageAr: messageAr,
      observation: observation,
      observations: observations,
    );
  }

  factory HealthObservationOpResult.failed(String messageAr) {
    return HealthObservationOpResult(success: false, messageAr: messageAr);
  }
}

/// المالك التشغيلي لعمليات HealthObservation (ليس LIO، ليس UI).
class HealthObservationApplicationService {
  HealthObservationApplicationService({required this.repository});

  static const serviceId = 'HealthObservationApplicationService';

  /// Canonical data owner lives behind this interface.
  final HealthDataRepository repository;

  Future<HealthObservationOpResult> readForPatient({
    required String patientId,
  }) async {
    final list = await repository.listObservationsForPatient(patientId);
    return HealthObservationOpResult.ok(
      messageAr: 'قُرئت ${list.length} ملاحظة صحية.',
      observations: list,
    );
  }

  Future<HealthObservationOpResult> write({
    required HealthObservation observation,
    required ProvenanceRecord provenance,
  }) async {
    if (observation.patientId.trim().isEmpty ||
        observation.conceptId.trim().isEmpty) {
      return HealthObservationOpResult.failed(
        'WRITE مرفوض: patientId/conceptId إلزاميان.',
      );
    }
    await repository.ensureProvenance(provenance);
    final withProv = observation.provenanceId.isEmpty
        ? HealthObservation(
            observationId: observation.observationId,
            patientId: observation.patientId,
            conceptId: observation.conceptId,
            value: observation.value,
            unit: observation.unit,
            observedAt: observation.observedAt,
            sourceType: observation.sourceType,
            sourceId: observation.sourceId,
            provenanceId: provenance.sourceId,
            method: observation.method,
            quality: observation.quality,
            status: observation.status,
            supersedesId: observation.supersedesId,
          )
        : observation;
    final saved = await repository.saveObservation(withProv);
    if (saved == null) {
      return HealthObservationOpResult.failed(
        'تعذّر حفظ الملاحظة — تحقق من Provenance.',
      );
    }
    return HealthObservationOpResult.ok(
      messageAr: 'كُتبت الملاحظة في المستودع الكانوني.',
      observation: saved,
    );
  }

  Future<HealthObservationOpResult> update({
    required HealthObservation observation,
    required ProvenanceRecord provenance,
  }) async {
    final existing =
        await repository.getObservation(observation.observationId);
    if (existing == null) {
      return HealthObservationOpResult.failed(
        'UPDATE مرفوض: الملاحظة غير موجودة.',
      );
    }
    await repository.ensureProvenance(provenance);
    final saved = await repository.updateObservation(observation);
    if (saved == null) {
      return HealthObservationOpResult.failed('تعذّر تحديث الملاحظة.');
    }
    return HealthObservationOpResult.ok(
      messageAr: 'حُدّثت الملاحظة في المستودع الكانوني.',
      observation: saved,
    );
  }

  /// ARCHIVE — ليس DELETE صعب.
  Future<HealthObservationOpResult> archive({
    required String observationId,
  }) async {
    final archived = await repository.archiveObservation(observationId);
    if (archived == null) {
      return HealthObservationOpResult.failed(
        'ARCHIVE مرفوض: الملاحظة غير موجودة.',
      );
    }
    return HealthObservationOpResult.ok(
      messageAr: 'أُرشفت الملاحظة (ARCHIVE ≠ DELETE).',
      observation: archived,
    );
  }
}
