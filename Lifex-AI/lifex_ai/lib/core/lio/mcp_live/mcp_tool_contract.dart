/// =============================================================
/// Lifex-AI — عقد أداة MCP الحيّة (Tool Registry)
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_tool_contract;

import '../lio_types.dart';

enum McpApprovalPolicy {
  none,
  onWrite,
  onHighRisk,
  always,
}

enum McpAuditPolicy {
  minimal,
  standard,
  full,
}

class McpToolContract {
  const McpToolContract({
    required this.toolId,
    required this.toolName,
    required this.description,
    required this.capabilities,
    required this.allowedOperations,
    required this.writeOperations,
    required this.allowedScopes,
    required this.requiredPermissions,
    required this.riskLevel,
    required this.approvalPolicy,
    required this.enabled,
    required this.timeout,
    required this.auditPolicy,
    this.mayTouchClinical = false,
    this.mayMutateMain = false,
    this.maySpendMoney = false,
    this.mayControlDevice = false,
  });

  final String toolId;
  final String toolName;
  final String description;
  final List<String> capabilities;
  final List<String> allowedOperations;
  final List<String> writeOperations;
  final List<String> allowedScopes;
  final List<String> requiredPermissions;
  final LioRiskLevel riskLevel;
  final McpApprovalPolicy approvalPolicy;
  final bool enabled;
  final Duration timeout;
  final McpAuditPolicy auditPolicy;
  final bool mayTouchClinical;
  final bool mayMutateMain;
  final bool maySpendMoney;
  final bool mayControlDevice;

  bool isWrite(String operation) => writeOperations.contains(operation);

  bool allowsOperation(String operation) =>
      allowedOperations.contains(operation) || allowedOperations.contains('*');

  bool allowsScope(String scope) =>
      allowedScopes.contains(scope) || allowedScopes.contains('*');
}

/// سجل عقود الأدوات — يوسّع ولا يستبدل LifexMcpGateway الوصفي.
class McpLiveToolRegistry {
  McpLiveToolRegistry({Map<String, McpToolContract>? seed})
      : _tools = Map.of(seed ?? defaultContracts);

  final Map<String, McpToolContract> _tools;

  static final Map<String, McpToolContract> defaultContracts = {
    'mcp.github': McpToolContract(
      toolId: 'mcp.github',
      toolName: 'GitHub',
      description: 'قراءة مستودع/CI — الكتابة بموافقة فقط.',
      capabilities: const ['read_repo', 'read_ci', 'read_artifacts'],
      allowedOperations: const [
        'read_repository',
        'read_branches',
        'read_commits',
        'read_files',
        'read_workflow_status',
        'read_workflow_jobs',
        'read_artifacts',
        'ping',
      ],
      writeOperations: const [
        'create_branch',
        'commit',
        'push',
        'pull_request',
        'merge',
        'workflow_mutation',
      ],
      allowedScopes: const ['repository_read', 'ci_read', 'repository_write'],
      requiredPermissions: const ['mcp.github'],
      riskLevel: LioRiskLevel.high,
      approvalPolicy: McpApprovalPolicy.onWrite,
      enabled: true,
      timeout: const Duration(seconds: 45),
      auditPolicy: McpAuditPolicy.full,
      mayMutateMain: false,
    ),
    'mcp.cursor': McpToolContract(
      toolId: 'mcp.cursor',
      toolName: 'Cursor Agent',
      description: 'محوّل وكيل برمجي — بلا تنفيذ حر وبلا تعديل main.',
      capabilities: const ['code_assist', 'local_edit_proposal'],
      allowedOperations: const ['ping', 'propose_edit', 'run_tests_request'],
      writeOperations: const ['apply_edit', 'run_shell', 'force_push'],
      allowedScopes: const ['source_code', 'tests'],
      requiredPermissions: const ['mcp.cursor'],
      riskLevel: LioRiskLevel.high,
      approvalPolicy: McpApprovalPolicy.onHighRisk,
      enabled: true,
      timeout: const Duration(seconds: 60),
      auditPolicy: McpAuditPolicy.full,
      mayMutateMain: false,
    ),
    'mcp.browser': McpToolContract(
      toolId: 'mcp.browser',
      toolName: 'Browser',
      description: 'بحث/قراءة/اقتباس — بلا شراء أو دفع.',
      capabilities: const ['search', 'read', 'extract', 'provenance'],
      allowedOperations: const ['search', 'read', 'extract', 'ping'],
      writeOperations: const ['purchase', 'pay', 'send', 'account_modify'],
      allowedScopes: const ['public_web'],
      requiredPermissions: const ['mcp.browser'],
      riskLevel: LioRiskLevel.medium,
      approvalPolicy: McpApprovalPolicy.onWrite,
      enabled: true,
      timeout: const Duration(seconds: 30),
      auditPolicy: McpAuditPolicy.standard,
    ),
    'mcp.local_files': McpToolContract(
      toolId: 'mcp.local_files',
      toolName: 'Files',
      description: 'ملفات مصرّح بها فقط — بلا clinical/secrets.',
      capabilities: const ['ping', 'stat', 'read_meta'],
      allowedOperations: const ['ping', 'stat', 'read_meta'],
      writeOperations: const ['write', 'delete'],
      allowedScopes: const ['project_files', 'source_code'],
      requiredPermissions: const ['mcp.local_files'],
      riskLevel: LioRiskLevel.low,
      approvalPolicy: McpApprovalPolicy.onWrite,
      enabled: true,
      timeout: const Duration(seconds: 15),
      auditPolicy: McpAuditPolicy.standard,
      mayTouchClinical: false,
    ),
    'mcp.devices': McpToolContract(
      toolId: 'mcp.devices',
      toolName: 'Devices',
      description: 'حالة أجهزة — لا تحكم طبي في هذه المرحلة.',
      capabilities: const ['read_status'],
      allowedOperations: const ['ping', 'read_status'],
      writeOperations: const ['control', 'prescribe_via_device'],
      allowedScopes: const ['device_telemetry'],
      requiredPermissions: const ['mcp.devices'],
      riskLevel: LioRiskLevel.critical,
      approvalPolicy: McpApprovalPolicy.always,
      enabled: true,
      timeout: const Duration(seconds: 20),
      auditPolicy: McpAuditPolicy.full,
      mayControlDevice: true,
    ),
  };

  McpToolContract? tool(String id) => _tools[id];

  List<McpToolContract> get all => List.unmodifiable(_tools.values);

  bool register(McpToolContract contract) {
    if (_tools.containsKey(contract.toolId)) return false;
    _tools[contract.toolId] = contract;
    return true;
  }
}
