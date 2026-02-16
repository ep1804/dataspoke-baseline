# Manifesto Consistency Check

<!-- Newest entries at the top. -->

---

## 2026-02-16 — Consistency audit: MANIFESTO_en.md vs. all spec docs

**Context**: After today's rewrites to `ARCHITECTURE.md` and `USE_CASE.md`, a full cross-document consistency check was run against `MANIFESTO_en.md` as the canonical reference.

**What**: Four issues found across `ARCHITECTURE.md`, `CLAUDE.md`, and `USE_CASE.md`. Two are actionable fixes; two are open questions for discussion.

---

### MANIFESTO canonical facts used as reference

| Topic | Canonical form |
|-------|---------------|
| Product name | `DataSpoke` |
| Project name | `DataSpoke Baseline` |
| Goal 1 | **Baseline Product** — implement essential AI-era catalog features |
| Goal 2 | **Scaffold for AI Coding** — Claude Code utilities for rapid custom catalog development |
| Repo contents | Baseline Product · Claude Code Utilities · Development Spec |
| Feature groups | **Ingestion**, **Quality Control**, **Self-Purifier**, **Knowledge Base & Verifier** |
| Ingestion sub-features | Python-based Custom Ingestion · Management & Orchestration |
| Quality Control sub-features | Python-based Quality Model |
| Self-Purifier sub-features | Documentation Auditor · Health Score Dashboard |
| Knowledge Base & Verifier sub-features | Semantic Search API · Context Verification API |
| AI-era capability anchors | Online Verifier → Context Verification API · Self-Purification → Self-Purifier group |

---

### Issues found

| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | Critical | `CLAUDE.md:53` | `context_verifier/` missing from backend services list — left behind when it was separated from `knowledge_base/` today | Add `context_verifier` to the services list |
| 2 | Major | `ARCHITECTURE.md` | "Scaffold for AI Coding" (Goal 2) is entirely absent — `.claude/` is not in the repo structure, and no section or tenet acknowledges the Claude Code Utilities that the manifesto lists as a first-class repo content category | Add `.claude/` to repo structure; add a tenet or brief section for Goal 2 |
| 3 | Minor | `USE_CASE.md` — feature mapping table, row 5 | Sub-feature label "AI-driven ontology consistency checks & corrections" is a description, not a manifesto name. Self-Purifier's canonical sub-features are Documentation Auditor and Health Score Dashboard. Use Case 5 exercises the Self-Purification capability (§1.1), not a named §2 sub-feature | Change sub-feature cell to "Self-Purification capability (§1.1)" to distinguish it from the §2 named sub-features |
| 4 | Minor | `ARCHITECTURE.md` — Backend "Key Capabilities" | Bullet labels ("Custom Connectors", "ML Models") don't reference the manifesto's canonical sub-feature names ("Python-based Custom Ingestion", "Python-based Quality Model") | Align bullet labels or add parenthetical mappings |

---

### Action items

- [x] Fix `CLAUDE.md:53` — add `context_verifier` to backend services list
- [x] Goal 2 (Scaffold for AI Coding) — created `spec/AI_SCAFFOLD.md` as a top-level spec document; added entry to `CLAUDE.md` spec hierarchy. Decision: not included in `ARCHITECTURE.md` (separate concern).
- [x] Fix `USE_CASE.md` feature mapping table row 5 — changed sub-feature label to "Self-Purification capability (§1.1)"
- [x] Update `ARCHITECTURE.md` Backend Key Capabilities — aligned bullet names to manifesto sub-feature names ("Python-based Custom Ingestion", "Python-based Quality Model")

### Open questions

- [ ] Should `ARCHITECTURE.md` describe the Claude Code utilities architecture in detail (skills, subagents, agent teams)? Or is that sufficiently covered by CLAUDE.md and the `.claude/` directory itself?
- [x] "Management & Orchestration" is a named Ingestion sub-feature in the manifesto, but in ARCHITECTURE.md the Orchestration Layer is a standalone section covering all feature groups. Should it be restructured so that orchestration-for-ingestion is under Ingestion, or is the current cross-cutting treatment correct?
  **Decision (2026-02-16)**: M&O is cross-cutting, not an Ingestion sub-feature. Removed from §2 Ingestion in both MANIFESTO files; added to §3 Architecture Spoke description as a shared layer. In `ARCHITECTURE.md`, moved from Phase 2 to Phase 1 and reworded Phase 2 to reference the shared layer.
