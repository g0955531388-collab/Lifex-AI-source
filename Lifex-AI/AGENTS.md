# Lifex-AI Autonomous Agent Instructions

When executing tasks or modifying code in this repository, agents must strictly follow the 6-stage skill-based workflow defined in the `.skills/` directory:

1. **Goal**: Read and understand the objective, inspect `lifex_ai` project structure, and formulate a step-by-step plan.
2. **Implement**: Execute code changes following Flutter and Dart best practices.
3. **Impeccable**: Review UI/UX structure, responsiveness, visual consistency, and clean formatting.
4. **Simplify**: Eliminate code redundancy, refactor long functions, and keep the codebase lean.
5. **Verify**: Run builds, tests, and static checks to ensure zero errors remain.
6. **Report**: Summarize completed tasks and changes clearly.

## Lifex Intelligence Orchestrator (LIO)

Lifex owns the contracts. ChatGPT / Cursor / Gemini / Copilot are **swappable tools**, not the sole brain.

- Path for AI data access (never AI → SQL):  
  `AI → AI Gateway → Identity → Authorization → Consent → Purpose → Scope → Sanitization → Repository → Result`
- **Memory ≠ Source of Truth.** Git, DB, documents, clinical records, and audit are SoT. Memory is index/cache/context only.
- **Clinical / personal health data** never enters general AI memory.
- High-risk actions need **Verifier evidence** (analyze/test/build/SHA) then **human approval**.
- First executable slice lives under `lifex_ai/lib/core/lio/`: LIO, MCP Gateway, Unified Memory, Source/Provenance, Agent Registry, Verifier.
- **MCP Live Gateway Foundation** (`lib/core/lio/mcp_live/`): sole path  
  `Identity→Auth→Consent→Purpose→Scope→Policy→Gateway→Adapter→Result→Verifier→Audit`.  
  Remote tools return `TOOL_UNAVAILABLE` (never fake success). Do **not** start Knowledge/RAG in the same wave.
- **CI Evidence Verifier** (`lib/core/lio/ci_evidence/`):  
  `MCP Gateway → GitHub READ → CiEvidence → LifexClaimVerifier → VERIFIED|FAILED|NOT_VERIFIED|TOOL_UNAVAILABLE → Audit`.  
  Never treat agent report as CI proof. READ ONLY.
- **Knowledge Engine + Hybrid RAG Foundation** (`lib/core/lio/knowledge_engine/`):  
  `Source → Ingestion/Index → Keyword|Vector*|Metadata|Graph|SQL* → Rerank → Evidence Pack → LIO → Verifier`.  
  LLM is **not** source of truth. Knowledge ≠ Clinical ≠ AI Memory. No diagnose/prescribe.  
  `*` Vector/SQL adapters may be `TOOL_UNAVAILABLE` until a live engine is wired.
- **Knowledge Source Registry + Ingestion** (`lib/core/lio/knowledge_engine/ingestion/`):  
  `Registry → Validate → Acquire → Normalize → Segment → Provenance → Duplicate/Conflict → Quarantine|Corpus → Knowledge Engine`.  
  No clinical/patient data. No silent overwrite. Existence ≠ authority.  
  **Unified Production Composition** (`lib/core/lio/lifex_production_composition.dart`): sole production root  
  `LifexProductionComposition → Fabric → AgentCore → ProductionKnowledgeComposition → Bridge → Knowledge Engine`.  
  Agent `KnowledgeRetriever` is a Compatibility Facade only — no Stub/Legacy fallback in production.  
  Test doubles live under `test/support/` and must be injected explicitly.
- Reuse existing `AgentOrchestrator` / engines. Do not invent medical facts. Do not force-push `main`. Package name stays `lifex_ai`.
