/// =============================================================
/// Lifex-AI — عقود تصدير Clinical/PHR
/// EXPORT ≠ SHARE ≠ PRINT · LLM ≠ SoT · Minimum necessary
/// =============================================================
library lifex_ai.core.health_data.clinical_phr_export_types;

/// تصنيف حساسية عنصر مُصدَّر — ليس تشخيصاً.
enum PhrExportDataClassification {
  private,
  sensitive,
  highlySensitive,
  restricted,
}

extension PhrExportDataClassificationX on PhrExportDataClassification {
  String get wireName {
    switch (this) {
      case PhrExportDataClassification.private:
        return 'PRIVATE';
      case PhrExportDataClassification.sensitive:
        return 'SENSITIVE';
      case PhrExportDataClassification.highlySensitive:
        return 'HIGHLY_SENSITIVE';
      case PhrExportDataClassification.restricted:
        return 'RESTRICTED';
    }
  }
}

/// نطاقات تصدير معلنة — فقط المدعوم فعلياً يُملأ بالبيانات.
enum PhrExportScopeKind {
  /// ملاحظات محددة بالمعرّفات.
  selectedObservations,

  /// كل ملاحظات المريض المتاحة عبر Canonical Owner.
  patientObservations,

  /// Complete PHR — قرار سياسة مستقل؛ يضم فقط النطاقات المدعومة.
  completePhr,

  /// غير مدعومة في هذا البناء (لا بيانات domain جاهزة).
  medications,
  allergies,
  encounters,
  laboratoryResults,
  imagingMetadata,
  clinicalDocuments,
}

extension PhrExportScopeKindX on PhrExportScopeKind {
  String get wireName => name;

  bool get isSupportedInThisBuild {
    switch (this) {
      case PhrExportScopeKind.selectedObservations:
      case PhrExportScopeKind.patientObservations:
      case PhrExportScopeKind.completePhr:
        return true;
      case PhrExportScopeKind.medications:
      case PhrExportScopeKind.allergies:
      case PhrExportScopeKind.encounters:
      case PhrExportScopeKind.laboratoryResults:
      case PhrExportScopeKind.imagingMetadata:
      case PhrExportScopeKind.clinicalDocuments:
        return false;
    }
  }

  PhrExportDataClassification get defaultClassification {
    switch (this) {
      case PhrExportScopeKind.selectedObservations:
      case PhrExportScopeKind.patientObservations:
        return PhrExportDataClassification.sensitive;
      case PhrExportScopeKind.completePhr:
        return PhrExportDataClassification.highlySensitive;
      case PhrExportScopeKind.medications:
      case PhrExportScopeKind.allergies:
      case PhrExportScopeKind.laboratoryResults:
      case PhrExportScopeKind.clinicalDocuments:
        return PhrExportDataClassification.highlySensitive;
      case PhrExportScopeKind.encounters:
      case PhrExportScopeKind.imagingMetadata:
        return PhrExportDataClassification.restricted;
    }
  }
}

/// طلب تصدير — Scope صريح إلزامي.
class ClinicalPhrExportRequest {
  const ClinicalPhrExportRequest({
    required this.patientId,
    required this.purpose,
    required this.requestedScopes,
    this.selectedObservationIds = const [],
    this.format = 'LIFEX_PHR_EXPORT_JSON_V1',
    this.allowCompletePhr = false,
  });

  final String patientId;
  final String purpose;
  final Set<PhrExportScopeKind> requestedScopes;
  final List<String> selectedObservationIds;
  final String format;

  /// موافقة/قرار صريح لـ complete PHR — ليس تجميع repository تلقائي.
  final bool allowCompletePhr;
}

/// عنصر مُصدَّر واحد — provenance + هوية + تصنيف.
class PhrExportItem {
  const PhrExportItem({
    required this.entityType,
    required this.entityId,
    required this.classification,
    required this.observedOrRecordedAt,
    required this.payload,
    required this.provenance,
    this.sourceType = '',
    this.sourceId = '',
    this.version,
  });

