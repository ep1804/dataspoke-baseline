---
name: plan-doc
description: Write specification or planning documents in spec/ following the project hierarchy. Use when the user asks to design, spec out, or document a DataSpoke feature, component, architectural decision, or implementation plan.
argument-hint: <topic>
allowed-tools: Read, Write, Edit
---

## Spec Directory Hierarchy

```
spec/
├── MANIFESTO_en.md     ← Highest authority. Canonical product identity,
├── MANIFESTO_kr.md       feature taxonomy, and naming. Never modify.
├── ARCHITECTURE.md     ← Top-level system architecture overview.
├── USE_CASE.md         ← Top-level conceptual scenarios.
│
├── feature/            ← Deep-dive specs for MAJOR features.
│   │                     Clean, timeless reference format.
│   │                     No log-style content (no dates, authors, changelogs).
│   └── <FEATURE>.md
│
└── plan/               ← Specs for MINOR changes and decisions.
    │                     Chronological log style. Each entry is dated.
    └── <TOPIC>.md
```

**Routing rules:**
- Top-level `spec/` — project-wide documents only. Do NOT create new top-level files unless the topic affects the whole system and warrants an architectural-level document.
- `spec/feature/` — major feature deep-dives (e.g. `INGESTION.md`, `SEMANTIC_SEARCH.md`, `SELF_PURIFIER.md`). Topics map to the four manifesto feature groups or their sub-features.
- `spec/plan/` — minor changes, incremental decisions, implementation notes, rollout plans. Written as a living log where new entries are prepended. **File names must be `<YYYYMMDD>_<topic_slug>.md` — date-prefixed and fully lowercase with underscores** (e.g., `20260216_rewrite_plan.md`).

---

## Step 1 — Read context

Always read these before writing:
- `spec/MANIFESTO_en.md` — canonical feature taxonomy and naming (highest authority)
- `spec/ARCHITECTURE.md` — component layout, tech stack, service tree
- `spec/USE_CASE.md` — reference scenarios

If writing about a specific feature, also check for an existing `spec/feature/<FEATURE>.md` to extend rather than create a duplicate.

---

## Step 2 — Determine destination and document type from `$ARGUMENTS`

| Destination | When to use | Document type |
|-------------|-------------|---------------|
| `spec/feature/<FEATURE>.md` | Major feature: Ingestion, Quality Control, Self-Purifier, Knowledge Base & Verifier, or a named sub-feature | Feature Spec (see template A) |
| `spec/plan/<YYYYMMDD>_<topic>.md` | Minor change, ADR, implementation note, rollout plan, or anything with a specific date/milestone | Plan Log (see template B) |
| `spec/<DOC>.md` (top-level) | Only for project-wide topics that belong alongside MANIFESTO and ARCHITECTURE | Top-level spec (use template A without feature-group context) |

---

## Step 3 — Write the document

Use the template for the chosen destination. Follow these style rules for both:
- H1 title
- H2 section headings, H3 sub-headings
- ASCII diagrams for component/flow illustrations
- Tables for comparisons and field definitions
- Code blocks for schemas, interfaces, API examples
- Feature group names must match the manifesto exactly: **Ingestion**, **Quality Control**, **Self-Purifier**, **Knowledge Base & Verifier**
- Product name is always `DataSpoke` (no space)

---

## Template A — Feature Spec (`spec/feature/<FEATURE>.md`)

No version/date/author metadata block. This is a timeless reference document.

```markdown
# <Feature Name>

> Part of the **<Manifesto Feature Group>** feature group.

## Table of Contents
1. [Overview](#overview)
2. [Goals & Non-Goals](#goals--non-goals)
3. [Design](#design)
4. [Data Model](#data-model)
5. [Interfaces](#interfaces)
6. [Open Questions](#open-questions)

## Overview

## Goals & Non-Goals
### Goals
### Non-Goals

## Design

## Data Model

## Interfaces

## Open Questions
- [ ]
```

---

## Template B — Plan Log (`spec/plan/<TOPIC>.md`)

Chronological log style. New entries go at the **top** (newest first).
Each entry has a date header and structured content.

```markdown
# <Topic Name>

<!-- Newest entries at the top. -->

---

## YYYY-MM-DD — <Entry Title>

**Context**: Why this decision or plan is being written now.

**What**: What is changing or being decided.

**Why**: Rationale, trade-offs considered.

**Action items**:
- [ ] item

---

## YYYY-MM-DD — <Earlier Entry Title>

...
```

---

## Step 4 — Update cross-references if needed

- If a new `spec/feature/` document introduces components or data models that belong in the architecture overview, update `spec/ARCHITECTURE.md`.
- If the document changes how a use case is realized, note it in `spec/USE_CASE.md` as a cross-reference.
- Never modify `spec/MANIFESTO_en.md` or `spec/MANIFESTO_kr.md`.
