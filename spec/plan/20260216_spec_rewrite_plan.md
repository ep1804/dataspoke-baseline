# Spec Documents Rewrite Plan

<!-- Newest entries at the top. -->

---

## 2026-02-16 — Align ARCHITECTURE.md and USE_CASE.md with revised MANIFESTO

**Context**: `MANIFESTO_en.md` and `MANIFESTO_kr.md` were revised and now serve as the canonical reference for DataSpoke's product identity, feature taxonomy, and naming. Downstream spec documents contained naming inconsistencies and structural gaps relative to the new canonical definitions.

**What**: Audited `ARCHITECTURE.md` and `USE_CASE.md` against the MANIFESTO and executed 10 rewrite tasks to align them.

**Why**: Consistent taxonomy across all documents ensures AI agents, contributors, and subagents derive the correct feature names, service structure, and product identity from any spec document they read.

---

### MANIFESTO Taxonomy (source of truth)

| Concept | Canonical Form |
|---------|---------------|
| Product name | `DataSpoke` (no space) |
| Project | `DataSpoke Baseline` |
| Hub | DataHub GMS — Single Source of Truth for metadata |
| Spoke | DataSpoke — business logic, dedicated UX, Orchestration, optional VectorDB |

**Four feature groups:**

| Feature Group | Sub-features |
|---------------|-------------|
| **Ingestion** | Python-based Custom Ingestion; Management & Orchestration |
| **Quality Control** | Python-based Quality Model (ML/time-series anomaly detection) |
| **Self-Purifier** | Documentation Auditor; Health Score Dashboard |
| **Knowledge Base & Verifier** | Semantic Search API; Context Verification API |

**Two AI-era capability anchors:**
- **Online Verifier** → maps to *Context Verification API*
- **Self-Purification** → maps to *Self-Purifier* feature group

---

### ARCHITECTURE.md — Issues found and resolved

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | Critical | `Data Spoke` (with space) used ~25× | Renamed to `DataSpoke` throughout |
| 2 | Critical | Backend services `search/`, `metadata/` didn't match manifesto feature groups | `search/` → `knowledge_base/` (with `semantic_search/` + `context_verifier/`); `metadata/` → `self_purifier/` |
| 3 | Critical | No dedicated Context Verification API service or router | Added `context_verifier/` service and `verification.py` router |
| 4 | Major | §"Monitoring & Observability" confused system health with Self-Purifier metadata health | Renamed to §"Infrastructure Observability" with an explicit disambiguation note |
| 5 | Minor | Dev model referenced `docker-compose.dev.yml` — actual setup is Kubernetes + Helm | Updated to reference `dev_env/install.sh` |
| 6 | Minor | Migration phases didn't map to manifesto feature groups | Renamed phases; added Phase 5: Self-Purifier |

---

### USE_CASE.md — Issues found and resolved

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | Critical | `Data Spoke` (with space) throughout | Renamed to `DataSpoke` |
| 2 | Major | Use case titles didn't reference manifesto feature groups | Prefixed each title with its feature group (e.g. "Use Case 2: Quality Control — Predictive SLA Management") |
| 3 | Major | No use case for Self-Purification (AI-driven ontology design) | Added Use Case 5: Self-Purification — AI-Driven Ontology Design |
| 4 | Minor | No feature group mapping table | Added mapping table at document top |
| 5 | Minor | API snippet `data_spoke.get_table_context()` blurred Knowledge Base vs. Verification | Updated to `dataspoke.verification.verify_context()` and `dataspoke.knowledge_base.semantic_search()` |

---

### Action items

- [x] Rename `Data Spoke` → `DataSpoke` in ARCHITECTURE.md and USE_CASE.md
- [x] Restructure backend service tree to match four manifesto feature groups
- [x] Add Context Verification API service and router
- [x] Disambiguate system observability vs. Self-Purifier metadata health
- [x] Fix dev environment model reference in ARCHITECTURE.md
- [x] Rename implementation phases to match feature groups; add Phase 5
- [x] Rename use case titles with feature group prefixes
- [x] Add feature group mapping table to USE_CASE.md
- [x] Add Use Case 5 (AI-driven ontology design scenario)
- [x] Align API snippet names in USE_CASE.md

### Open questions

- [x] Should `ARCHITECTURE.md` explicitly separate the "Knowledge Base" data store (vector DB + embeddings) from the "Verifier" runtime service? Or are they one backend service?
  **Decision (2026-02-16)**: Separated. `knowledge_base/` and `context_verifier/` are sibling backend services. The Verifier is a runtime consumer of the Knowledge Base, not a sub-module of it. Product taxonomy ("Knowledge Base & Verifier" feature group) is unchanged. See Design Decision §7 in `ARCHITECTURE.md`.
- [ ] Context Verification API is described as "real-time" — synchronous REST or streaming/WebSocket? This affects the API router and workflow design.
- [ ] Does "Scaffold for AI Coding" (Goal 2 from manifesto) warrant its own section in `ARCHITECTURE.md` documenting the Claude Code utilities architecture?
