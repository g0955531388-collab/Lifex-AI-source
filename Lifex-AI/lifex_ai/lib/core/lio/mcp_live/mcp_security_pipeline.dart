/// =============================================================
/// Lifex-AI — مسار الأمان قبل MCP
/// Identity → Authentication → Authorization → Consent → Purpose → Scope → Policy
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_security_pipeline;

import '../lio_types.dart';
import 'mcp_errors.dart';
import 'mcp_policy_decision.dart';
import 'mcp_request_context.dart';
import 'mcp_tool_contract.dart';

class McpSecurityVerdict {
  const McpSecurityVerdict({
    required this.decision,
    this.errorCode,
    this.messageAr,
  });

  final McpPolicyDecision decision;
  final McpErrorCode? errorCode;
  final String? messageAr;

  bool get mayProceedToExecute => decision.mayExecute;

  static McpSecurityVerdict allow() =>
      const McpSecurityVerdict(decision: McpPolicyDecision.allow);

  static McpSecurityVerdict stop({
    required McpPolicyDecision decision,
    required McpErrorCode code,
    required String messageAr,
  }) {
    return McpSecurityVerdict(
      decision: decision,
      errorCode: code,
      messageAr: messageAr,
    );
  }
}

class McpSecurityPipeline {
  const McpSecurityPipeline();

  /// لا تنفيذ هنا — قرار فقط.
  McpSecurityVerdict evaluate({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) {
    if (request.requestId.trim().isEmpty ||
        request.toolId.trim().isEmpty ||
        request.requestedAction.trim().isEmpty) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.invalidRequest,
        messageAr: 'طلب MCP غير صالح (حقول إلزامية ناقصة).',
      );
    }

    if (!request.hasIdentity) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.unauthenticated,
        messageAr: 'هوية ناقصة: actorId/agentId مطلوبان.',
      );
    }

    if (!request.authenticated) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.unauthenticated,
        messageAr: 'السياق غير مصادق (authenticated=false).',
      );
    }

    if (!request.authorized) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.unauthorized,
        messageAr: 'غير مصرّح (authorized=false).',
      );
    }

    if (!contract.enabled) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.blocked,
        code: McpErrorCode.forbidden,
        messageAr: 'الأداة معطّلة: ${contract.toolId}',
      );
    }

    // Consent: عمليات تمس بيانات حسّاسة أو scope clinical
    final needsConsent = request.scope.toLowerCase().contains('clinical') ||
        request.purpose.toLowerCase().contains('clinical') ||
        contract.mayTouchClinical;
    if (needsConsent && !request.consentGranted) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.requireConsent,
        code: McpErrorCode.consentRequired,
        messageAr: 'الموافقة (Consent) مطلوبة لهذا الغرض/النطاق.',
      );
    }

    if (request.purpose.trim().isEmpty) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.invalidRequest,
        messageAr: 'Purpose مطلوب.',
      );
    }

    final op = request.requestedAction;

    if (op.contains('sql') ||
        op.contains('clinical_repository') ||
        request.resource.toLowerCase().contains('sql://') ||
        request.resource.toLowerCase().contains('clinical://')) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.blocked,
        code: McpErrorCode.forbidden,
        messageAr: 'مسار AI/Agent → SQL/Clinical Repository محظور عبر MCP.',
      );
    }

    if (!contract.allowsScope(request.scope)) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.scopeDenied,
        messageAr: 'النطاق ${request.scope} غير مسموح لأداة ${contract.toolId}.',
      );
    }

    final isWrite = contract.isWrite(op);
    if (!contract.allowsOperation(op) && !isWrite) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.deny,
        code: McpErrorCode.policyDenied,
        messageAr: 'العملية $op غير مسموحة على ${contract.toolId}.',
      );
    }

    // Write ops not in allowedOperations still need explicit allow via write list + approval
    if (isWrite) {
      if (contract.mayMutateMain || op == 'merge' || op == 'force_push') {
        return McpSecurityVerdict.stop(
          decision: McpPolicyDecision.blocked,
          code: McpErrorCode.forbidden,
          messageAr: 'تعديل/دمج main أو force_push محظور عبر MCP.',
        );
      }
      if (!request.humanApproved) {
        return McpSecurityVerdict.stop(
          decision: McpPolicyDecision.requireConfirmation,
          code: McpErrorCode.approvalRequired,
          messageAr: 'عملية كتابة — توقّف حتى موافقة بشرية صريحة.',
        );
      }
    }

    final highRisk = request.riskLevel == LioRiskLevel.high ||
        request.riskLevel == LioRiskLevel.critical ||
        contract.riskLevel == LioRiskLevel.high ||
        contract.riskLevel == LioRiskLevel.critical;

    if (highRisk &&
        (contract.approvalPolicy == McpApprovalPolicy.onHighRisk ||
            contract.approvalPolicy == McpApprovalPolicy.always ||
            (contract.approvalPolicy == McpApprovalPolicy.onWrite &&
                isWrite))) {
      if (!request.humanApproved) {
        return McpSecurityVerdict.stop(
          decision: McpPolicyDecision.requireConfirmation,
          code: McpErrorCode.approvalRequired,
          messageAr: 'HIGH RISK — لا تنفيذ قبل Human Approval.',
        );
      }
    }

    if (contract.approvalPolicy == McpApprovalPolicy.always &&
        !request.humanApproved) {
      return McpSecurityVerdict.stop(
        decision: McpPolicyDecision.requireConfirmation,
        code: McpErrorCode.approvalRequired,
        messageAr: 'سياسة الأداة تتطلب موافقة دائماً.',
      );
    }

    return McpSecurityVerdict.allow();
  }
}
