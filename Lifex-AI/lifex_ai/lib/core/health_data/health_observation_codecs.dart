/// =============================================================
/// Lifex-AI — Codecs لـ HealthObservation / Provenance (persistence)
/// =============================================================
library lifex_ai.core.health_data.health_observation_codecs;

import 'health_data_types.dart';

class ProvenanceCodecs {
  const ProvenanceCodecs._();

  static Map<String, dynamic> toJson(ProvenanceRecord p) => {
        'sourceId': p.sourceId,
        'sourceName': p.sourceName,
        'sourceType': p.sourceType,
        'version': p.version,
        'retrievedAt': p.retrievedAt.toIso8601String(),
        if (p.effectiveAt != null)
          'effectiveAt': p.effectiveAt!.toIso8601String(),
        'verificationStatus': p.verificationStatus,
      };

  static ProvenanceRecord fromJson(Map<String, dynamic> json) {
    return ProvenanceRecord(
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? '',
      version: json['version']?.toString() ?? '1',
      retrievedAt: DateTime.tryParse(json['retrievedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      effectiveAt: json['effectiveAt'] == null
          ? null
          : DateTime.tryParse(json['effectiveAt'].toString()),
      verificationStatus:
          json['verificationStatus']?.toString() ?? 'unverified',
    );
  }
}

class HealthObservationCodecs {
  const HealthObservationCodecs._();

  static Map<String, dynamic> toJson(HealthObservation o) => {
        'observationId': o.observationId,
        'patientId': o.patientId,
        'conceptId': o.conceptId,
        'value': o.value,
        'unit': o.unit,
        'observedAt': o.observedAt.toIso8601String(),
        'sourceType': o.sourceType,
        'sourceId': o.sourceId,
        'provenanceId': o.provenanceId,
        'method': o.method,
        'quality': o.quality.name,
        'status': o.status.name,
        if (o.supersedesId != null) 'supersedesId': o.supersedesId,
      };

  static HealthObservation fromJson(Map<String, dynamic> json) {
    return HealthObservation(
      observationId: json['observationId']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      conceptId: json['conceptId']?.toString() ?? '',
      value: json['value'],
      unit: json['unit']?.toString() ?? '',
      observedAt: DateTime.tryParse(json['observedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceType: json['sourceType']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      provenanceId: json['provenanceId']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      quality: _quality(json['quality']?.toString()),
      status: _status(json['status']?.toString()),
      supersedesId: json['supersedesId']?.toString(),
    );
  }

  static ObservationQuality _quality(String? name) {
    return ObservationQuality.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ObservationQuality.unknown,
    );
  }

  static HealthRecordStatus _status(String? name) {
    return HealthRecordStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => HealthRecordStatus.active,
    );
  }
}
