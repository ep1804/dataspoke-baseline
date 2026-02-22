# DataHub API Skill Design

<!-- Newest entries at the top. -->

---

## 2026-02-20 — Purpose Revision: Dual-Mode Q&A and Code Writer

**Context**: The initial design framed the skill as a reference playbook — a guide for *how to approach* DataHub API work. But the real usage pattern is broader: the skill will be invoked both when a developer asks a conceptual question ("does DataHub have a native field for X?") and when they want working code written and verified against the local instance ("write and test a Python module that does Y").

**What**: The skill's purpose is revised to two explicit operating modes. This changes the skill structure, the toolset it requires, and how Phase 1 routes into the rest of the flow.

**Why**: The two modes have different success criteria and require different tools. Q&A needs only file reads and analysis. Code writing needs Python execution, `acryl-datahub` installed, a valid token, and a feedback loop that reads back the written data to confirm correctness. Conflating them into one linear flow produces a skill that half-serves both.

---

### Two Operating Modes

#### Mode 1 — Q&A: Answer a Question About DataHub

**Triggered by**: questions about DataHub's data model, available fields, suitable patterns, or whether DataHub supports a concept natively.

**Flow**:
```
1. Identify what metadata type the question is about
2. Check DataHub's native model in ref/ (decision protocol below)
3. If native solution exists: describe it with exact field names, aspect name,
   URN format, and relevant ref/ file paths
4. If no native solution: explain why, then propose the minimal custom approach
   (Structured Properties before Glossary before fully custom aspects)
5. Optionally show a code sketch — but do NOT execute it in Q&A mode
```

**Tools needed**: `Read`, `Grep`, `Glob` (no Bash execution).

**Output**: a clear written answer — recommendation, rationale, and source file citations.

---

#### Mode 2 — Code Writer: Build and Test a DataHub Utility

**Triggered by**: requests to write a Python module, function, or script that interacts with DataHub.

**Flow**:
```
1. Research: find the matching tutorial and SDK example in ref/
2. Check prerequisites (see below)
3. Write the code
4. Execute against local dev_env (localhost:9004)
5. Verify the result by reading back via SDK or GraphQL
6. Iterate if the result doesn't match expectation (up to 3 cycles)
7. Report: final code + what was written + verification output
```

**Tools needed**: `Read`, `Grep`, `Glob`, `Bash(python3 *)`, `Bash(pip3 *)`, `Bash(curl *)`.

**Prerequisites check** (run before executing any code):

```bash
# 1. Check acryl-datahub is installed
python3 -c "import datahub; print(datahub.__version__)" 2>/dev/null \
  || pip3 install acryl-datahub --quiet

# 2. Check port-forward is running (GMS must be reachable)
curl -s http://localhost:9004/config | python3 -c "import sys,json; d=json.load(sys.stdin); print('GMS ok, version:', d['versions']['acryldata/datahub']['version'])" \
  || echo "ERROR: GMS not reachable. Run: dev_env/datahub-port-forward.sh"

# 3. Ensure a token is available
# Use $DATAHUB_TOKEN if set; otherwise generate one
if [ -z "$DATAHUB_TOKEN" ]; then
  echo "DATAHUB_TOKEN not set — generate via: http://localhost:9002 → Settings → Access Tokens"
fi
```

**Execution pattern** — write code to a temp file and run it:

```bash
# Write and execute
cat > /tmp/datahub_test_script.py << 'EOF'
<generated code here>
EOF
python3 /tmp/datahub_test_script.py
```

**Verification pattern** — after any write operation, read back to confirm:

```python
# Read back the written entity to verify
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
import os

graph = DataHubGraph(DatahubClientConfig(
    server="http://localhost:9004",
    token=os.environ.get("DATAHUB_TOKEN", ""),
))

# Example: verify a dataset property was written
aspect = graph.get_aspect(entity_urn=urn, aspect_type=DatasetProperties)
assert aspect is not None, "Entity not found after write"
print("Verified:", aspect)
```

**Iteration limit**: if code fails or verification fails, diagnose and fix, then re-run. Stop after 3 consecutive failures and report the blocker.

---

### Mode Selection in Phase 1

Phase 1 now has an explicit branch:

