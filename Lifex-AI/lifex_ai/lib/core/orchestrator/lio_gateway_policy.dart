/// =============================================================
/// Lifex-AI — سياسة بوابة LIO الإنتاجية
/// قرار فقط — بلا تشخيص، بلا أدوية، بلا وصول SQL/DB.
/// =============================================================
library lifex_ai.core.orchestrator.lio_gateway_policy;

import 'lio_gateway_contracts.dart';

/// سياسة تقييم الطلبات قبل MCP.
class LioGatewayPolicy {
  const LioGatewayPolicy();

  /// أغراض تشغيلية مسموحة (ليست قائمة أمراض).
  static const allowedPurposes = {
    'care_support',
    'education',
    'scheduling',
    'wallet_ops',
    'donation_public',
    'device_status',
    'emergency_signal',
    'knowledge_lookup',
    'audit_review',
    'settings',
  };

  /// نطاقات بيانات مسموحة عامة/تشغيلية.
  static const allowedScopes = {
    'public',
    'operational',
    'profile_basic',
    'wallet_balance_view',
    'donation_public_search',
    'device_discovery',
    'emergency_contacts_min',
    'knowledge_public',
    'settings_local',
  };

  LioGatewayDecision evaluate(LioGatewayRequest request) {
    final ts = request.timestamp;

    if (!request.hasValidIds ||
        request.purpose.trim().isEmpty ||
        request.requestedAction.trim().isEmpty ||
        request.dataScope.trim().isEmpty) {
      return _deny(
        request,
        reasonCode: 'INVALID_REQUEST',
        reasonAr: 'طلب غير صالح: حقول إلزامية ناقصة أو فارغة.',
        timestamp: ts,
      );
    }

    if (!request.hasValidIdentity) {
      return _deny(
        request,
        reasonCode: 'MISSING_IDENTITY',
        reasonAr: 'هوية/حساب ناقص — Authentication مطلوبة قبل أي Access.',
        timestamp: ts,
      );
    }

    if (!request.authenticated) {
      return _deny(
        request,
        reasonCode: 'UNAUTHENTICATED',
        reasonAr:
            'Authentication فشلت أو ناقصة. Authentication ≠ Authorization ≠ Consent.',
        timestamp: ts,
      );
    }

    if (!request.authorized) {
      return _deny(
        request,
        reasonCode: 'UNAUTHORIZED',
        reasonAr: 'Authorization مرفوضة. الصلاحية منفصلة عن Consent وDevice Trust.',
        timestamp: ts,
      );
    }

    if (request.looksLikeDbBypass) {
      return _deny(
        request,
        reasonCode: 'DB_BYPASS_FORBIDDEN',
        reasonAr:
            'مسار UI/Agent/LIO → DB أو medical driver مباشرة محظور. '
            'المسار: LIO → MCP → Repository فقط.',
        timestamp: ts,
      );
    }

    if (!allowedPurposes.contains(request.purpose.trim())) {
      return _deny(
        request,
        reasonCode: 'PURPOSE_VIOLATION',
        reasonAr: 'Purpose غير مسموح أو خارج قائمة الأغراض التشغيلية المعتمدة.',
        timestamp: ts,
      );
    }

    if (!allowedScopes.contains(request.dataScope.trim()) &&
        !request.emergencyLimitedMode) {
      return _deny(
        request,
        reasonCode: 'SCOPE_VIOLATION',
        reasonAr: 'Data Scope خارج النطاقات المسموحة (purpose limitation).',
        timestamp: ts,
      );
    }

    if (!request.minimumNecessarySatisfied ||
        _excessFields(request) ||
        _clinicalInGeneralMemoryAttempt(request)) {
      return _deny(
        request,
        reasonCode: 'MINIMIZATION_VIOLATION',
        reasonAr:
            'انتهاك data minimization / minimum necessary — '
            'لا تُمرَّر بيانات سريرية إلى ذاكرة LIO العامة.',
        timestamp: ts,
      );
    }

    final needsConsent = request.touchesClinicalScope ||
        request.sensitivity == LioDataSensitivity.personal ||
        request.purpose == 'care_support';
    if (needsConsent &&
        (!request.consent.consentGranted || !request.consent.purposeAligned)) {
      return LioGatewayDecision(
        requestId: request.requestId,
        correlationId: request.correlationId,
        kind: LioGatewayDecisionKind.requireConsent,
        reasonAr: 'Consent مطلوب لهذا الغرض/النطاق. Consent ≠ Authorization.',
        reasonCode: 'CONSENT_REQUIRED',
        timestamp: ts,
        riskLevel: request.riskLevel,
        purpose: request.purpose,
        dataScope: request.dataScope,
        mayProceedToMcp: false,
      );
    }

    if (request.emergencyLimitedMode) {
      // Emergency لا يتجاوز السياسة مطلقاً — مسار محدود فقط + تدقيق.
      if (!request.authenticated || !request.authorized) {
        return _deny(
          request,
          reasonCode: 'EMERGENCY_STILL_REQUIRES_AUTHZ',
          reasonAr:
              'Emergency Limited لا يلغي Authentication/Authorization.',
          timestamp: ts,
        );
      }
      return LioGatewayDecision(
        requestId: request.requestId,
        correlationId: request.correlationId,
        kind: LioGatewayDecisionKind.emergencyLimited,
        reasonAr:
            'EMERGENCY_LIMITED: الحد الأدنى للإشارة/الاتصال فقط — '
            'بلا تجاوز سياسة وبلا وصول سريري كامل.',
        reasonCode: 'EMERGENCY_LIMITED',
        timestamp: ts,
        riskLevel: request.riskLevel,
        purpose: request.purpose,
        dataScope: request.dataScope,
        mayProceedToMcp: true,
      );
    }

    if (request.riskLevel == LioActionRisk.critical) {
      if (!request.reviewApproved) {
        return LioGatewayDecision(
          requestId: request.requestId,
          correlationId: request.correlationId,
          kind: LioGatewayDecisionKind.requireReview,
          reasonAr: 'إجراء critical — يتطلب مراجعة بشرية قبل التنفيذ.',
          reasonCode: 'REQUIRE_REVIEW',
          timestamp: ts,
          riskLevel: request.riskLevel,
          purpose: request.purpose,
          dataScope: request.dataScope,
          mayProceedToMcp: false,
        );
      }
    }

    if (request.riskLevel == LioActionRisk.high ||
        request.approvalRequirement) {
      if (!request.humanConfirmed) {
        return LioGatewayDecision(
          requestId: request.requestId,
          correlationId: request.correlationId,
          kind: LioGatewayDecisionKind.requireConfirmation,
          reasonAr: 'إجراء عالي الخطورة — لا تنفيذ قبل تأكيد بشري صريح.',
          reasonCode: 'REQUIRE_CONFIRMATION',
          timestamp: ts,
          riskLevel: request.riskLevel,
          purpose: request.purpose,
          dataScope: request.dataScope,
          mayProceedToMcp: false,
        );
      }
    }

    if (request.approvalRequirement && !request.stepUpSatisfied) {
      return LioGatewayDecision(
        requestId: request.requestId,
        correlationId: request.correlationId,
        kind: LioGatewayDecisionKind.requireStepUp,
        reasonAr: 'مطلوب رفع مصادقة (step-up) قبل المتابعة.',
        reasonCode: 'REQUIRE_STEP_UP',
        timestamp: ts,
        riskLevel: request.riskLevel,
        purpose: request.purpose,
        dataScope: request.dataScope,
        mayProceedToMcp: false,
      );
    }

    return LioGatewayDecision(
      requestId: request.requestId,
      correlationId: request.correlationId,
      kind: LioGatewayDecisionKind.allow,
      reasonAr: 'ALLOW: الطلب منخفض/متوسط الخطورة ضمن Purpose وScope والحد الأدنى.',
      reasonCode: 'ALLOW',
      timestamp: ts,
      riskLevel: request.riskLevel,
      purpose: request.purpose,
      dataScope: request.dataScope,
      mayProceedToMcp: true,
    );
  }

  bool _excessFields(LioGatewayRequest request) {
    const forbidden = {
      'diagnosis',
      'medication_list',
      'lab_raw',
      'phr_full',
      'pan',
      'cvv',
      'password',
      'api_key',
    };
    for (final key in request.declaredFields.keys) {
      if (forbidden.contains(key.toLowerCase())) return true;
    }
    return false;
  }

  bool _clinicalInGeneralMemoryAttempt(LioGatewayRequest request) {
    final action = request.requestedAction.toLowerCase();
    return action.contains('store_clinical_in_general_memory') ||
        action.contains('llm_as_source_of_truth');
  }

  LioGatewayDecision _deny(
    LioGatewayRequest request, {
    required String reasonCode,
    required String reasonAr,
    required DateTime timestamp,
  }) {
    return LioGatewayDecision(
      requestId: request.requestId,
      correlationId: request.correlationId,
      kind: LioGatewayDecisionKind.deny,
      reasonAr: reasonAr,
      reasonCode: reasonCode,
      timestamp: timestamp,
      riskLevel: request.riskLevel,
      purpose: request.purpose,
      dataScope: request.dataScope,
      mayProceedToMcp: false,
    );
  }
}
