/// =============================================================
/// Lifex-AI — بناء Export Artifact من Canonical Owner فقط
/// =============================================================
library lifex_ai.core.health_data.clinical_phr_export_builder;

import 'health_data_types.dart';
import 'health_observation_codecs.dart';
import 'clinical_phr_export_integrity.dart';
import 'clinical_phr_export_policy.dart';
import 'clinical_phr_export_types.dart';

class ClinicalPhrExportBuilder {
  ClinicalPhrExportBuilder({
    this.policy = const ClinicalPhrExportPolicy(),
    this.integrity = const ClinicalPhrExportIntegrity(),
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const builderId = 'ClinicalPhrExportBuilder';

  final ClinicalPhrExportPolicy policy;
  final ClinicalPhrExportIntegrity integrity;
  final DateTime Function() _clock;

  PhrExportArtifact build({
    required String exportId,
    required String accountIdRef,
    required String auditReference,
    required ClinicalPhrExportRequest request,
    required Set<PhrExportScopeKind> effectiveScopes,
    required Set<PhrExportScopeKind> unsupportedScopes,
    required List<HealthObservation> observations,
    required Map<String, ProvenanceRecord> provenanceById,
  }) {
    final items = <PhrExportItem>[];
    for (final obs in observations) {
      final prov = provenanceById[obs.provenanceId];
      final payload = policy.sanitizeMap(HealthObservationCodecs.toJson(obs));
      items.add(
        PhrExportItem(
          entityType: 'HealthObservation',
          entityId: obs.observationId,
          classification: PhrExportDataClassification.sensitive,
          observedOrRecordedAt: obs.observedAt,
          sourceType: obs.sourceType,
          sourceId: obs.sourceId,
          version: null,
          provenance: prov == null
              ? {
                  'provenanceId': obs.provenanceId,
                  'status': 'MISSING_PROVENANCE_REF',
                }
              : policy.sanitizeMap(ProvenanceCodecs.toJson(prov)),
          payload: payload,
        ),
      );
    }

    final createdAt = _clock();
    final draft = PhrExportArtifact(
      exportId: exportId,
      patientIdRef: request.patientId,
      accountIdRef: accountIdRef,
      createdAt: createdAt,
      purpose: request.purpose,
      requestedScope:
          request.requestedScopes.map((e) => e.wireName).toList()..sort(),
      actualScope: effectiveScopes.map((e) => e.wireName).toList()..sort(),
      unsupportedScopes:
          unsupportedScopes.map((e) => e.wireName).toList()..sort(),
      format: request.format,
      schemaVersion: PhrExportArtifact.schemaVersionValue,
      items: items,
      integrity: const PhrExportIntegrity(
        algorithm: ClinicalPhrExportIntegrity.algorithmId,
        digestHex: 'pending',
      ),
      auditReference: auditReference,
      provenanceSummary: {
        'itemCount': items.length,
        'provenancePresentCount': items
            .where((i) => i.provenance['sourceId'] != null)
            .length,
        'canonicalOwner': 'HealthObservationRepository',
        'llmIsSourceOfTruth': false,
      },
    );

    final digest = integrity.hashPayload(draft.toIntegrityPayload());
    return PhrExportArtifact(
      exportId: draft.exportId,
      patientIdRef: draft.patientIdRef,
      accountIdRef: draft.accountIdRef,
      createdAt: draft.createdAt,
      purpose: draft.purpose,
      requestedScope: draft.requestedScope,
      actualScope: draft.actualScope,
      unsupportedScopes: draft.unsupportedScopes,
      format: draft.format,
      schemaVersion: draft.schemaVersion,
      items: draft.items,
      integrity: digest,
      auditReference: draft.auditReference,
      provenanceSummary: draft.provenanceSummary,
    );
  }
}