```
Is the task a question or a build request?

├── "Does DataHub have X?"
│   "What's the best way to model Y in DataHub?"
│   "Should I use Z or build custom?"
│   → MODE 1 (Q&A) — research and answer, no execution
│
└── "Write a Python module to do X"
    "Build a utility that Y"
    "Test whether Z works against local DataHub"
    → MODE 2 (Code Writer) — write, execute, verify
```

Mixed requests ("explain how X works and write the code") run Q&A first, then Code Writer.

---

### Updated Skill Identity

| Field | Value |
|---|---|
| **Modes** | Q&A (research + recommendation) \| Code Writer (write + execute + verify) |
| **Allowed tools** | `Read`, `Grep`, `Glob`, `Bash(python3 *)`, `Bash(pip3 *)`, `Bash(curl *)` |
| **GMS target** | `http://localhost:9004` (requires `datahub-port-forward.sh` running) |
| **Auth** | `$DATAHUB_TOKEN` env var or generate via `http://localhost:9002` |

---

### Action Items Added by This Revision

- [x] Update SKILL.md structure to open with the mode-selection branch (Phase 1 fork)
- [x] Add prerequisite check block to SKILL.md (acryl-datahub installed, GMS reachable, token set)
- [x] Add verification pattern to SKILL.md (read-back after every write)
- [x] Register `Bash(python3 *)`, `Bash(pip3 *)`, `Bash(curl *)` in `allowed-tools` in SKILL.md front-matter

---

## 2026-02-20 — Use Case Analysis: Platform Property & Quality Events

**Context**: Two concrete integration questions were raised that the skill must be able to answer. Researching them against the v1.4.0 DataHub source (`ref/github/datahub/`) reveals that DataHub already has native solutions for both — no custom glossary structures are needed. The findings below are encoded as **known patterns** the skill should surface when similar questions arise.

**What**: Analysis and conclusions for (1) storing a dataset's storage/DB platform property, and (2) writing custom data quality results that reference an external experiment run (e.g., MLflow).

**Why**: Establishing these patterns now prevents future contributors from re-inventing custom glossary structures for problems DataHub already solves natively. The skill should always check DataHub's data model first.

---

### Known Pattern A — Dataset Storage / DB Platform Property

**Question**: How do I record which storage or DB platform a dataset uses (iceberg, parquet, postgresql, mysql, …)?

#### DataHub's Native Model

Platform identity is built into the dataset URN. When you call `make_dataset_urn(platform=..., name=..., env=...)`, the platform is embedded as a first-class component of the unique identifier:

```
urn:li:dataset:(urn:li:dataPlatform:<platform>,<name>,<env>)
```

This is the correct place for the primary storage technology. DataHub ships with dozens of recognized platform names (`iceberg`, `parquet`, `postgresql`, `mysql`, `snowflake`, `hive`, …) and stores extended metadata about each in the `dataPlatformInfo` aspect.

If a dataset lives on a specific cluster or named instance of a platform, the `dataPlatformInstance` aspect adds that:

```python
# File: metadata-models/.../common/DataPlatformInstance.pdl
# Fields:
#   platform: Urn          → "urn:li:dataPlatform:postgresql"
#   instance: optional Urn → "urn:li:dataPlatformInstance:(urn:li:dataPlatform:postgresql,prod-us-east-1)"
```

#### When the URN Isn't Enough

If you need to annotate a dataset with a *secondary* platform attribute (e.g., a dataset whose primary platform is `s3` but whose table format is `iceberg`), use **Structured Properties** — available since v1.3, fully supported in v1.4.0.

```
Aspect definition file:
  metadata-models/.../structured/StructuredPropertyDefinition.pdl

Key fields:
  qualifiedName  string            e.g. "io.dataspoke.storage.tableFormat"
  valueType      Urn               e.g. "urn:li:dataType:datahub.string"
  allowedValues  array[PropertyValue]
  cardinality    SINGLE | MULTIPLE
  entityTypes    array[Urn]        e.g. ["urn:li:entityType:datahub.dataset"]

Value assignment aspect:
  metadata-models/.../structured/StructuredPropertyValueAssignment.pdl
```

