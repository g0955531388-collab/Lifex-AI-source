/// =============================================================
/// Lifex-AI — KnowledgeRetriever = Compatibility Facade فقط
/// Production: Agent → Bridge → LifexKnowledgeEngine → Evidence Pack
/// ممنوع: Stub/Legacy fallback في المسار الإنتاجي.
/// =============================================================
library lifex_ai.core.agent.knowledge.knowledge_retriever;

import '../../../data/medical_database_manager.dart';
import '../../lio/knowledge_engine/evidence_pack.dart';
import '../../lio/knowledge_engine/knowledge_engine.dart';
import '../../lio/knowledge_engine/retrieval_adapters.dart';
import 'knowledge_context.dart';
import 'knowledge_engine_bridge.dart';
import 'medical_bundle_corpus_seeder.dart';

/// عقد الاسترجاع — Production يحقن تنفيذ KE فقط؛ Test doubles في test/.
abstract class KnowledgeRetriever {
  /// تركيب إنتاجي إلزامي — دائماً KnowledgeEngineBridgedRetriever.
  /// لا يقبل Stub ولا يفعّل fallback عند الفشل.
  factory KnowledgeRetriever.production({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge? bridge,
    MedicalBundleCorpusSeeder? seeder,
  }) {
    return KnowledgeEngineBridgedRetriever(
      databaseManager: databaseManager,
      knowledgeEngine: knowledgeEngine,
      corpus: corpus,
      bridge: bridge,
      seeder: seeder,
    );
  }

  /// توافق مع التركيب القديم — يوجّه إلى production فقط.
  factory KnowledgeRetriever({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge? bridge,
    MedicalBundleCorpusSeeder? seeder,
  }) =>
      KnowledgeRetriever.production(
        databaseManager: databaseManager,
        knowledgeEngine: knowledgeEngine,
        corpus: corpus,
        bridge: bridge,
        seeder: seeder,
      );

  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8});

  void invalidateCache();

  /// true فقط لمسار Knowledge Engine الإنتاجي.
  bool get isProductionKnowledgePath;
}

/// Facade إنتاجي: لا بحث مستقل — يفوض حصراً عبر Bridge إلى Knowledge Engine.
class KnowledgeEngineBridgedRetriever implements KnowledgeRetriever {
  KnowledgeEngineBridgedRetriever({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge? bridge,
    MedicalBundleCorpusSeeder? seeder,
  })  : _databaseManager = databaseManager,
        _corpus = corpus ?? InMemoryKnowledgeCorpus(),
        _bridge = bridge ?? const AgentKnowledgeBridge(),
        _seeder = seeder ?? const MedicalBundleCorpusSeeder() {
    _engine = knowledgeEngine ??
        LifexKnowledgeEngine(
          corpus: _corpus,
          safety: const KnowledgeEngineSafety(),
        );
  }

  final MedicalDatabaseManager _databaseManager;
  final InMemoryKnowledgeCorpus _corpus;
  final AgentKnowledgeBridge _bridge;
  final MedicalBundleCorpusSeeder _seeder;
  late final LifexKnowledgeEngine _engine;

  bool _seeded = false;
  int _engineRetrieveCalls = 0;

  int get engineRetrieveCalls => _engineRetrieveCalls;

  bool get delegatesToKnowledgeEngine => true;

  @override
  bool get isProductionKnowledgePath => true;

  LifexKnowledgeEngine get knowledgeEngine => _engine;

  AgentKnowledgeBridge get bridge => _bridge;

  MedicalBundleCorpusSeeder get seeder => _seeder;

  @override
  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return KnowledgeContext(
        query: query,
        matches: const [],
        retrievalStatus: 'EMPTY_QUERY',
        llmIsSourceOfTruth: false,
      );
    }

    try {
      await _ensureSeeded();
      final engineQuery = _bridge.toEngineQuery(
        trimmed,
        maxResults: maxResults,
      );
      _engineRetrieveCalls++;
      final KnowledgeEvidencePack pack = await _engine.retrieve(engineQuery);
      return _bridge.toAgentContext(
        originalQuery: query,
        pack: pack,
        maxResults: maxResults,
      );
    } catch (e) {
      // لا fallback إلى Stub/Legacy — خطأ صريح فقط.
      return KnowledgeContext(
        query: query,
        matches: const [],
        retrievalStatus: 'TOOL_UNAVAILABLE',
        notesAr: [
          'TOOL_UNAVAILABLE — Knowledge Engine فشل؛ لا مسار بديل. ($e)',
        ],
        llmIsSourceOfTruth: false,
      );
    }
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    if (_corpus.records.isEmpty) {
      await _seeder.seedInto(_corpus, _databaseManager);
    }
    _seeded = true;
  }

  @override
  void invalidateCache() {
    _seeded = false;
  }
}

/// محوّل إنتاجي صادق عندما يكون Knowledge Engine غير موصول.
/// ليس Stub بحث — لا نتائج ولا Legacy fallback.
class KnowledgeEngineUnavailableRetriever implements KnowledgeRetriever {
  const KnowledgeEngineUnavailableRetriever();

  @override
  bool get isProductionKnowledgePath => true;

  @override
  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8}) async {
    return KnowledgeContext(
      query: query,
      matches: const [],
      retrievalStatus: 'TOOL_UNAVAILABLE',
      notesAr: const [
        'TOOL_UNAVAILABLE — Knowledge Engine غير موصول؛ لا Stub/Legacy fallback.',
      ],
      llmIsSourceOfTruth: false,
    );
  }

  @override
  void invalidateCache() {}
}
