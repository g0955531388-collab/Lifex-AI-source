/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_core.dart
/// المسار: lib/core/agent/agent_core.dart
/// الوصف: حزمة تجميع كل مكوّنات طبقة الوكيل معاً (نفس نمط AiModuleBundle
/// في features/ai/ai_bridge.dart) — نقطة الدخول الوحيدة التي يستخدمها
/// main.dart لبناء الطبقة وربطها، دون أن تعرف الواجهات تفاصيل التركيب
/// الداخلي (AgentToolRegistry، AgentMemory، إلخ) كل واحدة على حدة.
/// =============================================================

import '../../features/ai/ai_bridge.dart';
import '../../features/ai/ai_service_router.dart';
import '../../features/emergency/risk_level_engine.dart';
import '../../features/vision/medical_ocr_reader.dart';
import '../../features/vision/smart_vision_engine.dart';
import '../../data/medical_database_manager.dart';
import 'agent_executor.dart';
import 'agent_logger.dart';
import 'agent_memory.dart';
import 'agent_orchestrator.dart';
import 'agent_planner.dart';
import 'agent_policy.dart';
import 'agent_validator.dart';
import 'agents/coordinator_agent.dart';
import 'agents/emergency_agent.dart';
import 'agents/knowledge_agent.dart';
import 'agents/medical_agent.dart';
import 'agents/report_agent.dart';
import 'agents/vision_agent.dart';
import 'knowledge/knowledge_retriever.dart';
import 'tools/agent_tool_registry.dart';
import 'tools/calculator_tool.dart';
import 'tools/document_reader_tool.dart';
import 'tools/image_analysis_tool.dart';
import 'tools/knowledge_search_tool.dart';
import 'tools/notification_tool.dart';
import 'tools/ocr_tool.dart';
import 'tools/report_generator_tool.dart';

class AgentCoreBundle {
  const AgentCoreBundle({
    required this.toolRegistry,
    required this.memory,
    required this.knowledgeRetriever,
    required this.planner,
    required this.executor,
    required this.validator,
    required this.safetyPolicy,
    required this.logger,
    required this.orchestrator,
    required this.coordinator,
  });

  final AgentToolRegistry toolRegistry;
  final AgentMemory memory;
  final KnowledgeRetriever knowledgeRetriever;
  final AgentPlanner planner;
  final AgentExecutor executor;
  final AgentValidator validator;
  final AgentSafetyPolicy safetyPolicy;
  final AgentLogger logger;
  final AgentOrchestrator orchestrator;

  /// نقطة الدخول الفعلية المقصودة للواجهة — راجع CoordinatorAgent.
  final CoordinatorAgent coordinator;
}

/// تجميع طبقة الوكيل — يُستدعى من [LifexProductionComposition] في الإنتاج
/// (بعد تهيئة aiModuleBundle). لا يبني Knowledge Retriever بنفسه؛ يجب حقن
/// مسار إنتاجي من ProductionKnowledgeComposition عبر جذر الإنتاج الموحّد.
///
/// لا يُنشئ أي خدمة أساسية جديدة بنفسه — كل الاعتماديات (medicalDatabaseManager،
/// aiModuleBundle، ocrReader، visionEngine، knowledgeRetriever) تُمرَّر جاهزة
/// (بند 35/37: إعادة استخدام الخدمات الحالية، لا تكرارها).
class AgentCore {
  AgentCore._();

  /// يتطلب [knowledgeRetriever] إنتاجياً صريحاً — لا fallback ولا nullable.
  static AgentCoreBundle initialize({
    required MedicalDatabaseManager medicalDatabaseManager,
    required AiModuleBundle aiModuleBundle,
    required AiServiceRouter aiServiceRouter,
    required KnowledgeRetriever knowledgeRetriever,
    MedicalOcrReader? ocrReader,
    OcrTextExtractor? ocrTextExtractor,
    SmartVisionEngine? visionEngine,
    RiskLevelEngine? riskLevelEngine,
  }) {
    if (!knowledgeRetriever.isProductionKnowledgePath) {
      throw ArgumentError.value(
        knowledgeRetriever,
        'knowledgeRetriever',
        'Production AgentCore requires a production KnowledgeRetriever '
            '(from ProductionKnowledgeComposition / LifexProductionComposition). '
            'Inject test doubles only in test composition.',
      );
    }

    final logger = AgentLogger.instance;
    final validator = AgentValidator();
    const safetyPolicy = AgentSafetyPolicy();
    const planner = AgentPlanner();

    final memory = AgentMemory();

    // --- تسجيل الأدوات (بند 8) ---
    final toolRegistry = AgentToolRegistry(logger: logger);
    toolRegistry.registerAll([
      KnowledgeSearchTool(retriever: knowledgeRetriever),
      const ReportGeneratorTool(),
      const CalculatorTool(),
      NotificationTool(),
      if (ocrReader != null) DocumentReaderTool(ocrReader: ocrReader),
      if (ocrTextExtractor != null) OcrTool(ocrExtractor: ocrTextExtractor),
      if (visionEngine != null) ImageAnalysisTool(visionEngine: visionEngine),
    ]);

    final executor = AgentExecutor(
      toolRegistry: toolRegistry,
      validator: validator,
      safetyPolicy: safetyPolicy,
      logger: logger,
    );

    final orchestrator = AgentOrchestrator(
      planner: planner,
      executor: executor,
      memory: memory,
      knowledgeRetriever: knowledgeRetriever,
      logger: logger,
    );

    // --- الوكلاء المتخصصون (بند 14) ---
    final medicalAgent = MedicalAgent(
      analysisEngine: aiModuleBundle.analysisEngine,
      guidanceEngine: aiModuleBundle.guidanceEngine,
    );
    const visionAgent = VisionAgent();
    final knowledgeAgent = KnowledgeAgent(retriever: knowledgeRetriever);
    const reportAgent = ReportAgent();
    final emergencyAgent = EmergencyAgent(riskEngine: riskLevelEngine);

    final coordinator = CoordinatorAgent(
      orchestrator: orchestrator,
      emergencyAgent: emergencyAgent,
      medicalAgent: medicalAgent,
      visionAgent: visionAgent,
      knowledgeAgent: knowledgeAgent,
      reportAgent: reportAgent,
    );

    return AgentCoreBundle(
      toolRegistry: toolRegistry,
      memory: memory,
      knowledgeRetriever: knowledgeRetriever,
      planner: planner,
      executor: executor,
      validator: validator,
      safetyPolicy: safetyPolicy,
      logger: logger,
      orchestrator: orchestrator,
      coordinator: coordinator,
    );
  }
}
