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
- Reuse existing `AgentOrchestrator` / engines. Do not invent medical facts. Do not force-push `main`. Package name stays `lifex_ai`.
