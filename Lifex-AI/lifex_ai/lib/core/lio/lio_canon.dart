/// =============================================================
/// Lifex-AI — قانون عقل القيادة (LIO Canon)
/// Lifex Intelligence Orchestrator فوق النماذج والوكلاء — ليس Chatbot.
/// Memory ≠ Source of Truth. AI لا يلمس SQL مباشرة.
/// =============================================================
library lifex_ai.core.lio.lio_canon;

/// قوانين ثابتة قابلة للاختبار — موجة LIO الأولى.
class LifexLioCanon {
  const LifexLioCanon();

  String get systemName => 'Lifex-AI';
  String get packageName => 'lifex_ai';
  String get orchestratorName => 'Lifex Intelligence Orchestrator';
  String get orchestratorShortName => 'LIO';

  /// النماذج أدوات متخصصة تحت LIO — لا عقل وحيد.
  bool get modelsAreSpecializedToolsNotSoleBrain => true;

  /// Cursor / Copilot / Gemini / ChatGPT كلها قابلة للتبديل.
  bool get providersAreSwappable => true;

  /// الذاكرة ليست مصدر الحقيقة.
  bool get memoryIsNotSourceOfTruth => true;

  /// Graph / RAG / Cache إسقاطات قابلة لإعادة البناء.
  bool get projectionsAreRebuildable => true;

  /// مسار البيانات الإلزامي للـAI (لا اختصار إلى SQL).
  List<String> get aiDataPath => const [
        'AI',
        'AI_GATEWAY',
        'IDENTITY',
        'AUTHORIZATION',
        'CONSENT',
        'PURPOSE',
        'DATA_SCOPE',
        'SANITIZATION',
        'REPOSITORY',
        'RESULT',
      ];

  bool get aiMayTalkSqlDirectly => false;

  /// Clinical / Personal Health Record خارج ذاكرة AI العامة.
  bool get clinicalDataEntersGeneralAiMemory => false;

  /// FHIR/HL7/DICOM محولات — ليست نموذج Lifex الأساسي.
  bool get fhirIsAdapterNotCanonicalModel => true;

  /// الادعاء بلا دليل مرفوض.
  bool get claimWithoutEvidenceIsRejected => true;

  /// المهام عالية الخطورة تحتاج موافقة بشرية.
  bool get highRiskRequiresHumanApproval => true;

  /// الطبقات الإلزامية لا تُخلط.
  List<String> get mandatoryLayers => const [
        'DATA',
        'KNOWLEDGE',
        'OBSERVATION',
        'INTERPRETATION',
        'HYPOTHESIS',
        'DIAGNOSIS',
        'DECISION',
        'ACTION',
        'CONTROL',
      ];

  /// أنواع الذاكرة الموحّدة (A–G). Clinical منفصل.
  List<String> get memoryKinds => const [
        'working',
        'project',
        'episodic',
        'semantic',
        'source',
        'user_preference',
        'clinical_isolated',
      ];

  /// وكلاء الموجة الأولى — تسجيل فقط؛ التنفيذ لاحقاً عبر MCP.
  List<String> get firstWaveAgentRoles => const [
        'planner',
        'research',
        'code',
        'medical_knowledge',
        'data',
        'security',
        'testing',
        'browser',
        'github',
        'device',
        'critic_verifier',
      ];

  /// قطعة التنفيذ الأولى المعتمدة.
  List<String> get firstExecutableSlice => const [
        'LIO',
        'MCP_GATEWAY',
        'UNIFIED_MEMORY',
        'SOURCE_PROVENANCE',
        'AGENT_REGISTRY',
        'VERIFIER',
      ];

  Map<String, Object?> asReport() => {
        'orchestrator': orchestratorShortName,
        'memoryNotSoT': memoryIsNotSourceOfTruth,
        'aiTalksSql': aiMayTalkSqlDirectly,
        'clinicalInGeneralMemory': clinicalDataEntersGeneralAiMemory,
        'fhirIsCanonical': !fhirIsAdapterNotCanonicalModel,
        'providersSwappable': providersAreSwappable,
        'firstSliceCount': firstExecutableSlice.length,
        'aiPathSteps': aiDataPath.length,
      };
}
