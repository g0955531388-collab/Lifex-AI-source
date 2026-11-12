/// =============================================================
/// Lifex-AI — سياسة تصدير Clinical/PHR (Scope / Minimization)
/// =============================================================
library lifex_ai.core.health_data.clinical_phr_export_policy;

import 'clinical_phr_export_types.dart';

class ClinicalPhrExportPolicyDecision {
  const ClinicalPhrExportPolicyDecision({
    required this.allowed,
    required this.reasonCode,
    required this.messageAr,
    this.effectiveScopes = const {},
    this.unsupportedScopes = const {},
  });

  final bool allowed;
  final String reasonCode;
  final String messageAr;
  final Set<PhrExportScopeKind> effectiveScopes;
  final Set<PhrExportScopeKind> unsupportedScopes;
}

/// سياسة التصدير — قرار مستقل لـ complete PHR + minimum necessary.
class ClinicalPhrExportPolicy {
  const ClinicalPhrExportPolicy();

  static const policyId = 'ClinicalPhrExportPolicy';

  static const forbiddenPayloadKeys = {
    'password',
    'passwd',
    'secret',
    'token',
    'accessToken',
    'refreshToken',
    'apiKey',
    'encryptionKey',
    'dek',
    'keyBytes',
    'aesKey',
    'privateKey',
    'secureSecretStore',
    'cvv',
    'pan',
  };

  /// أغراض تصدير مسموحة (تشغيلية — ليست قائمة أمراض).
  static const allowedExportPurposes = {
    'phr_export',
    'care_support',
  };

  ClinicalPhrExportPolicyDecision evaluate({
    required ClinicalPhrExportRequest request,
    required String gatewayPurpose,
    required String gatewayDataScope,
  }) {
    if (request.patientId.trim().isEmpty) {
      return const ClinicalPhrExportPolicyDecision(
        allowed: false,
        reasonCode: 'EXPORT_VALIDATION_FAILED',
        messageAr: 'EXPORT مرفوض: patientId إلزامي.',
      );
    }
    if (request.requestedScopes.isEmpty) {
      return const ClinicalPhrExportPolicyDecision(
        allowed: false,
        reasonCode: 'SCOPE_REQUIRED',
        messageAr: 'EXPORT مرفوض: DataScope/requestedScopes إلزامي وصريح.',
      );
    }
    if (!allowedExportPurposes.contains(request.purpose.trim()) &&
        !allowedExportPurposes.contains(gatewayPurpose.trim())) {
      return const ClinicalPhrExportPolicyDecision(
        allowed: false,
        reasonCode: 'PURPOSE_VIOLATION',
        messageAr:
            'EXPORT مرفوض: purpose خارج قائمة أغراض التصدير المعتمدة.',
      );
    }

    final unsupported = <PhrExportScopeKind>{};
    final effective = <PhrExportScopeKind>{};

    for (final scope in request.requestedScopes) {
      if (!scope.isSupportedInThisBuild) {
        unsupported.add(scope);
        continue;
      }
      if (scope == PhrExportScopeKind.completePhr) {
        if (!request.allowCompletePhr) {
          return const ClinicalPhrExportPolicyDecision(
            allowed: false,
            reasonCode: 'COMPLETE_PHR_POLICY_DENIED',
            messageAr:
                'Complete PHR Export مرفوض: يتطلب قرار Authorization/Consent '
                'وسماح صريح (allowCompletePhr) — ليس تجميع repository تلقائي.',
          );
        }
        if (gatewayDataScope.trim() != 'phr_export_complete') {
          return const ClinicalPhrExportPolicyDecision(
            allowed: false,
            reasonCode: 'COMPLETE_PHR_SCOPE_MISMATCH',
            messageAr:
                'Complete PHR يتطلب dataScope=phr_export_complete من بوابة LIO.',
          );
        }
        // Complete PHR يفعّل فقط النطاقات المدعومة فعلياً (observations).
        effective.add(PhrExportScopeKind.patientObservations);
        effective.add(PhrExportScopeKind.completePhr);
        continue;
      }
      if (scope == PhrExportScopeKind.selectedObservations &&
          request.selectedObservationIds.isEmpty) {
        return const ClinicalPhrExportPolicyDecision(
          allowed: false,
          reasonCode: 'SCOPE_REQUIRED',
          messageAr:
              'selectedObservations يتطلب قائمة selectedObservationIds غير فارغة.',
        );
      }
      effective.add(scope);
    }

    if (effective.isEmpty) {
      return ClinicalPhrExportPolicyDecision(
        allowed: false,
        reasonCode: 'UNSUPPORTED_SCOPE',
        messageAr:
            'لا نطاق مدعوم في الطلب — المجالات غير المتوفرة تبقى خارج Export.',
        unsupportedScopes: unsupported,
      );
    }

    return ClinicalPhrExportPolicyDecision(
      allowed: true,
      reasonCode: 'EXPORT_POLICY_OK',
      messageAr: 'سياسة التصدير تسمح بالنطاق الفعّال.',
      effectiveScopes: effective,
      unsupportedScopes: unsupported,
    );
  }

  /// إزالة مفاتيح سرية من خرائط الحمولة (minimum necessary).
  Map<String, dynamic> sanitizeMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      final lower = key.toLowerCase();
      if (forbiddenPayloadKeys.any((f) => lower.contains(f.toLowerCase()))) {
        return;
      }
      if (value is Map) {
        out[key] = sanitizeMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        out[key] = value.map((e) {
          if (e is Map) return sanitizeMap(Map<String, dynamic>.from(e));
          return e;
        }).toList();
      } else {
        out[key] = value;
      }
    });
    return out;
  }
}
