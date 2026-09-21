/// =============================================================
/// Lifex-AI — نقطة دخول Application الإلزامية قبل Agent/Tool/MCP
/// UI → AppContext → LioSensitiveActionEntry → ProductionLioGateway
/// → (ALLOW/EMERGENCY_LIMITED) → Agent/Tool callback → Audit
///
/// ممنوع إنشاء Gateway ثانٍ. ممنوع UI→Agent أو UI→MCP مباشرة.
/// =============================================================
library lifex_ai.core.orchestrator.lio_sensitive_action_entry;

import '../agent/agent_confidence.dart';
import '../agent/agent_context.dart';
import '../agent/agent_core.dart';
import '../agent/agent_orchestrator.dart';
import '../agent/agent_result.dart';
import '../agent/agent_state.dart';
import 'lio_gateway.dart';
import 'lio_gateway_contracts.dart';

/// نتيجة عبور البوابة ثم التنفيذ (أو التوقف).
class LioSensitiveActionOutcome<T> {
  const LioSensitiveActionOutcome._({
    required this.decision,
    required this.executed,
    this.value,
  });

  factory LioSensitiveActionOutcome.blocked(LioGatewayDecision decision) {
    return LioSensitiveActionOutcome._(
      decision: decision,
      executed: false,
    );
  }

  factory LioSensitiveActionOutcome.completed({
    required LioGatewayDecision decision,
    required T value,
  }) {
    return LioSensitiveActionOutcome._(
      decision: decision,
      executed: true,
      value: value,
    );
  }

  final LioGatewayDecision decision;
  final bool executed;
  final T? value;

  bool get wasAllowedThroughLio => decision.mayProceedToMcp;
}

/// عقد Application: كل طلب حساس يمر عبر LIO قبل أي Agent/Tool/MCP.
class LioSensitiveActionEntry {
  const LioSensitiveActionEntry({
    required this.lioGateway,
    required this.agentCore,
  });

  static const String entryId = 'LioSensitiveActionEntry';

  /// نفس Gateway من Composition Root — لا نسخة ثانية.
  final ProductionLioGateway lioGateway;

  /// نفس AgentCore من Composition Root.
  final AgentCoreBundle agentCore;

  /// يقيّم عبر LIO ثم ينفّذ [run] فقط عند ALLOW / EMERGENCY_LIMITED.
  Future<LioSensitiveActionOutcome<T>> authorizeThenRun<T>({
    required LioGatewayRequest request,
    required Future<T> Function() run,
  }) async {
    final decision = lioGateway.evaluate(request);
    if (!lioGateway.mayHandOffToMcp(decision)) {
      return LioSensitiveActionOutcome.blocked(decision);
    }
    final value = await run();
    return LioSensitiveActionOutcome.completed(
      decision: decision,
      value: value,
    );
  }

  /// مسار وكيل حسّاس: LIO ثم CoordinatorAgent فقط.
  Future<LioSensitiveActionOutcome<AgentResult>> runAgentRequest({
    required LioGatewayRequest gatewayRequest,
    required AgentContext agentContext,
    required String sessionId,
    AgentTaskProgressListener? onProgress,
    Map<String, dynamic>? emergencyTriggerContext,
  }) {
    return authorizeThenRun<AgentResult>(
      request: gatewayRequest,
      run: () => agentCore.coordinator.handleUserRequest(
        context: agentContext,
        sessionId: sessionId,
        emergencyTriggerContext: emergencyTriggerContext,
        onProgress: onProgress,
      ),
    );
  }

  /// إلغاء مهمة سبق أن عُبرت LIO — لا يطلق أدوات جديدة.
  void cancelAgentTask(String taskId) {
    agentCore.coordinator.cancelTask(taskId);
  }

  /// نتيجة توقف عندما ترفض LIO التنفيذ.
  AgentResult blockedAgentResult({
    required String taskId,
    required LioGatewayDecision decision,
  }) {
    return AgentResult(
      taskId: taskId,
      finalState: AgentTaskState.blocked,
      summaryAr: 'توقف الطلب عند بوابة LIO: ${decision.wireDecision}',
      confidence: AgentConfidence.unknown,
      disclaimerAr: kAgentDefaultDisclaimerAr,
      errorMessageAr: decision.reasonAr,
    );
  }
}
