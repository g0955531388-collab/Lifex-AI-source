/// =============================================================
/// Lifex-AI — أنواع LIO المشتركة
/// =============================================================
library lifex_ai.core.lio.lio_types;

enum LioMissionStatus {
  drafted,
  planning,
  awaitingApproval,
  running,
  verifying,
  completed,
  failed,
  blocked,
  cancelled,
}

enum LioRiskLevel { low, medium, high, critical }

enum LioProviderKind {
  chatgptPlanning,
  cursorCode,
  githubCopilot,
  geminiResearch,
  localModel,
  human,
}

enum LioMemoryKind {
  working,
  project,
  episodic,
  semantic,
  source,
  userPreference,
  /// معزول — لا يدخل سياق AI العام أبداً.
  clinicalIsolated,
}

enum LioSourceAuthority {
  officialStandard,
  peerReviewed,
  officialVendor,
  repositoryCommit,
  documentation,
  news,
  unknownBlog,
  unverified,
}

enum LioConflictStatus { none, suspected, confirmed, unresolved }

enum LioVerificationVerdict { pass, fail, inconclusive, needsHuman }

enum LioAgentRole {
  planner,
  research,
  code,
  medicalKnowledge,
  data,
  security,
  testing,
  browser,
  github,
  device,
  criticVerifier,
}
