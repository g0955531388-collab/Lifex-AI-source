/// =============================================================
/// Lifex-AI — عقود بوابة LIO الإنتاجية
/// Authentication ≠ Authorization ≠ Consent ≠ Device Trust ≠ Access
/// =============================================================
library lifex_ai.core.orchestrator.lio_gateway_contracts;

/// قرارات LIO الإنتاجية المسموحة.
enum LioGatewayDecisionKind {
  allow,
  deny,
  requireConsent,
  requireStepUp,
  requireConfirmation,
  requireReview,
  emergencyLimited,
}

extension LioGatewayDecisionKindX on LioGatewayDecisionKind {
  String get wireName {
    switch (this) {
      case LioGatewayDecisionKind.allow:
        return 'ALLOW';
      case LioGatewayDecisionKind.deny:
        return 'DENY';
      case LioGatewayDecisionKind.requireConsent:
        return 'REQUIRE_CONSENT';
      case LioGatewayDecisionKind.requireStepUp:
        return 'REQUIRE_STEP_UP';
      case LioGatewayDecisionKind.requireConfirmation:
        return 'REQUIRE_CONFIRMATION';
      case LioGatewayDecisionKind.requireReview:
        return 'REQUIRE_REVIEW';
      case LioGatewayDecisionKind.emergencyLimited:
        return 'EMERGENCY_LIMITED';
    }
  }

  /// ALLOW و EMERGENCY_LIMITED فقط قد يمضيان للتنفيذ المحدود عبر MCP.
  bool get mayProceedToMcp =>
      this == LioGatewayDecisionKind.allow ||
      this == LioGatewayDecisionKind.emergencyLimited;
}

/// تصنيف حساسية البيانات المطلوبة — ليس تشخيصاً طبياً.
enum LioDataSensitivity {
  public,
  operational,
  personal,
  clinical,
  restricted,
}

/// مستوى خطورة الإجراء المطلوب.
enum LioActionRisk {
  low,
  medium,
  high,
  critical,
}

/// سياق موافقة — منفصل عن المصادقة والتفويض.
class LioConsentContext {
  const LioConsentContext({
    required this.consentGranted,
    this.consentId,
    this.purposeAligned = false,
  });

  final bool consentGranted;
  final String? consentId;

  /// هل غرض الموافقة يطابق purpose الطلب؟
  final bool purposeAligned;
}

/// طلب بوابة LIO — عقد واضح قبل أي مسار MCP/Agent.
class LioGatewayRequest {
  const LioGatewayRequest({
    required this.requestId,
    required this.correlationId,
    required this.identityAccountId,
    required this.purpose,
    required this.requestedAction,
    required this.dataScope,
    required this.sensitivity,
    required this.consent,
    required this.riskLevel,
    required this.timestamp,
    this.authenticated = false,
    this.authorized = false,
    this.deviceTrusted = false,
    this.approvalRequirement = false,
    this.stepUpSatisfied = false,
    this.humanConfirmed = false,
    this.reviewApproved = false,
    this.emergencyLimitedMode = false,
    this.declaredFields = const {},
    this.minimumNecessarySatisfied = true,
  });

  final String requestId;
  final String correlationId;

  /// هوية/حساب الفاعل — ليس Device Trust.
  final String identityAccountId;

  final String purpose;
  final String requestedAction;

  /// نطاق البيانات المطلوب (حد أدنى معلن).
  final String dataScope;

  final LioDataSensitivity sensitivity;
  final LioConsentContext consent;
  final LioActionRisk riskLevel;
  final DateTime timestamp;

  /// Authentication — إثبات الهوية.
  final bool authenticated;

  /// Authorization — صلاحية الدور/الإذن (≠ Consent).
  final bool authorized;

  /// Device Trust — منفصل عن Access.
  final bool deviceTrusted;

  /// هل السياسة تتطلب موافقة/تأكيداً مسبقاً؟
  final bool approvalRequirement;

  final bool stepUpSatisfied;
  final bool humanConfirmed;
  final bool reviewApproved;

  /// وضع طوارئ محدود — لا يتجاوز السياسة مطلقاً.
  final bool emergencyLimitedMode;

  /// حقول معلنة للطلب — لفحص minimization (بلا بيانات سريرية خام).
  final Map<String, Object?> declaredFields;

  /// هل التزم الطلب بمبدأ الحد الأدنى الضروري؟
  final bool minimumNecessarySatisfied;

  bool get hasValidIdentity => identityAccountId.trim().isNotEmpty;

  bool get hasValidIds =>
      requestId.trim().isNotEmpty && correlationId.trim().isNotEmpty;

  bool get touchesClinicalScope =>
      sensitivity == LioDataSensitivity.clinical ||
      sensitivity == LioDataSensitivity.restricted ||
      dataScope.toLowerCase().contains('clinical') ||
      dataScope.toLowerCase().contains('phr') ||
      purpose.toLowerCase().contains('clinical');

  bool get looksLikeDbBypass {
    final a = requestedAction.toLowerCase();
    final s = dataScope.toLowerCase();
    return a.contains('sql') ||
        a.contains('direct_db') ||
        a.contains('repository_raw') ||
        s.contains('sql://') ||
        s.contains('clinical://') ||
        a.contains('medical_driver');
  }
}

/// قرار LIO مع سبب قابل للتدقيق.
class LioGatewayDecision {
  const LioGatewayDecision({
    required this.requestId,
    required this.correlationId,
    required this.kind,
    required this.reasonAr,
    required this.reasonCode,
    required this.timestamp,
    required this.riskLevel,
    required this.purpose,
    required this.dataScope,
    this.mayProceedToMcp = false,
  });

  final String requestId;
  final String correlationId;
  final LioGatewayDecisionKind kind;
  final String reasonAr;
  final String reasonCode;
  final DateTime timestamp;
  final LioActionRisk riskLevel;
  final String purpose;
  final String dataScope;
  final bool mayProceedToMcp;

  String get wireDecision => kind.wireName;
}

/// حدث تدقيق — بلا أسرار وبلا بيانات صحية غير لازمة.
class LioAuditEvent {
  const LioAuditEvent({
    required this.requestId,
    required this.correlationId,
    required this.actor,
    required this.action,
    required this.decision,
    required this.purpose,
    required this.scope,
    required this.risk,
    required this.timestamp,
    required this.outcome,
    required this.reasonCode,
  });

  final String requestId;
  final String correlationId;
  final String actor;
  final String action;
  final String decision;
  final String purpose;
  final String scope;
  final String risk;
  final DateTime timestamp;

  /// نتيجة مختصرة: ALLOWED_TO_MCP | STOPPED | EMERGENCY_LIMITED_PATH
  final String outcome;
  final String reasonCode;

  Map<String, Object?> toSafeMap() => {
        'requestId': requestId,
        'correlationId': correlationId,
        'actor': actor,
        'action': action,
        'decision': decision,
        'purpose': purpose,
        'scope': scope,
        'risk': risk,
        'timestamp': timestamp.toIso8601String(),
        'outcome': outcome,
        'reasonCode': reasonCode,
      };
}

/// سجل تدقيق في الذاكرة — لا يخزّن PHI.
class LioAuditLog {
  final List<LioAuditEvent> _events = [];

  List<LioAuditEvent> get events => List.unmodifiable(_events);

  void record(LioAuditEvent event) => _events.add(event);

  void clear() => _events.clear();
}
