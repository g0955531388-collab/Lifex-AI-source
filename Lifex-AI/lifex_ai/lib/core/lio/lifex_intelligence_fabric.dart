/// =============================================================
/// Lifex-AI — Intelligence Fabric (تركيب موجة 1)
/// يربط LIO فوق AgentOrchestrator الحالي دون تكرار محركات.
/// =============================================================
library lifex_ai.core.lio.lifex_intelligence_fabric;

import '../agent/agent_orchestrator.dart';
import 'agent_control_registry.dart';
import 'claim_verifier.dart';
import 'knowledge_engine/ingestion/ingestion_pipeline.dart';
import 'knowledge_engine/knowledge_engine.dart';
import 'knowledge_engine/retrieval_adapters.dart';
import 'lio_canon.dart';
import 'lio_orchestrator.dart';
import 'mcp_gateway.dart';
import 'mcp_live/mcp_live_gateway.dart';
import 'source_reliability.dart';
import 'unified_memory.dart';

/// نسيج الذكاء: LIO + MCP + Memory + Provenance + Registry + Verifier (+ Knowledge).
///
/// مسار الإنتاج لـ Agent Knowledge يُبنى عبر [LifexProductionComposition] فقط،
/// باستخدام [LifexIntelligenceFabric.forProduction] مع Orchestrator و KE مشتركين.
/// البناء الحر هنا مسموح للاختبارات/LIO المنفصل — وليس بديلاً عن جذر الإنتاج.
class LifexIntelligenceFabric {
  LifexIntelligenceFabric({
    this.existingOrchestrator,
    LifexIntelligenceOrchestrator? lio,
    LifexLioCanon? canon,
    this.liveMcp,
    this.knowledgeEngine,
    this.ingestionPipeline,
  })  : canon = canon ?? const LifexLioCanon(),
        lio = lio ?? LifexIntelligenceOrchestrator();

  /// تركيب إنتاجي صريح — يحقن Orchestrator و Knowledge Engine من جذر الإنتاج.
  factory LifexIntelligenceFabric.forProduction({
    required AgentOrchestrator existingOrchestrator,
    LifexKnowledgeEngine? knowledgeEngine,
    KnowledgeIngestionPipeline? ingestionPipeline,
    LifexMcpLiveGateway? liveMcp,
    LifexIntelligenceOrchestrator? lio,
    LifexLioCanon? canon,
  }) {
    return LifexIntelligenceFabric(
      existingOrchestrator: existingOrchestrator,
      knowledgeEngine: knowledgeEngine,
      ingestionPipeline: ingestionPipeline,
      liveMcp: liveMcp,
      lio: lio,
      canon: canon,
    );
  }

  final LifexLioCanon canon;

  /// عقل القيادة الجديد.
  final LifexIntelligenceOrchestrator lio;

  /// منسّق المهام الحالي داخل التطبيق — يُعاد استخدامه، لا يُستبدل صامتاً.
  final AgentOrchestrator? existingOrchestrator;

  /// بوابة MCP الحيّة (Foundation) — اختيارية حتى تُبنى صراحة.
  final LifexMcpLiveGateway? liveMcp;

  /// Knowledge Engine Foundation — اختياري؛ ليس SoT بذاته.
  final LifexKnowledgeEngine? knowledgeEngine;

  /// مسار Registry → Ingestion → Corpus (لا يتجاوز provenance).
  final KnowledgeIngestionPipeline? ingestionPipeline;

  LifexMcpGateway get mcp => lio.mcp;
  LifexUnifiedMemory get memory => lio.memory;
  LifexAgentControlRegistry get agents => lio.agents;
  LifexClaimVerifier get verifier => lio.verifier;
  LifexSourceReliabilityEngine get reliability => lio.reliability;

  /// ينشئ Live Gateway فوق نفس سجل العقود و LIO.
  LifexMcpLiveGateway attachLiveMcpGateway() {
    return LifexMcpLiveGateway(registry: mcp, lio: lio);
  }

  /// هل المسار يمنع AI→SQL؟
  bool get enforcesAiDataPath => !canon.aiMayTalkSqlDirectly;

  /// هل Clinical خارج سياق AI العام؟
  bool get isolatesClinicalMemory =>
      !canon.clinicalDataEntersGeneralAiMemory &&
      memory.clinicalNeverInGeneralPack;

  /// يربط محرك معرفة محليًا فوق Corpus محقون (للاختبار/التأسيس).
  LifexKnowledgeEngine attachKnowledgeEngine(KnowledgeCorpus corpus) {
    return LifexKnowledgeEngine(corpus: corpus);
  }

  Map<String, Object?> bootstrapReport() => {
        ...canon.asReport(),
        'hasExistingAgentOrchestrator': existingOrchestrator != null,
        'mcpToolCount': mcp.tools.length,
        'agentProfileCount': agents.all.length,
        'enforcesAiDataPath': enforcesAiDataPath,
        'isolatesClinicalMemory': isolatesClinicalMemory,
        'mcpLiveAttached': liveMcp != null,
        'mcpLivePhase': 'MCP_LIVE_GATEWAY_FOUNDATION',
        'knowledgeEngineAttached': knowledgeEngine != null,
        'knowledgePhase': 'KNOWLEDGE_ENGINE_HYBRID_RAG_FOUNDATION',
        'ingestionPipelineAttached': ingestionPipeline != null,
        'ingestionPhase': 'KNOWLEDGE_SOURCE_REGISTRY_INGESTION',
        'llmIsSourceOfTruth':
            knowledgeEngine?.safety.llmIsSourceOfTruth ?? false,
      };
}
