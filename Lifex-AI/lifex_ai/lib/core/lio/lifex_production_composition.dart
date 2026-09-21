/// =============================================================
/// Lifex-AI — Production Composition Root (موحّد)
/// المسار الوحيد لإنتاج Agent Knowledge + Fabric + AgentCore.
/// =============================================================
library lifex_ai.core.lio.lifex_production_composition;

import '../../data/medical_database_manager.dart';
import '../../features/ai/ai_bridge.dart';
import '../../features/ai/ai_service_router.dart';
import '../../features/emergency/risk_level_engine.dart';
import '../../features/vision/medical_ocr_reader.dart';
import '../../features/vision/smart_vision_engine.dart';
import '../agent/agent_core.dart';
import '../agent/knowledge/knowledge_engine_bridge.dart';
import '../agent/knowledge/knowledge_retriever.dart';
import '../agent/knowledge/medical_bundle_corpus_seeder.dart';
import '../agent/knowledge/production_knowledge_composition.dart';
import 'knowledge_engine/ingestion/ingestion_pipeline.dart';
import 'knowledge_engine/knowledge_engine.dart';
import 'knowledge_engine/retrieval_adapters.dart';
import 'lifex_intelligence_fabric.dart';
import 'lio_canon.dart';
import 'lio_orchestrator.dart';
import 'mcp_live/mcp_live_gateway.dart';
import '../orchestrator/clock.dart';
import '../orchestrator/lio_gateway.dart';
import '../orchestrator/lio_sensitive_action_entry.dart';

/// حزمة الإنتاج الموحّدة — Fabric و AgentCore يشتركان في نفس Knowledge Engine.
class LifexProductionBundle {
  const LifexProductionBundle({
    required this.fabric,
    required this.agentCore,
    required this.knowledgeEngine,
    required this.knowledgeRetriever,
    required this.corpus,
    required this.lioGateway,
    required this.sensitiveActionEntry,
  });

  final LifexIntelligenceFabric fabric;
  final AgentCoreBundle agentCore;

  /// null فقط عندما يُصرَّح بأن Knowledge Engine غير موصول (TOOL_UNAVAILABLE).
  final LifexKnowledgeEngine? knowledgeEngine;
  final KnowledgeRetriever knowledgeRetriever;
  final InMemoryKnowledgeCorpus corpus;

  /// بوابة LIO الإنتاجية — نفس Orchestrator من Fabric (لا بوابة ثانية مستقلة).
  final ProductionLioGateway lioGateway;

  /// نقطة دخول Application الإلزامية قبل Agent/Tool/MCP.
  final LioSensitiveActionEntry sensitiveActionEntry;

  /// مسار معرفة إنتاجي موحّد (لا Stub / لا مسار ثانٍ).
  bool get isUnifiedProductionKnowledgePath {
    if (!knowledgeRetriever.isProductionKnowledgePath) return false;
    if (!identical(fabric.knowledgeEngine, knowledgeEngine)) return false;
    if (!identical(fabric.existingOrchestrator, agentCore.orchestrator)) {
      return false;
    }
    if (!identical(agentCore.knowledgeRetriever, knowledgeRetriever)) {
      return false;
    }
    if (!identical(lioGateway.orchestrator, fabric.lio)) return false;
    if (!identical(sensitiveActionEntry.lioGateway, lioGateway)) return false;
    if (!identical(sensitiveActionEntry.agentCore, agentCore)) return false;
    if (!identical(
      sensitiveActionEntry.aiServiceRouter.hubGateway,
      sensitiveActionEntry.aiHubGateway,
    )) {
      return false;
    }
    if (knowledgeRetriever is KnowledgeEngineUnavailableRetriever) {
      return knowledgeEngine == null;
    }
    if (knowledgeRetriever is KnowledgeEngineBridgedRetriever) {
      final bridged = knowledgeRetriever as KnowledgeEngineBridgedRetriever;
      return knowledgeEngine != null &&
          identical(bridged.knowledgeEngine, knowledgeEngine);
    }
    return false;
  }
}

