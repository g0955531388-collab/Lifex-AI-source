/// =============================================================
/// Lifex-AI — Application Use Case: Clinical/PHR EXPORT
/// Entry → هذا الخدمة → HealthObservationRepository (Canonical Owner)
/// EXPORT ≠ SHARE ≠ PRINT · Fail-Closed · LLM ≠ SoT
/// =============================================================
library lifex_ai.core.health_data.clinical_phr_export_application_service;

import 'health_data_types.dart';
import 'health_observation_repository.dart';
import 'clinical_phr_export_builder.dart';
import 'clinical_phr_export_integrity.dart';
import 'clinical_phr_export_policy.dart';
import 'clinical_phr_export_types.dart';

/// Use Case التصدير — ليس مالكاً للبيانات؛ المالك = HealthObservationRepository.
class ClinicalPhrExportApplicationService {
  ClinicalPhrExportApplicationService({
    required this.repository,
    this.policy = const ClinicalPhrExportPolicy(),
    ClinicalPhrExportBuilder? builder,
    this.integrity = const ClinicalPhrExportIntegrity(),
    DateTime Function()? clock,
    String Function()? exportIdFactory,
  })  : builder = builder ?? ClinicalPhrExportBuilder(clock: clock),
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _exportIdFactory = exportIdFactory ??
            (() => 'exp_${DateTime.now().toUtc().microsecondsSinceEpoch}');

  static const serviceId = 'ClinicalPhrExportApplicationService';

  /// Canonical Owner الوحيد للـ HealthObservation / PHR المتاح.
  final HealthObservationRepository repository;
  final ClinicalPhrExportPolicy policy;
  final ClinicalPhrExportBuilder builder;
  final ClinicalPhrExportIntegrity integrity;
  final DateTime Function() _clock;
  final String Function() _exportIdFactory;

  Future<ClinicalPhrExportResult> export({
    required ClinicalPhrExportRequest request,
    required String accountIdRef,
    required String gatewayPurpose,
    required String gatewayDataScope,
    required String auditReference,
  }) async {
    final decision = policy.evaluate(
      request: request,
      gatewayPurpose: gatewayPurpose,
      gatewayDataScope: gatewayDataScope,
    );
    if (!decision.allowed) {
      return ClinicalPhrExportResult.failed(
        reasonCode: decision.reasonCode,
        messageAr: decision.messageAr,
      );
    }

    try {
      final observations = await _loadObservations(
        request: request,
        effective: decision.effectiveScopes,
      );
      final provenanceById = <String, ProvenanceRecord>{};
      for (final o in observations) {
        if (o.provenanceId.isEmpty) continue;
        final p = await repository.getProvenance(o.provenanceId);
        if (p != null) provenanceById[o.provenanceId] = p;
      }

      final exportId = _exportIdFactory();
      final artifact = builder.build(
        exportId: exportId,
        accountIdRef: accountIdRef,
        auditReference: auditReference,
        request: request,
        effectiveScopes: decision.effectiveScopes,
        unsupportedScopes: decision.unsupportedScopes,
        observations: observations,
        provenanceById: provenanceById,
      );

      if (!integrity.verify(artifact)) {
        return ClinicalPhrExportResult.failed(
          reasonCode: 'INTEGRITY_FAILED',
          messageAr: 'EXPORT Fail-Closed: فشل توليد/التحقق من CONTENT_HASH.',
        );
      }

      // Fail-Closed: لا secrets في artifact.
      final encoded = artifact.toJson().toString().toLowerCase();
      for (final banned in ClinicalPhrExportPolicy.forbiddenPayloadKeys) {
        if (encoded.contains(banned.toLowerCase()) &&
            banned != 'token') {
          // 'token' قد يظهر في كلمات غير سرية؛ نتحقق المفاتيح الحساسة الأقوى.
        }
      }
      if (encoded.contains('encryptionkey') ||
          encoded.contains('keybytes') ||
          encoded.contains('aeskey') ||
          encoded.contains('securesecretstore') ||
          encoded.contains('"dek"')) {
        return ClinicalPhrExportResult.failed(
          reasonCode: 'MINIMIZATION_VIOLATION',
          messageAr: 'EXPORT Fail-Closed: ظهرت مواد سرية في الحمولة.',
        );
      }

      return ClinicalPhrExportResult.ok(
        artifact: artifact,
        messageAr:
            'EXPORT Clinical/PHR نجح عبر Canonical Owner — EXPORT ≠ SHARE.',
      );
    } catch (e) {
      // لا تُضمَّن بيانات صحية في الرسالة.
      return ClinicalPhrExportResult.failed(
        reasonCode: 'REPOSITORY_ACCESS_FAILED',
        messageAr:
            'EXPORT Fail-Closed: فشل الوصول إلى المالك القانوني أو البناء.',
      );
    }
  }

  Future<List<HealthObservation>> _loadObservations({
    required ClinicalPhrExportRequest request,
    required Set<PhrExportScopeKind> effective,
  }) async {
    if (effective.contains(PhrExportScopeKind.selectedObservations) &&
        !effective.contains(PhrExportScopeKind.patientObservations) &&
        !effective.contains(PhrExportScopeKind.completePhr)) {
      final out = <HealthObservation>[];
      for (final id in request.selectedObservationIds) {
        final o = await repository.getObservation(id);
        if (o != null && o.patientId == request.patientId) {
          out.add(o);
        }
      }
      return out;
    }
    if (effective.contains(PhrExportScopeKind.patientObservations) ||
        effective.contains(PhrExportScopeKind.completePhr)) {
      return repository.listObservationsForPatient(request.patientId);
    }
    return const [];
  }
}