  final String entityType;
  final String entityId;
  final PhrExportDataClassification classification;
  final DateTime observedOrRecordedAt;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> provenance;
  final String sourceType;
  final String sourceId;
  final String? version;

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'entityId': entityId,
        'classification': classification.wireName,
        'observedOrRecordedAt': observedOrRecordedAt.toIso8601String(),
        'sourceType': sourceType,
        'sourceId': sourceId,
        if (version != null) 'version': version,
        'provenance': provenance,
        'payload': payload,
      };
}

/// معلومات سلامة — CONTENT_HASH وليس توقيعاً رقمياً.
class PhrExportIntegrity {
  const PhrExportIntegrity({
    required this.algorithm,
    required this.digestHex,
    this.kind = 'CONTENT_HASH',
    this.isDigitalSignature = false,
  });

  final String algorithm;
  final String digestHex;
  final String kind;
  final bool isDigitalSignature;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'algorithm': algorithm,
        'digestHex': digestHex,
        'isDigitalSignature': isDigitalSignature,
        'note':
            'CONTENT_HASH only — not a digital signature; no signing key used.',
      };
}

/// Artifact تصدير — لا ينتج إن فشل المسار (Fail-Closed).
class PhrExportArtifact {
  const PhrExportArtifact({
    required this.exportId,
    required this.patientIdRef,
    required this.accountIdRef,
    required this.createdAt,
    required this.purpose,
    required this.requestedScope,
    required this.actualScope,
    required this.unsupportedScopes,
    required this.format,
    required this.schemaVersion,
    required this.items,
    required this.integrity,
    required this.auditReference,
    required this.provenanceSummary,
  });

  static const schemaVersionValue = '1.0.0';
  static const formatValue = 'LIFEX_PHR_EXPORT_JSON_V1';

  final String exportId;
  final String patientIdRef;
  final String accountIdRef;
  final DateTime createdAt;
  final String purpose;
  final List<String> requestedScope;
  final List<String> actualScope;
  final List<String> unsupportedScopes;
  final String format;
  final String schemaVersion;
  final List<PhrExportItem> items;
  final PhrExportIntegrity integrity;
  final String auditReference;
  final Map<String, dynamic> provenanceSummary;

  Map<String, dynamic> toJson() => {
        'exportId': exportId,
        'patientIdRef': patientIdRef,
        'accountIdRef': accountIdRef,
        'createdAt': createdAt.toIso8601String(),
        'purpose': purpose,
        'requestedScope': requestedScope,
        'actualScope': actualScope,
        'unsupportedScopes': unsupportedScopes,
        'format': format,
        'schemaVersion': schemaVersion,
        'items': items.map((e) => e.toJson()).toList(),
        'integrity': integrity.toJson(),
        'auditReference': auditReference,
        'provenanceSummary': provenanceSummary,
        'llmIsSourceOfTruth': false,
        'exportIsNotShare': true,
        'exportIsNotPrint': true,
      };

  /// حمولة للتجزئة — بلا حقل integrity نفسه.
  Map<String, dynamic> toIntegrityPayload() {
    final full = toJson();
    full.remove('integrity');
    return full;
  }
}

/// نتيجة Use Case — Fail-Closed بلا artifact عند الفشل.
class ClinicalPhrExportResult {
  const ClinicalPhrExportResult({
    required this.succeeded,
    required this.reasonCode,
    required this.messageAr,
    this.artifact,
  });

  final bool succeeded;
  final String reasonCode;
  final String messageAr;
  final PhrExportArtifact? artifact;

  factory ClinicalPhrExportResult.failed({
    required String reasonCode,
    required String messageAr,
  }) {
    return ClinicalPhrExportResult(
      succeeded: false,
      reasonCode: reasonCode,
      messageAr: messageAr,
    );
  }

  factory ClinicalPhrExportResult.ok({
    required PhrExportArtifact artifact,
    required String messageAr,
  }) {
    return ClinicalPhrExportResult(
      succeeded: true,
      reasonCode: 'EXPORT_OK',
      messageAr: messageAr,
      artifact: artifact,
    );
  }
}