**Example Structured Property definition for DataSpoke:**

```python
# Define once (idempotent upsert)
property_def = {
    "qualifiedName": "io.dataspoke.storage.tableFormat",
    "displayName": "Table Format",
    "valueType": "urn:li:dataType:datahub.string",
    "cardinality": "SINGLE",
    "entityTypes": ["urn:li:entityType:datahub.dataset"],
    "allowedValues": [
        {"value": {"string": "iceberg"}},
        {"value": {"string": "parquet"}},
        {"value": {"string": "delta"}},
        {"value": {"string": "orc"}},
    ],
}
```

#### Decision

| Scenario | Recommendation |
|---|---|
| Platform IS the primary storage technology | Encode in dataset URN (`make_dataset_urn(platform="iceberg", ...)`) |
| Named cluster or instance of a platform | Use `dataPlatformInstance` aspect |
| Secondary format attribute alongside a primary platform | Use **Structured Properties** |
| Any of the above | **Never use Glossary Terms** — they are for business vocabulary, not technical platform metadata |

#### Reference Files

| File | Purpose |
|---|---|
| `li-utils/.../common/DataPlatformUrn.pdl` | URN format for data platforms |
| `metadata-models/.../common/DataPlatformInstance.pdl` | `dataPlatformInstance` aspect fields |
| `metadata-models/.../structured/StructuredPropertyDefinition.pdl` | Structured property schema |
| `metadata-models/.../structured/StructuredPropertyValueAssignment.pdl` | Attaching values to entities |
| `metadata-ingestion/src/datahub/emitter/mce_builder.py` | `make_dataset_urn()` |
| `docs/api/tutorials/structured-properties.md` | Tutorial |

---

### Known Pattern B — Custom Quality Checker Results with External Experiment Link

**Question**: How do I write a custom data quality checker's result as an event when the result includes a link to an MLflow experiment run?

#### DataHub's Native Model

DataHub models quality checks as **Assertion** entities with **AssertionRunEvent** timeseries aspects. For fully custom checkers (not GE, dbt, or SQL), use `CustomAssertionInfo`.

**AssertionInfo** (`assertionInfo` aspect on `urn:li:assertion:<id>`):
```
File: metadata-models/.../assertion/AssertionInfo.pdl
Fields:
  type: CUSTOM
  customAssertion: CustomAssertionInfo
    .type: string          → your category, e.g. "mlflow-quality-check"
    .entity: Urn           → the dataset URN being monitored
    .field: optional Urn   → if checking a specific column
    .logic: optional string → description of the check logic
  description: optional string
```

**AssertionRunEvent** (`assertionRunEvent` timeseries aspect):
```
File: metadata-models/.../assertion/AssertionRunEvent.pdl
Fields:
  timestampMillis: long
  runId: string              → your run identifier (e.g. mlflow run ID)
  asserteeUrn: Urn           → dataset URN
  status: COMPLETE
  result: AssertionResult
    .type: SUCCESS | FAILURE | ERROR
    .externalUrl: string     → ← MLflow experiment/run URL goes here
    .nativeResults: map[string, string]  → arbitrary key-value metrics
    .error: optional AssertionResultError
```

**`externalUrl` is the exact field designed for this.** `nativeResults` carries supporting metrics (precision, recall, etc.) as key-value pairs.

#### Python SDK

`DataHubGraph` in `metadata-ingestion/src/datahub/ingestion/graph/client.py` provides two methods directly:

```python
# Step 1: Create the assertion (idempotent)
assertion_urn = graph.upsert_custom_assertion(
    urn=None,                        # auto-generated or pass a stable URN
    entity_urn="urn:li:dataset:...", # dataset being checked
    type="mlflow-quality-check",     # your category string
    description="Monthly feature drift check",
    platform_name="dataspoke-quality",
    external_url="https://mlflow.company.com/experiments/42",  # link to the experiment
)

# Step 2: Report each run result
graph.report_assertion_result(
    urn=assertion_urn,
    timestamp_millis=round(time.time() * 1000),
    type="SUCCESS",            # or "FAILURE" / "ERROR"
    external_url="https://mlflow.company.com/experiments/42/runs/abc123",  # specific run
    properties=[               # nativeResults as list of {key, value}
        {"key": "precision", "value": "0.95"},
        {"key": "recall",    "value": "0.92"},
        {"key": "f1_score",  "value": "0.935"},
    ],
)
```

