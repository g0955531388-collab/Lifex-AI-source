/// =============================================================
/// Lifex-AI — Lifex Intelligence Orchestrator (LIO)
/// يقرّر: ماذا؟ أي مصدر؟ أي نموذج؟ أي وكيل؟ هل موثوق؟ هل يُنفَّذ؟
/// =============================================================
library lifex_ai.core.lio.lio_orchestrator;

import 'agent_control_registry.dart';
import 'claim_verifier.dart';
import 'lio_types.dart';
import 'mcp_gateway.dart';
import 'source_reliability.dart';
import 'unified_memory.dart';

class LioMissionRequest {
  const LioMissionRequest({
    required this.id,
    required this.goalAr,
    this.preferredProvider = LioProviderKind.chatgptPlanning,
    this.risk = LioRiskLevel.medium,
    this.needsCode = false,
    this.needsResearch = false,
    this.needsBuild = false,
    this.touchesClinical = false,
    this.spendsMoney = false,
  });

  final String id;
  final String goalAr;
  final LioProviderKind preferredProvider;
  final LioRiskLevel risk;
  final bool needsCode;
  final bool needsResearch;
  final bool needsBuild;
  final bool touchesClinical;
  final bool spendsMoney;
}

class LioMissionPlan {
  const LioMissionPlan({
    required this.missionId,
    required this.status,
    required this.stepsAr,
    required this.assignedRoles,
    required this.providerSequence,
    required this.blockedReasonAr,
    required this.requiresHumanApproval,
  });

  final String missionId;
  final LioMissionStatus status;
  final List<String> stepsAr;
  final List<LioAgentRole> assignedRoles;
  final List<LioProviderKind> providerSequence;
  final String? blockedReasonAr;
  final bool requiresHumanApproval;
}

/// عقل القيادة — لا ينفّذ كوداً بنفسه؛ يخطّط ويقيّد ويحوّل للوكلاء.
class LifexIntelligenceOrchestrator {
  LifexIntelligenceOrchestrator({
    LifexMcpGateway? mcp,
    LifexUnifiedMemory? memory,
    LifexAgentControlRegistry? agents,
    LifexClaimVerifier? verifier,
    LifexSourceReliabilityEngine? reliability,
  })  : mcp = mcp ?? LifexMcpGateway(),
        memory = memory ?? LifexUnifiedMemory(),
        agents = agents ?? LifexAgentControlRegistry(),
        verifier = verifier ?? const LifexClaimVerifier(),
        reliability = reliability ?? const LifexSourceReliabilityEngine();

  final LifexMcpGateway mcp;
  final LifexUnifiedMemory memory;
  final LifexAgentControlRegistry agents;
  final LifexClaimVerifier verifier;
  final LifexSourceReliabilityEngine reliability;

  /// خطّة مهمة — بدون تنفيذ جانبي.
  LioMissionPlan plan(LioMissionRequest request) {
    if (request.touchesClinical) {
      return LioMissionPlan(
        missionId: request.id,
        status: LioMissionStatus.blocked,
        stepsAr: const [],
        assignedRoles: const [],
        providerSequence: const [],
        blockedReasonAr:
            'البيانات السريرية لا تمر عبر ذاكرة AI العامة. '
            'المسار: AI Gateway → Identity → Authorization → Consent → Purpose → Scope → Repository.',
        requiresHumanApproval: true,
      );
    }
    if (request.spendsMoney) {
      return LioMissionPlan(
        missionId: request.id,
        status: LioMissionStatus.awaitingApproval,
        stepsAr: const [
          'مراجعة مالية بشرية',
          'Fee preview',
          'تأكيد مزوّد مرخّص',
        ],
        assignedRoles: const [LioAgentRole.security],
        providerSequence: const [LioProviderKind.human],
        blockedReasonAr: null,
        requiresHumanApproval: true,
      );
    }

    final roles = <LioAgentRole>[LioAgentRole.planner];
    final providers = <LioProviderKind>[request.preferredProvider];
    final steps = <String>['تحليل الهدف', 'اختيار مصادر'];

    if (request.needsResearch) {
      roles.add(LioAgentRole.research);
      roles.add(LioAgentRole.browser);
      providers.add(LioProviderKind.geminiResearch);
      steps.addAll(const [
        'بحث',
        'فتح مصادر',
        'مقارنة',
        'اقتباس + provenance',
      ]);
    }
    if (request.needsCode) {
      roles.add(LioAgentRole.code);
      providers.add(LioProviderKind.cursorCode);
      providers.add(LioProviderKind.githubCopilot);
      steps.addAll(const ['تعديل كود', 'اختبار', 'فتح PR']);
    }
    if (request.needsBuild) {
      roles.add(LioAgentRole.testing);
      roles.add(LioAgentRole.criticVerifier);
      steps.addAll(const [
        'analyze',
        'test',
        'build',
        'SHA-256',
        'تحقق Verifier',
      ]);
    }
    roles.add(LioAgentRole.criticVerifier);

    final needsHuman = request.risk == LioRiskLevel.high ||
        request.risk == LioRiskLevel.critical ||
        request.needsCode ||
        request.needsBuild;

    return LioMissionPlan(
      missionId: request.id,
      status: needsHuman
          ? LioMissionStatus.awaitingApproval
          : LioMissionStatus.planning,
      stepsAr: steps,
      assignedRoles: roles,
      providerSequence: providers,
      blockedReasonAr: null,
      requiresHumanApproval: needsHuman,
    );
  }

  /// مفتاح دور متوافق مع MCP / السجل.
  static String roleKey(LioAgentRole role) {
    switch (role) {
      case LioAgentRole.medicalKnowledge:
        return 'medical_knowledge';
      case LioAgentRole.criticVerifier:
        return 'critic_verifier';
      default:
        return role.name;
    }
  }

  /// بوابة أداة MCP عبر سياسة الوكيل.
  String? authorizeTool({
    required LioAgentRole role,
    required String toolId,
    required bool humanApproved,
  }) {
    final profile = agents.profile(role);
    if (profile == null) return 'وكيل غير مسجّل.';
    if (!profile.allowedTools.contains(toolId)) {
      return 'الأداة $toolId خارج أدوات ${profile.identity}.';
    }
    return mcp.denyReason(
      toolId: toolId,
      role: roleKey(role),
      humanApproved: humanApproved,
      clinicalRequested: false,
      moneyRequested: false,
    );
  }

  /// التحقق المستقل من ادّعاء وكيل.
  LioVerificationReport verifyClaim({
    required LioClaim claim,
    required List<LioEvidence> evidence,
    Set<LioEvidenceKind> required = LifexClaimVerifier.requiredForCodeFix,
  }) {
    return verifier.verify(
      claim: claim,
      evidence: evidence,
      required: required,
    );
  }
}
