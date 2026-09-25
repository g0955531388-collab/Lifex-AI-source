/// =============================================================
/// Lifex-AI — سجل تحكم الوكلاء (Agent Control Layer)
/// OWASP-aligned: هوية، صلاحيات، ميزانية، تدقيق — لا صندوق أسود.
/// =============================================================
library lifex_ai.core.lio.agent_control_registry;

import 'lio_types.dart';

class LioAgentCapability {
  const LioAgentCapability({
    required this.id,
    required this.descriptionAr,
  });

  final String id;
  final String descriptionAr;
}

class LioAgentProfile {
  const LioAgentProfile({
    required this.identity,
    required this.role,
    required this.capabilities,
    required this.allowedTools,
    required this.allowedSources,
    required this.allowedActions,
    required this.forbiddenActions,
    required this.dataScopes,
    required this.riskCeiling,
    required this.budgetTokens,
    required this.timeLimitSeconds,
    required this.requiresHumanApproval,
    required this.auditRequired,
  });

  final String identity;
  final LioAgentRole role;
  final List<LioAgentCapability> capabilities;
  final List<String> allowedTools;
  final List<String> allowedSources;
  final List<String> allowedActions;
  final List<String> forbiddenActions;
  final List<String> dataScopes;
  final LioRiskLevel riskCeiling;
  final int budgetTokens;
  final int timeLimitSeconds;
  final bool requiresHumanApproval;
  final bool auditRequired;

  bool mayPerform(String action) {
    if (forbiddenActions.contains(action)) return false;
    return allowedActions.contains(action) || allowedActions.contains('*');
  }
}

class LifexAgentControlRegistry {
  LifexAgentControlRegistry({Map<LioAgentRole, LioAgentProfile>? seed})
      : _profiles = Map.of(seed ?? _defaults);

  final Map<LioAgentRole, LioAgentProfile> _profiles;

  static final Map<LioAgentRole, LioAgentProfile> _defaults = {
    LioAgentRole.research: LioAgentProfile(
      identity: 'agent.research',
      role: LioAgentRole.research,
      capabilities: const [
        LioAgentCapability(id: 'search', descriptionAr: 'بحث'),
        LioAgentCapability(id: 'read', descriptionAr: 'قراءة'),
        LioAgentCapability(id: 'compare', descriptionAr: 'مقارنة'),
        LioAgentCapability(id: 'report', descriptionAr: 'تقرير'),
      ],
      allowedTools: const ['mcp.browser', 'mcp.local_files'],
      allowedSources: const ['web', 'docs', 'standards'],
      allowedActions: const ['search', 'read', 'compare', 'report'],
      forbiddenActions: const [
        'modify_patient_db',
        'prescribe',
        'spend_money',
        'control_medical_device',
        'merge_main',
      ],
      dataScopes: const ['public_knowledge', 'project_docs'],
      riskCeiling: LioRiskLevel.medium,
      budgetTokens: 80000,
      timeLimitSeconds: 900,
      requiresHumanApproval: false,
      auditRequired: true,
    ),
    LioAgentRole.code: LioAgentProfile(
      identity: 'agent.code',
      role: LioAgentRole.code,
      capabilities: const [
        LioAgentCapability(id: 'edit', descriptionAr: 'تعديل كود'),
        LioAgentCapability(id: 'test', descriptionAr: 'اختبار'),
      ],
      allowedTools: const ['mcp.cursor', 'mcp.github', 'mcp.local_files'],
      allowedSources: const ['repository'],
      allowedActions: const ['edit', 'test', 'open_pr'],
      forbiddenActions: const [
        'modify_patient_db',
        'prescribe',
        'spend_money',
        'force_push_main',
        'merge_main',
      ],
      dataScopes: const ['source_code', 'tests'],
      riskCeiling: LioRiskLevel.high,
      budgetTokens: 200000,
      timeLimitSeconds: 3600,
      requiresHumanApproval: true,
      auditRequired: true,
    ),
    LioAgentRole.criticVerifier: LioAgentProfile(
      identity: 'agent.critic_verifier',
      role: LioAgentRole.criticVerifier,
      capabilities: const [
        LioAgentCapability(id: 'verify', descriptionAr: 'تحقق مستقل'),
      ],
      allowedTools: const ['mcp.github', 'mcp.local_files'],
      allowedSources: const ['ci', 'artifacts', 'tests'],
      allowedActions: const ['analyze', 'test', 'inspect_artifact', 'verdict'],
      forbiddenActions: const [
        'modify_patient_db',
        'prescribe',
        'spend_money',
        'self_approve_own_claim',
      ],
      dataScopes: const ['ci_logs', 'artifacts', 'code'],
      riskCeiling: LioRiskLevel.high,
      budgetTokens: 50000,
      timeLimitSeconds: 1800,
      requiresHumanApproval: false,
      auditRequired: true,
    ),
    LioAgentRole.device: LioAgentProfile(
      identity: 'agent.device',
      role: LioAgentRole.device,
      capabilities: const [
        LioAgentCapability(id: 'status', descriptionAr: 'حالة جهاز'),
      ],
      allowedTools: const ['mcp.devices'],
      allowedSources: const ['device_hub'],
      allowedActions: const ['read_status'],
      forbiddenActions: const [
        'control_without_auth',
        'prescribe',
        'spend_money',
        'modify_patient_db',
      ],
      dataScopes: const ['device_telemetry'],
      riskCeiling: LioRiskLevel.critical,
      budgetTokens: 20000,
      timeLimitSeconds: 300,
      requiresHumanApproval: true,
      auditRequired: true,
    ),
  };

  LioAgentProfile? profile(LioAgentRole role) => _profiles[role];

  List<LioAgentProfile> get all => List.unmodifiable(_profiles.values);

  String? denyAction(LioAgentRole role, String action) {
    final p = _profiles[role];
    if (p == null) return 'وكيل غير مسجّل: $role';
    if (p.forbiddenActions.contains(action)) {
      return 'الإجراء $action محظور على ${p.identity}.';
    }
    if (!p.mayPerform(action)) {
      return 'الإجراء $action خارج صلاحيات ${p.identity}.';
    }
    return null;
  }
}