Real usage is verified by smoke tests in `smoke-test/tests/assertions/custom_assertions_test.py`.

#### Why Not Glossary Terms

Glossary Terms are static annotations — they express what a dataset *is*, not what happened to it at a point in time. Quality run results are timeseries data (multiple runs, each timestamped, each with a status). There is no way to query "latest run result" or "runs over the last 30 days" from a Glossary Term. Use `AssertionRunEvent` instead.

#### Decision

| Approach | Verdict |
|---|---|
| `CustomAssertionInfo` + `AssertionRunEvent.externalUrl` | **Correct** — native DataHub, queryable timeseries, designed for this |
| `AssertionRunEvent.nativeResults` for metrics | **Correct** — map[string,string] for supporting key-value data |
| Custom Glossary structure | **Wrong** — static annotations, no timeseries, no run status |
| `DataQualityContract` | Not relevant here — contracts define SLAs, not per-run results |

#### Reference Files

| File | Purpose |
|---|---|
| `metadata-models/.../assertion/AssertionInfo.pdl` | Assertion entity aspect |
| `metadata-models/.../assertion/CustomAssertionInfo.pdl` | Custom assertion subtype |
| `metadata-models/.../assertion/AssertionRunEvent.pdl` | Timeseries run event (has `externalUrl`) |
| `metadata-models/.../assertion/AssertionResult.pdl` | Result with `externalUrl` + `nativeResults` |
| `metadata-ingestion/src/datahub/ingestion/graph/client.py` | `upsert_custom_assertion()`, `report_assertion_result()` |
| `smoke-test/tests/assertions/custom_assertions_test.py` | End-to-end usage example |
| `docs/api/tutorials/custom-assertions.md` | Tutorial |

---

### Skill Design Implications

These two cases establish a decision protocol the skill should follow for any "should I use DataHub or build my own?" question:

```
1. Identify the metadata type: is it entity metadata, annotations,
   timeseries events, or business classification?

2. Check DataHub's native aspects first:
   - Entity metadata → DatasetProperties, DataPlatformInstance
   - Typed custom attributes → Structured Properties
   - Quality / operational events → AssertionRunEvent (timeseries)
   - Business vocabulary → Glossary Terms (only this case)

3. Only propose a custom structure if no native aspect covers the need
   after checking metadata-models/ and docs/api/tutorials/.
```

The `reference.md` companion file for the skill should include this protocol and the two patterns above as worked examples.

---

## 2026-02-20 — Initial Design

**Context**: DataSpoke's backend services must integrate tightly with DataHub's REST API, GraphQL API, and Python SDK. When Claude implements these integrations, it needs a structured playbook: where to look up reference material, how to reach the local dev instance, and how to authenticate and test calls — without resorting to ad-hoc `kubectl` commands.

**What**: Design a Claude Code skill (`datahub-api`) that encodes this playbook as a reusable, invocable skill under `.claude/skills/datahub-api/`.

**Why**: Without a skill, every DataHub API task requires re-deriving the same setup steps (auth, endpoint addresses, reference paths). A skill makes these steps systematic and shareable across all DataSpoke backend work.

---

### 1. Skill Identity

| Field | Value |
|---|---|
| **Name** | `datahub-api` |
| **Invocation** | `/datahub-api <task>` (manual) or auto-triggered on DataHub API tasks |
| **Trigger condition** | Any task involving DataHub GraphQL queries, REST/OpenAPI calls, `acryl-datahub` SDK usage, or questions about DataHub's data model |
| **Agent type** | `general-purpose` |
| **Allowed tools** | `Read`, `Grep`, `Glob`, `Bash(python3 *)`, `Bash(pip3 *)`, `Bash(curl *)` |
| **File location** | `.claude/skills/datahub-api/SKILL.md` |
| **Operating modes** | **Q&A** (research + answer) and **Code Writer** (write + execute + verify) — see 2026-02-20 revision |

---

### 2. Skill Structure

