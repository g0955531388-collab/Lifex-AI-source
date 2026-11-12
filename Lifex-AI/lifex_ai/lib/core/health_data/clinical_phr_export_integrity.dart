/// =============================================================
/// Lifex-AI — سلامة Export Artifact (CONTENT_HASH ≠ توقيع رقمي)
/// =============================================================
library lifex_ai.core.health_data.clinical_phr_export_integrity;

import 'dart:convert';

import 'clinical_phr_export_types.dart';

class ClinicalPhrExportIntegrity {
  const ClinicalPhrExportIntegrity();

  static const algorithmId = 'FNV-1a-64';
  static const serviceId = 'ClinicalPhrExportIntegrity';

  /// تجزئة محتوى مستقرة — ليست توقيعاً رقمياً ولا تستخدم مفتاح توقيع.
  PhrExportIntegrity hashPayload(Map<String, dynamic> payloadWithoutIntegrity) {
    final canonical = jsonEncode(_sortDeep(payloadWithoutIntegrity));
    final digest = _fnv1a64Hex(canonical);
    return PhrExportIntegrity(
      algorithm: algorithmId,
      digestHex: digest,
      kind: 'CONTENT_HASH',
      isDigitalSignature: false,
    );
  }

  bool verify(PhrExportArtifact artifact) {
    final expected = hashPayload(artifact.toIntegrityPayload());
    return expected.digestHex == artifact.integrity.digestHex &&
        artifact.integrity.algorithm == algorithmId &&
        artifact.integrity.isDigitalSignature == false;
  }

  dynamic _sortDeep(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return {
        for (final k in keys) k: _sortDeep(value[k]),
      };
    }
    if (value is List) {
      return value.map(_sortDeep).toList();
    }
    return value;
  }

  String _fnv1a64Hex(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
