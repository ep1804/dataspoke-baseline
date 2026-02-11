---
name: plan-doc
description: Write specification or planning documents in spec/ following the project style. Use when the user asks to design, spec out, or document a new DataSpoke feature, component, or architectural decision.
argument-hint: <topic>
allowed-tools: Read, Write, Edit
---

1. **Read context before writing**:
   - `spec/ARCHITECTURE.md` — system architecture, tech stack, data flows
   - `spec/MANIFESTO_en.md` — product philosophy
   - `spec/USE_CASE.md` — conceptual scenarios for reference

2. **Determine document type** from `$ARGUMENTS`:
   - *Design spec*: component design with interfaces, data models, algorithms
   - *Plan*: implementation phases, milestones, open questions
   - *ADR*: problem, options, decision, consequences

3. **Follow the existing style**: H1 title, metadata block, H2 TOC, ASCII diagrams, tables for comparisons, code blocks for schemas/interfaces, "Open Questions" section at the end.

4. **Write to `spec/<TOPIC-SLUG>.md`** (e.g., `spec/SEMANTIC_SEARCH.md`).

5. If the new doc introduces components or decisions that belong in the architecture overview, update `spec/ARCHITECTURE.md`.

---

Use this document template:

```markdown
# <Title>

> **Version**: 0.1 | **Status**: Draft | **Date**: YYYY-MM-DD

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

## Open Questions
- [ ]
```