The skill SKILL.md is organized into five phases. **Phase 1 forks into two paths** — Q&A and Code Writer — and only the Code Writer path requires Phases 3–5 in full:

```
Phase 1 — Understand the task & select mode
            ├── Q&A mode  → Phase 2 → answer → done
            └── Code mode → Phase 2 → Phase 3 → Phase 4 (if needed) → Phase 5

Phase 2 — Look up reference material in ref/github/datahub
Phase 3 — Check prerequisites (acryl-datahub, port-forward, token)
Phase 4 — Explore live API documentation (optional, fallback from static ref)
Phase 5 — Write code → execute → verify → iterate → report
```

---

### 3. Phase 1 — Understand the Task & Select Mode

**Step 1 — Select operating mode:**

| If the task looks like… | Mode |
|---|---|
| "Does DataHub have X?", "What's the best way to model Y?", "Should I use Z or build custom?" | **Q&A** — research and answer, no execution |
| "Write a Python module to do X", "Build a utility for Y", "Test whether Z works" | **Code Writer** — write, execute, verify |
| Mixed ("explain and write the code") | Q&A first, then Code Writer |

**Step 2 — Identify the API layer** (both modes):

| Task | API to use |
|---|---|
| Search, entity reads, lineage queries (UI-facing) | GraphQL |
| Emit lineage, custom aspects, bulk ingestion | Python SDK (`DatahubRestEmitter`) |
| Token management, soft delete, batch operations | GraphQL mutation |
| Advanced admin, index management | OpenAPI REST |

**Step 3 — Identify entity type** (both modes): dataset, dashboard, chart, tag, lineage, assertion, structured property, …

After Phase 1, Q&A routes directly to Phase 2 → answer. Code Writer continues through Phases 2–5.

---

### 4. Phase 2 — Reference Navigation

The full DataHub source (v1.4.0) lives in `ref/github/datahub/`. The skill encodes a lookup table so Claude knows exactly where to go for each type of question.

#### 4.1 Reference Lookup Table

| Question type | Where to look |
|---|---|
| "What GraphQL query does X?" | `ref/github/datahub/docs/api/graphql/getting-started.md`<br>`ref/github/datahub/docs/api/graphql/graphql-best-practices.md`<br>`ref/github/datahub/datahub-graphql-core/src/main/resources/*.graphql` |
| "How do I emit / write X via SDK?" | `ref/github/datahub/docs/api/tutorials/<topic>.md`<br>`ref/github/datahub/metadata-ingestion/examples/library/` |
| "What is the URN format for X?" | `ref/github/datahub/docs/api/tutorials/datasets.md`<br>`ref/github/datahub/metadata-ingestion/src/datahub/emitter/mce_builder.py` |
| "How does the emitter / client work?" | `ref/github/datahub/metadata-ingestion/src/datahub/emitter/rest_emitter.py`<br>`ref/github/datahub/metadata-ingestion/src/datahub/ingestion/graph/client.py` |
| "What is a MetadataChangeProposal?" | `ref/github/datahub/metadata-ingestion/src/datahub/emitter/mcp_builder.py`<br>`ref/github/datahub/metadata-ingestion/src/datahub/emitter/mcp.py` |
| "What REST endpoints exist?" | `ref/github/datahub/docs/api/openapi/` (static docs) OR live Swagger (see Phase 4) |
| "What aspects does entity X have?" | `ref/github/datahub/metadata-models/src/main/pegasus/com/linkedin/` |
| "How to auth / token management?" | `ref/github/datahub/docs/api/graphql/token-management.md` |

#### 4.2 GraphQL Schema Files

The complete GraphQL schema is split into domain files under:
```
ref/github/datahub/datahub-graphql-core/src/main/resources/
  entity.graphql       ← all entity types (Dataset, Dashboard, Chart, …)
  search.graphql       ← search and scroll queries
  lineage.graphql      ← lineage queries and mutations
  ingestion.graphql    ← ingestion sources and runs
  auth.graphql         ← token management
  common.graphql       ← shared types (Tag, GlossaryTerm, Owner, …)
  ...
```

When looking for a specific type or mutation, search across these files with Grep.

#### 4.3 SDK Examples

