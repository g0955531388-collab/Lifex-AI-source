/// =============================================================
/// Lifex-AI — تركيب إنتاجي لـ Agent Knowledge (Composition Root helper)
/// =============================================================
library lifex_ai.core.agent.knowledge.production_knowledge_composition;

import '../../../data/medical_database_manager.dart';
import '../../lio/knowledge_engine/knowledge_engine.dart';
import '../../lio/knowledge_engine/retrieval_adapters.dart';
import 'knowledge_engine_bridge.dart';
import 'knowledge_retriever.dart';
import 'medical_bundle_corpus_seeder.dart';

/// نقطة التركيب الإنتاجية — لا تستورد أي test doubles.
class ProductionKnowledgeComposition {
  const ProductionKnowledgeComposition._();

  /// يبني المسار الإلزامي:
  /// KnowledgeRetriever.production → Bridge → LifexKnowledgeEngine
  static KnowledgeRetriever createRetriever({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge bridge = const AgentKnowledgeBridge(),
    MedicalBundleCorpusSeeder seeder = const MedicalBundleCorpusSeeder(),
    bool knowledgeEngineConnected = true,
  }) {
    if (!knowledgeEngineConnected) {
      return const KnowledgeEngineUnavailableRetriever();
    }
    return KnowledgeRetriever.production(
      databaseManager: databaseManager,
      knowledgeEngine: knowledgeEngine,
      corpus: corpus,
      bridge: bridge,
      seeder: seeder,
    );
  }
}
