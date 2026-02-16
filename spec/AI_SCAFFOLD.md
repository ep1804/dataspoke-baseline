# DataSpoke Baseline: AI Coding Scaffold

> **Document Status**: Specification v0.1
> This document covers Goal 2 of the DataSpoke Baseline project: providing a ready-to-use scaffold so that an organization-specific dedicated data catalog (a "Spoke") can be built with AI in a short time.

---

## Table of Contents

1. [Purpose](#purpose)
2. [Scaffold Structure](#scaffold-structure)
3. [Utilities Catalog](#utilities-catalog)
   - [Skills](#skills)
   - [Commands](#commands)
   - [Subagents](#subagents)
4. [Permissions Model](#permissions-model)
5. [Building a Custom Spoke](#building-a-custom-spoke)
6. [Design Principles](#design-principles)

---

## Purpose

The DataSpoke Baseline pursues two goals (from `spec/MANIFESTO_en.md` §1.3):

1. **Baseline Product** — a reference implementation of the core features any AI-era data catalog must have.
2. **Scaffold for AI Coding** — sufficient conventions, development specs, and Claude Code utilities so that an organization-specific dedicated catalog can be built with AI in a short time.

This document covers **Goal 2**. The scaffold is the set of Claude Code configurations in `.claude/` that make AI-assisted development immediately productive from the first session.

**The core premise**: a well-structured scaffold removes the bootstrapping cost of AI coding — the AI agent knows the project layout, naming conventions, spec hierarchy, and operational environment before writing a single line of code.

---

## Scaffold Structure

```
.claude/
├── skills/                     # Auto-loaded prompt extensions
│   ├── kubectl/                # Kubernetes operations against local cluster
│   ├── monitor-k8s/            # Cluster health reporting
│   └── plan-doc/               # Spec document routing and authoring
├── commands/                   # User-invoked multi-step workflows
│   ├── dataspoke-dev-env-install.md
│   └── dataspoke-dev-env-uninstall.md
├── agents/                     # Subagent system prompts
│   ├── api-spec.md             # OpenAPI spec author
│   ├── backend.md              # FastAPI/Python implementer
│   ├── frontend.md             # Next.js/TypeScript implementer
│   └── k8s-helm.md             # Helm/Kubernetes/Docker author
└── settings.json               # Tool permission rules
```

The scaffold works alongside three other structural elements:
- **`CLAUDE.md`** — root-level agent instructions: project context, architecture summary, design decisions, and the full Claude Code configuration reference
- **`spec/`** — hierarchical specification documents (MANIFESTO → ARCHITECTURE → feature specs → plan logs)
- **`dev_env/`** — local Kubernetes dev environment scripts

---

## Utilities Catalog

### Skills

Skills are prompt extensions that give the agent specialized context or workflows for a specific domain. They live in `.claude/skills/` and are loaded when the user invokes them explicitly (`/skill-name`) or when Claude detects a matching context.

| Skill | Invocation | Scope | Purpose |
|-------|-----------|-------|---------|
| `kubectl` | `/kubectl <operation>` | User-invoked only | Run kubectl/helm operations against the local cluster; reads cluster name and namespaces from `dev_env/.env` |
| `monitor-k8s` | `/monitor-k8s [focus]` | User-invoked; runs in forked subagent | Full cluster health report: pod status, recent events, Helm releases |
| `plan-doc` | `/plan-doc <topic>` | User-invoked or auto-triggered when writing specs | Route spec authorship to the correct tier (`spec/feature/` vs `spec/plan/`) and enforce document format |

### Commands

Commands are user-invoked multi-step workflows — scripted sequences of agent actions that would otherwise require many manual steps. They live in `.claude/commands/`.

| Command | Invocation | Purpose |
|---------|-----------|---------|
| `dataspoke-dev-env-install` | `/dataspoke-dev-env-install` | End-to-end dev environment setup: configure `dev_env/.env`, run preflight checks, execute `install.sh`, monitor pod readiness, report access URLs |
| `dataspoke-dev-env-uninstall` | `/dataspoke-dev-env-uninstall` | Controlled teardown: show current cluster state, confirm with user, run `uninstall.sh`, clean up orphaned PVs |

### Subagents

Subagents are specialized Claude instances with focused system prompts. The main agent delegates to them automatically when the task context matches. They live in `.claude/agents/`.

| Subagent | Trigger context | Scope | Memory |
|----------|----------------|-------|--------|
| `api-spec` | Designing or writing OpenAPI 3.0 specs in `api/` | API-first design; outputs YAML specs + companion markdown | Session |
| `backend` | Implementing FastAPI/Python in `src/api/`, `src/backend/`, `src/workflows/`, `src/shared/` | All four feature group services | Project (persists across sessions in `.claude/agent-memory/`) |
| `frontend` | Implementing Next.js/TypeScript in `src/frontend/` | UI components, pages, hooks, API client | Project (persists across sessions in `.claude/agent-memory/`) |
| `k8s-helm` | Writing Helm charts, Dockerfiles, or dev env scripts | Container images, K8s manifests, Helm chart templates | Session |

`backend` and `frontend` subagents use **project memory** — they accumulate module locations, naming patterns, and architectural decisions in `.claude/agent-memory/` and carry that knowledge into future sessions without requiring re-orientation.

---

## Permissions Model

Defined in `.claude/settings.json`. The guiding principle: **read freely, mutate with confirmation, never destroy**.

| Category | Policy |
|----------|--------|
| Read-only operations (`kubectl get`, `helm list`, `git log`, `docker ps`) | Auto-allowed |
| Mutating operations (`kubectl apply`, `helm install`, `helm upgrade`, `kubectl rollout`) | Prompt for confirmation |
| Destructive operations (`kubectl delete namespace`, `rm -rf`, `sudo`) | Always blocked |

This allows the agent to freely inspect the local cluster state while requiring explicit user approval before changing it.

---

## Building a Custom Spoke

The scaffold is designed to be forked and adapted for an organization's specific needs. A custom Spoke is a DataSpoke implementation tailored to the organization's data sources, domain vocabulary, and operational requirements.

### Typical customization points

```
Fork dataspoke-baseline
│
├── spec/MANIFESTO_*.md         ← Define your org's product identity and feature scope
├── spec/ARCHITECTURE.md        ← Adjust stack choices (e.g. Airflow over Temporal)
├── spec/feature/               ← Write feature specs for org-specific extensions
│
├── src/backend/ingestion/      ← Add connectors for your data sources
├── src/backend/quality/        ← Configure ML models for your data patterns
│
├── dev_env/.env                ← Point to your cluster and namespaces
└── .claude/agents/backend.md  ← Extend with org-specific conventions
```

### Recommended sequence

1. **Revise the manifesto** — redefine product identity, feature scope, and naming for your org
2. **Update `ARCHITECTURE.md`** — adjust tech stack and integration points
3. **Run `/dataspoke-dev-env-install`** — bring up the local DataHub environment
4. **Use `api-spec` subagent** — design Hub-Spoke API contracts before writing backend code
5. **Use `backend` subagent** — implement feature services iteratively, leveraging project memory
6. **Use `frontend` subagent** — build the UX layer against the API spec
7. **Use `k8s-helm` subagent** — package and deploy to your target environment

### What the scaffold saves

| Without scaffold | With scaffold |
|-----------------|--------------|
| Agent must learn project layout from scratch each session | `CLAUDE.md` + subagent project memory provides immediate context |
| No standard for spec documents → inconsistent output | `plan-doc` skill enforces spec hierarchy and format |
| Manual cluster setup and teardown | `dataspoke-dev-env-install/uninstall` commands handle it end-to-end |
| Risk of agent running destructive commands | `settings.json` permission rules block them |
| API and backend developed in parallel without contract | `api-spec` subagent establishes the contract first |

---

## Design Principles

### 1. Context before code
The agent reads the spec hierarchy (MANIFESTO → ARCHITECTURE → feature specs) before generating any implementation. `CLAUDE.md` is the entry point that orients the agent to the full project state.

### 2. Spec as the source of truth
All naming, feature taxonomy, and product identity derive from `MANIFESTO_en.md`. Subagents are instructed to consult it before making naming decisions. The `plan-doc` skill routes new documentation to the correct tier automatically.

### 3. API-first development
The `api-spec` subagent produces OpenAPI specs as standalone artifacts before backend implementation begins. This allows frontend and backend subagents to work from a shared contract without requiring a running service.

### 4. Least privilege for agent tools
The permissions model is conservative by default. Agents can read and inspect freely but cannot make changes to shared or persistent state without user confirmation. This is especially important for cluster operations.

### 5. Persistent subagent memory
`backend` and `frontend` subagents accumulate project knowledge in `.claude/agent-memory/` across sessions. This means the second session is more productive than the first — the agent already knows where things are and how decisions were made.