`ref/github/datahub/metadata-ingestion/examples/library/` contains runnable Python scripts, one per operation type. Naming convention: `<entity>_<operation>.py`. Always read the matching example before writing SDK code.

---

### 5. Phase 3 — Authenticate to Local DataHub

#### 5.1 Access Points

Both access points are managed by `dev_env/datahub-port-forward.sh`, which runs two `kubectl port-forward` processes in the background and writes their PIDs to a lock file. Run it once before starting any DataHub API work:

```bash
dev_env/datahub-port-forward.sh          # start both forwards in background
dev_env/datahub-port-forward.sh --stop   # stop both and clean up PIDs
```

| Endpoint | Local URL | Forwarded to | Purpose |
|---|---|---|---|
| DataHub Frontend | `http://localhost:9002` | `datahub-frontend` pod `:9002` | UI, GraphiQL, session-based API proxy |
| DataHub GMS | `http://localhost:9004` | `datahub-gms` service `:8080` | Direct GMS REST API, Swagger UI, SDK target |

Port numbers are read from `dev_env/.env`:
- `DATASPOKE_DEV_KUBE_DATAHUB_PORT_FORWARD_UI_PORT=9002` (existing)
- `DATASPOKE_DEV_KUBE_DATAHUB_PORT_FORWARD_GMS_PORT=9004` (new)

**Rule**: These two endpoints are the **only** permitted access points. Never use `kubectl exec`, ad-hoc `kubectl port-forward`, or direct service/pod IPs.

**If a new port-forward is needed** (e.g., Kafka, Elasticsearch): add the forwarding logic to `dev_env/datahub-port-forward.sh` (following the same background-process pattern) and update `dev_env/README.md`. Do not run one-off `kubectl port-forward` commands.

#### 5.2 Authentication Flow

Default credentials: `datahub` / `datahub`.

Most GMS endpoints require a Bearer token. Procedure to obtain one:

**Option A — Generate via GraphQL (recommended for scripts):**

```bash
# POST to the frontend proxy (handles session internally)
curl -s -X POST http://localhost:9002/api/graphql \
  -H "Content-Type: application/json" \
  -u "datahub:datahub" \
  -d '{
    "query": "mutation { createAccessToken(input: { type: PERSONAL, actorUrn: \"urn:li:corpuser:datahub\", duration: ONE_MONTH, name: \"dataspoke-dev\" }) { accessToken } }"
  }'
```

**Option B — Via UI:**
1. Open `http://localhost:9002` → Settings → Access Tokens → Generate new token
2. Copy token and set `export DATAHUB_TOKEN=<token>`

**Using the token:**
```bash
curl -s http://localhost:9004/api/graphql \
  -H "Authorization: Bearer $DATAHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __typename }"}'
```

#### 5.3 Unauthenticated Endpoints (safe for probing)

These GMS endpoints do not require auth and are useful for health checks:

- `GET http://localhost:9004/config` — server config, version, feature flags
- `GET http://localhost:9004/health` — liveness

---

### 6. Phase 4 — Explore Live API Documentation

Once authenticated, two interactive documentation interfaces are available:

#### 6.1 Swagger UI (REST/OpenAPI)

URL: `http://localhost:9004/openapi/swagger-ui/index.html`
Requires: Bearer token set in the Authorize dialog.

Use for: discovering REST endpoint paths, request schemas, response shapes.

Fetch the raw OpenAPI spec for programmatic inspection:
```bash
curl -s -H "Authorization: Bearer $DATAHUB_TOKEN" \
  http://localhost:9004/openapi/v3/api-docs | python3 -m json.tool
```

#### 6.2 GraphiQL (interactive GraphQL explorer)

URL: `http://localhost:9002/api/graphiql`
Access: session cookie from browser login (`datahub` / `datahub`).

Use for: exploring the live schema, running test queries, validating mutations before coding them.

The complete schema is also available statically in `ref/github/datahub/datahub-graphql-core/src/main/resources/` — prefer the static version for offline reference.

---

### 7. Phase 5 — Implement and Test

#### 7.1 Python SDK Setup

```python
from datahub.ingestion.graph.client import DataHubGraph
from datahub.ingestion.graph.config import DatahubClientConfig

graph = DataHubGraph(DatahubClientConfig(
    server="http://localhost:9004",
    token="<DATAHUB_TOKEN>",
))
```

