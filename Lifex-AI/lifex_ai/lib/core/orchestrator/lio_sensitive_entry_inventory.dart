/// =============================================================
/// Lifex-AI — جرد نقاط الدخول الحساسة للإنتاج (Production)
/// مصدر قابل للاختبار للحراس — ليس وثيقة فقط.
/// =============================================================
library lifex_ai.core.orchestrator.lio_sensitive_entry_inventory;

/// سجل نقطة دخول حساسة معروفة.
class LioSensitiveEntryRecord {
  const LioSensitiveEntryRecord({
    required this.path,
    required this.classOrFunction,
    required this.callerSurface,
    required this.operation,
    required this.mustPassLio,
    required this.legalPathNote,
  });

  final String path;
  final String classOrFunction;
  final String callerSurface;
  final String operation;
  final bool mustPassLio;
  final String legalPathNote;
}

/// الجرد المعتمد لمسارات AI/Agent/Tool/MCP الحساسة في الإنتاج.
class LioSensitiveEntryInventory {
  const LioSensitiveEntryInventory();

  static const inventoryId = 'LioSensitiveEntryInventory';

  /// المسار القانوني الوحيد.
  static const legalFlow = [
    'Presentation/UI',
    'LifexAppContext',
    'LioSensitiveActionEntry',
    'ProductionLioGateway',
    'Identity',
    'Authentication',
    'Authorization',
    'Consent',
    'Purpose',
    'DataScope/Minimization',
    'SecurityPolicy',
    'Risk/ActionClassification',
    'MCP/Agent/Tool',
    'Verification',
    'Audit',
  ];

  /// نقطة دخول Application الوحيدة المسموحة للعمليات الحساسة.
  static const soleApplicationEntry = 'LioSensitiveActionEntry';

  List<LioSensitiveEntryRecord> get productionEntries => const [
        LioSensitiveEntryRecord(
          path: 'lib/screens/ai_agent_screen.dart',
          classOrFunction: 'AiAgentScreen._submitAgentTask',
          callerSurface: 'UI',
          operation: 'agent_user_request',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.runAgentRequest',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/screens/ai_agent_screen.dart',
          classOrFunction: 'AiAgentScreen._submitChat',
          callerSurface: 'UI',
          operation: 'chat_ai_query',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.runAiChatQuery',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/screens/ai_hub_screen.dart',
          classOrFunction: 'AiHubScreen._showConnectDialog',
          callerSurface: 'UI',
          operation: 'ai_hub_connect_account',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.connectExternalAiAccount',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/screens/ai_hub_screen.dart',
          classOrFunction: 'AiHubScreen._disconnect',
          callerSurface: 'UI',
          operation: 'ai_hub_disconnect_account',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.disconnectExternalAiAccount',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/screens/ai_hub_screen.dart',
          classOrFunction: 'AiHubScreen._refreshConnected',
          callerSurface: 'UI',
          operation: 'ai_hub_list_accounts',
          mustPassLio: true,
          legalPathNote: 'via LioSensitiveActionEntry.listConnectedAiAccounts',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/core/orchestrator/lio_sensitive_action_entry.dart',
          classOrFunction: 'LioSensitiveActionEntry',
          callerSurface: 'Application',
          operation: 'authorizeThenRun / runAgentRequest / AI hub ops',
          mustPassLio: true,
          legalPathNote: 'sole Application gate; uses ProductionLioGateway',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/core/agent/agents/coordinator_agent.dart',
          classOrFunction: 'CoordinatorAgent.handleUserRequest',
          callerSurface: 'Agent-internal',
          operation: 'orchestrate tools',
          mustPassLio: true,
          legalPathNote: 'only after LIO Allow via SensitiveActionEntry',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/core/agent/tools/agent_tool_registry.dart',
          classOrFunction: 'AgentToolRegistry.executeTool',
          callerSurface: 'Agent-internal',
          operation: 'tool_execute',
          mustPassLio: true,
          legalPathNote: 'downstream of Coordinator after LIO',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/core/lio/mcp_live/mcp_live_gateway.dart',
          classOrFunction: 'LifexMcpLiveGateway.execute',
          callerSurface: 'MCP-boundary',
          operation: 'mcp_tool',
          mustPassLio: true,
          legalPathNote: 'not callable from UI; Fabric/Composition only',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/features/ai/ai_service_router.dart',
          classOrFunction: 'AiServiceRouter.query',
          callerSurface: 'AI-provider',
          operation: 'external_ai_query',
          mustPassLio: true,
          legalPathNote: 'UI must not call; only via SensitiveActionEntry',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/features/ai/unified_ai_hub_gateway.dart',
          classOrFunction: 'UnifiedAiHubGateway.connectAccount/disconnectAccount',
          callerSurface: 'AI-provider',
          operation: 'ai_credential_ops',
          mustPassLio: true,
          legalPathNote: 'UI must not call; only via SensitiveActionEntry',
        ),
        LioSensitiveEntryRecord(
          path: 'lib/main.dart',
          classOrFunction: 'MultiProvider (LioSensitiveActionEntry only)',
          callerSurface: 'Bootstrap',
          operation: 'wire_providers',
          mustPassLio: true,
          legalPathNote:
              'must not expose AgentCoreBundle/AiServiceRouter/UnifiedAiHubGateway to UI',
        ),
      ];

  /// مسارات UI ممنوعة من استدعاء هذه الرموز مباشرة.
  /// (بدون أقواس مُنشئ لتجنّب إيجابيات كاذبة في حراس البناء)
  static const uiForbiddenDirectCalls = [
    'handleUserRequest',
    'LifexMcpLiveGateway',
    'attachLiveMcpGateway',
    'KnowledgeSearchTool',
    'executeTool',
    'AgentCore.initialize',
    'ProductionLioGateway',
    'LioSensitiveActionEntry(',
    'AiServiceRouter(',
    'connectAccount',
  ];

  /// أنماط Provider ممنوعة في screens لـ Agent/MCP/Tool/AI execute.
  static const uiForbiddenProviderTypes = [
    'AgentCoreBundle',
    'LifexMcpLiveGateway',
    'AiServiceRouter',
    'UnifiedAiHubGateway',
    'AgentToolRegistry',
  ];

  /// أنماط Provider ممنوعة في main من التعريض لشجرة UI.
  static const mainForbiddenUiProviders = [
    'Provider<AgentCoreBundle>',
    'Provider<AiServiceRouter>',
    'Provider<UnifiedAiHubGateway>',
    'Provider<LifexMcpLiveGateway>',
    'Provider<AgentToolRegistry>',
  ];
}
