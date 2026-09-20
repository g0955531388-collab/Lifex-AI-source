/// =============================================================
/// Lifex-AI — KnowledgeRetriever = Compatibility Facade فقط
/// المسار: Agent → Bridge → Knowledge Engine → Evidence Pack
/// ممنوع: محرك استرجاع موازٍ أو تجاوز Knowledge Engine.
/// =============================================================
library lifex_ai.core.agent.knowledge.knowledge_retriever;

import '../../../data/medical_database_manager.dart';
import '../../lio/knowledge_engine/evidence_pack.dart';
import '../../lio/knowledge_engine/knowledge_engine.dart';
import '../../lio/knowledge_engine/retrieval_adapters.dart';
import 'knowledge_context.dart';
import 'knowledge_engine_bridge.dart';
import 'medical_bundle_corpus_seeder.dart';

/// عقد الاسترجاع للمستهلكين (أدوات/وكلاء/اختبارات وهمية).
abstract class KnowledgeRetriever {
  /// الواجهة الإنتاجية الافتراضية — تفوّض حصراً إلى Knowledge Engine.
  factory KnowledgeRetriever({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge? bridge,
    MedicalBundleCorpusSeeder? seeder,
    bool engineAvailable = true,
  }) {
    return KnowledgeEngineBridgedRetriever(
      databaseManager: databaseManager,
      knowledgeEngine: knowledgeEngine,
      corpus: corpus,
      bridge: bridge,
      seeder: seeder,
      engineAvailable: engineAvailable,
    );
  }

  Future<KnowledgeContext> retrieve(String query, {int maxResults = 8});

  void invalidateCache();
}

/// Facade: لا يحتوي منطق بحث مستقل — Knowledge Engine وحده يسترجع.
class KnowledgeEngineBridgedRetriever implements KnowledgeRetriever {
  KnowledgeEngineBridgedRetriever({
    required MedicalDatabaseManager databaseManager,
    LifexKnowledgeEngine? knowledgeEngine,
    InMemoryKnowledgeCorpus? corpus,
    AgentKnowledgeBridge? bridge,
    MedicalBundleCorpusSeeder? seeder,
    this.engineAvailable = true,
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
  final bool engineAvailable;

  bool _seeded = false;
  int _engineRetrieveCalls = 0;

  /// للاختبارات/الحراسة: يثبت التفويض الفعلي.
  int get engineRetrieveCalls => _engineRetrieveCalls;

  bool get delegatesToKnowledgeEngine => true;

  LifexKnowledgeEngine get knowledgeEngine => _engine;

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

    if (!engineAvailable) {
      return KnowledgeContext(
        query: query,
        matches: const [],
        retrievalStatus: 'TOOL_UNAVAILABLE',
        notesAr: const [
          'TOOL_UNAVAILABLE — Knowledge Engine غير متاح؛ لا fallback موازٍ.',
        ],
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
      return KnowledgeContext(
        query: query,
        matches: const [],
        retrievalStatus: 'ENGINE_ERROR',
        notesAr: ['ENGINE_ERROR — $e'],
        llmIsSourceOfTruth: false,
      );
    }
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    // البذر ≠ استرجاع: يملأ Corpus فقط ثم يبحث المحرك القانوني.
    if (_corpus.records.isEmpty) {
      await _seeder.seedInto(_corpus, _databaseManager);
    }
    _seeded = true;
  }

  @override
  void invalidateCache() {
    _seeded = false;
    // لا نفرّغ corpus المحقون من الخارج؛ إعادة البذر عند الحاجة فقط إن كان فارغاً
    // بعد إبطال صريح عبر استبدال المحرك — هنا نسمح بإعادة محاولة البذر.
  }
}