For bulk emission:
```python
from datahub.emitter.rest_emitter import DatahubRestEmitter

emitter = DatahubRestEmitter("http://localhost:9004", token="<DATAHUB_TOKEN>")
```

#### 7.2 Code Writer Execution Loop

For each new operation:

1. **Read the relevant tutorial** from `ref/github/datahub/docs/api/tutorials/`
2. **Find the matching SDK example** in `ref/github/datahub/metadata-ingestion/examples/library/`
3. **Inspect the live schema** via GraphiQL or Swagger if the static ref doesn't answer the question
4. **Write the code** targeting `http://localhost:9004`; inject `DATAHUB_TOKEN` from env
5. **Execute** via `python3 /tmp/datahub_test_script.py`
6. **Verify** by reading back the written entity using `DataHubGraph.get_aspect()` or a GraphQL query
7. **Iterate** on failure — diagnose error, fix, re-run; stop after 3 failures and report the blocker
8. **Report** the final code, what was written/verified, and any caveats

#### 7.3 Common URN Builders

```python
from datahub.emitter.mce_builder import (
    make_dataset_urn,        # urn:li:dataset:(urn:li:dataPlatform:<p>,<name>,<env>)
    make_data_platform_urn,  # urn:li:dataPlatform:<name>
    make_schema_field_urn,   # urn:li:schemaField:(<dataset_urn>,<field>)
    make_tag_urn,            # urn:li:tag:<name>
    make_user_urn,           # urn:li:corpuser:<username>
    make_group_urn,          # urn:li:corpGroup:<name>
    make_domain_urn,         # urn:li:domain:<uuid>
)
```

#### 7.4 Emitter Behavior to Know

- **Retry**: 3 attempts on `[429, 500, 502, 503, 504]` with exponential backoff
- **Payload limit**: ~15 MB per request; split large batches
- **Async tracing**: trace ID in `traceparent` response header (W3C format)
- **Rate limiting**: exponential back-off on 429 with 2× multiplier

---

### 8. Constraints Enforced by the Skill

1. **Never use `kubectl exec` to interact with DataHub** — it bypasses the intended API surface and doesn't reflect production behavior.
2. **Never run ad-hoc `kubectl port-forward`** — if a new port is needed, add it to `dev_env/datahub-port-forward.sh` following the same background-process pattern, and propose the change to the user.
3. **Always read the matching tutorial/example first** before writing API code — the reference library is complete and avoids re-inventing patterns.
4. **Prefer static `ref/` lookup over live API exploration** for speed — only fall back to Swagger/GraphiQL when the static ref is ambiguous.

---

### 9. Action Items

**dev_env:**
- [x] Modify `dev_env/datahub-port-forward.sh`:
  - Add `DATASPOKE_DEV_KUBE_DATAHUB_PORT_FORWARD_GMS_PORT` (default `9004`) to `dev_env/.env` and `.env.example`
  - Run both `kubectl port-forward` processes in the background (`... &`); write PIDs to `dev_env/.datahub-port-forward.pid`
  - Add `--stop` flag: kill both PIDs and remove the lock file
  - Print both access URLs on start: frontend at `:9002`, GMS at `:9004`

**Skill files:**
- [x] Create `.claude/skills/datahub-api/SKILL.md` with:
  - Front-matter: `allowed-tools: Read, Grep, Glob, Bash(python3 *), Bash(pip3 *), Bash(curl *)`
  - Phase 1 mode-selection fork (Q&A vs. Code Writer)
  - Prerequisite check block (acryl-datahub, GMS reachable, token)
  - Five-phase flow with Code Writer execution loop (write → execute → verify → iterate)
- [x] Create `.claude/skills/datahub-api/reference.md` with:
  - Reference lookup table (Phase 2)
  - Decision protocol (native DataHub vs. custom)
  - Known Pattern A (platform property) and Pattern B (quality events with external URL)

**Registration:**
- [x] Register `datahub-api` in `CLAUDE.md` skill table
- [ ] Verify token generation and GMS connectivity end-to-end against the local cluster
