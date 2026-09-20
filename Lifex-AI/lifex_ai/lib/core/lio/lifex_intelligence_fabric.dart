/// =============================================================
/// Lifex-AI — Intelligence Fabric (تركيب موجة 1)
/// يربط LIO فوق AgentOrchestrator الحالي دون تكرار محركات.
/// =============================================================
library lifex_ai.core.lio.lifex_intelligence_fabric;

import '../agent/agent_orchestrator.dart';
import 'agent_control_registry.dart';
import 'claim_verifier.dart';
import 'lio_canon.dart';
import 'lio_orchestrator.dart';
import 'mcp_gateway.dart';
import 'source_reliability.dart';
import 'unified_memory.dart';

/// نسيج الذكاء: LIO + MCP + Memory + Provenance + Registry + Verifier.
class LifexIntelligenceFabric {
  LifexIntelligenceFabric({
    this.existingOrchestrator,
    LifexIntelligenceOrchestrator? lio,
    LifexLioCanon? canon,
  })  : canon = canon ?? const LifexLioCanon(),
        lio = lio ?? LifexIntelligenceOrchestrator();

  final LifexLioCanon canon;

  /// عقل القيادة الجديد.
  final LifexIntelligenceOrchestrator lio;

  /// منسّق المهام الحالي داخل التطبيق — يُعاد استخدامه، لا يُستبدل صامتاً.
  final AgentOrchestrator? existingOrchestrator;

  LifexMcpGateway get mcp => lio.mcp;
  LifexUnifiedMemory get memory => lio.memory;
  LifexAgentControlRegistry get agents => lio.agents;
  LifexClaimVerifier get verifier => lio.verifier;
  LifexSourceReliabilityEngine get reliability => lio.reliability;

  /// هل المسار يمنع AI→SQL؟
  bool get enforcesAiDataPath => !canon.aiMayTalkSqlDirectly;

  /// هل Clinical خارج سياق AI العام؟
  bool get isolatesClinicalMemory =>
      !canon.clinicalDataEntersGeneralAiMemory &&
      memory.clinicalNeverInGeneralPack;

  Map<String, Object?> bootstrapReport() => {
        ...canon.asReport(),
        'hasExistingAgentOrchestrator': existingOrchestrator != null,
        'mcpToolCount': mcp.tools.length,
        'agentProfileCount': agents.all.length,
        'enforcesAiDataPath': enforcesAiDataPath,
        'isolatesClinicalMemory': isolatesClinicalMemory,
      };
}