/// Composition Root إنتاجي واحد لمسار Agent Knowledge.
///
/// ```
/// LifexProductionComposition
///   → LifexIntelligenceFabric
///   → AgentCore
///   → ProductionKnowledgeComposition
///   → KnowledgeRetriever
///   → KnowledgeEngineBridge
///   → LifexKnowledgeEngine
/// ```
///
/// لا يوجد Composition إنتاجي ثانٍ للمعرفة. الاختبارات فقط تحقن Fake/Stub.
class LifexProductionComposition {
  const LifexProductionComposition._();

  /// المعرّف المعماري — يُستخدم في الحراس لمنع تكرار جذور الإنتاج.
  static const String compositionRootId = 'LifexProductionComposition';

  /// يبني Fabric + AgentCore فوق نفس Knowledge Engine و Retriever.
  static LifexProductionBundle assemble({
    required MedicalDatabaseManager medicalDatabaseManager,
    required AiModuleBundle aiModuleBundle,
    required AiServiceRouter aiServiceRouter,
    MedicalOcrReader? ocrReader,
    OcrTextExtractor? ocrTextExtractor,
    SmartVisionEngine? visionEngine,
    RiskLevelEngine? riskLevelEngine,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge bridge = const AgentKnowledgeBridge(),
    MedicalBundleCorpusSeeder seeder = const MedicalBundleCorpusSeeder(),
    bool knowledgeEngineConnected = true,
    LifexIntelligenceOrchestrator? lio,
    LifexLioCanon? canon,
    LifexMcpLiveGateway? liveMcp,
    KnowledgeIngestionPipeline? ingestionPipeline,
    LifexClock? clock,
    ProductionLioGateway? lioGateway,
  }) {
    final sharedCorpus = corpus ?? InMemoryKnowledgeCorpus();
    final LifexKnowledgeEngine? sharedEngine = !knowledgeEngineConnected
        ? null
        : (knowledgeEngine ??
            LifexKnowledgeEngine(
              corpus: sharedCorpus,
              safety: const KnowledgeEngineSafety(),
            ));

    final knowledgeRetriever = ProductionKnowledgeComposition.createRetriever(
      databaseManager: medicalDatabaseManager,
      knowledgeEngine: sharedEngine,
      corpus: sharedCorpus,
      bridge: bridge,
      seeder: seeder,
      knowledgeEngineConnected: knowledgeEngineConnected,
    );

    if (!knowledgeRetriever.isProductionKnowledgePath) {
      throw StateError(
        'LifexProductionComposition: production retriever required; '
        'test doubles must not enter this root.',
      );
    }

    final agentCore = AgentCore.initialize(
      medicalDatabaseManager: medicalDatabaseManager,
      aiModuleBundle: aiModuleBundle,
      aiServiceRouter: aiServiceRouter,
      knowledgeRetriever: knowledgeRetriever,
      ocrReader: ocrReader,
      ocrTextExtractor: ocrTextExtractor,
      visionEngine: visionEngine,
      riskLevelEngine: riskLevelEngine,
    );

    final fabric = LifexIntelligenceFabric.forProduction(
      existingOrchestrator: agentCore.orchestrator,
      knowledgeEngine: sharedEngine,
      ingestionPipeline: ingestionPipeline,
      liveMcp: liveMcp,
      lio: lio,
      canon: canon,
    );

    final gateway = lioGateway ??
        ProductionLioGateway(
          orchestrator: fabric.lio,
          clock: clock,
        );
    if (!identical(gateway.orchestrator, fabric.lio)) {
      throw StateError(
        'LifexProductionComposition: lioGateway.orchestrator must be the '
        'same instance as fabric.lio — no second LIO.',
      );
    }

    final entry = LioSensitiveActionEntry(
      lioGateway: gateway,
      agentCore: agentCore,
      aiServiceRouter: aiServiceRouter,
      aiHubGateway: aiServiceRouter.hubGateway,
    );

    return LifexProductionBundle(
      fabric: fabric,
      agentCore: agentCore,
      knowledgeEngine: sharedEngine,
      knowledgeRetriever: knowledgeRetriever,
      corpus: sharedCorpus,
      lioGateway: gateway,
      sensitiveActionEntry: entry,
    );
  }
}
