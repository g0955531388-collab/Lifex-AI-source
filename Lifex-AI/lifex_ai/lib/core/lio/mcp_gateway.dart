/// =============================================================
/// Lifex-AI — بوابة MCP (عقود)
/// ربط الأدوات/الموارد/المطالبات تحت LIO — بلا تنفيذ شبكة في الموجة 1.
/// =============================================================
library lifex_ai.core.lio.mcp_gateway;

/// وصف أداة MCP معرّضة لـ LIO.
class LioMcpToolDescriptor {
  const LioMcpToolDescriptor({
    required this.id,
    required this.name,
    required this.descriptionAr,
    required this.allowedRoles,
    this.requiresHumanApproval = false,
    this.mayTouchClinicalData = false,
    this.mayModifyRepository = false,
    this.maySpendMoney = false,
    this.mayControlDevice = false,
  });

  final String id;
  final String name;
  final String descriptionAr;
  final List<String> allowedRoles;
  final bool requiresHumanApproval;
  final bool mayTouchClinicalData;
  final bool mayModifyRepository;
  final bool maySpendMoney;
  final bool mayControlDevice;
}

/// بوابة تسجيل أدوات MCP — لا تنفيذ مباشر هنا.
class LifexMcpGateway {
  LifexMcpGateway({List<LioMcpToolDescriptor>? seed})
      : _tools = {
          for (final t in seed ?? _defaultTools) t.id: t,
        };

  final Map<String, LioMcpToolDescriptor> _tools;

  static const _defaultTools = <LioMcpToolDescriptor>[
    LioMcpToolDescriptor(
      id: 'mcp.github',
      name: 'GitHub',
      descriptionAr: 'مستودع/PR/Actions/Releases — بلا دمج تلقائي.',
      allowedRoles: ['github', 'code', 'testing', 'critic_verifier'],
      mayModifyRepository: true,
      requiresHumanApproval: true,
    ),
    LioMcpToolDescriptor(
      id: 'mcp.cursor',
      name: 'Cursor Agent',
      descriptionAr: 'تنفيذ برمجي داخل المستودع المحلي.',
      allowedRoles: ['code', 'testing'],
      mayModifyRepository: true,
      requiresHumanApproval: true,
    ),
    LioMcpToolDescriptor(
      id: 'mcp.browser',
      name: 'Browser',
      descriptionAr: 'بحث وقراءة مصادر — اقتباس + provenance إلزامي.',
      allowedRoles: ['browser', 'research'],
    ),
    LioMcpToolDescriptor(
      id: 'mcp.local_files',
      name: 'Local Files',
      descriptionAr: 'ملفات مشروع وتطوير — بلا أسرار وبلا سجلات سريرية.',
      allowedRoles: ['code', 'research', 'planner'],
    ),
    LioMcpToolDescriptor(
      id: 'mcp.devices',
      name: 'Devices',
      descriptionAr: 'حالة أجهزة — DISCOVERED≠CONNECTED≠AUTHORIZED≠CONTROLABLE.',
      allowedRoles: ['device'],
      mayControlDevice: true,
      requiresHumanApproval: true,
    ),
  ];

  List<LioMcpToolDescriptor> get tools =>
      List.unmodifiable(_tools.values);

  LioMcpToolDescriptor? tool(String id) => _tools[id];

  bool register(LioMcpToolDescriptor tool) {
    if (_tools.containsKey(tool.id)) return false;
    _tools[tool.id] = tool;
    return true;
  }

  /// هل الدور مسموح باستدعاء الأداة؟
  bool roleMayInvoke(String toolId, String role) {
    final t = _tools[toolId];
    if (t == null) return false;
    return t.allowedRoles.contains(role);
  }

  /// حواجز أمان قبل أي استدعاء.
  String? denyReason({
    required String toolId,
    required String role,
    required bool humanApproved,
    required bool clinicalRequested,
    required bool moneyRequested,
  }) {
    final t = _tools[toolId];
    if (t == null) return 'أداة MCP غير مسجّلة: $toolId';
    if (!t.allowedRoles.contains(role)) {
      return 'الدور $role غير مسموح له بأداة ${t.name}.';
    }
    if (t.requiresHumanApproval && !humanApproved) {
      return 'الأداة ${t.name} تتطلب موافقة بشرية.';
    }
    if (clinicalRequested && !t.mayTouchClinicalData) {
      return 'الأداة ${t.name} ممنوعة من البيانات السريرية.';
    }
    if (moneyRequested && !t.maySpendMoney) {
      return 'الأداة ${t.name} ممنوعة من صرف أموال.';
    }
    return null;
  }
}
