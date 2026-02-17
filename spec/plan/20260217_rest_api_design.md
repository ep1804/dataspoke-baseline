# REST API Design Plan

> **Plan Type**: Implementation Plan
> **Created**: 2026-02-17
> **Status**: Draft
> **Target Spec Document**: `spec/API.md`

---

## Overview

This plan outlines the design and implementation approach for the DataSpoke REST API. The API will expose all four feature groups from the MANIFESTO (Ingestion, Quality Control, Self-Purifier, Knowledge Base & Verifier) plus a reflection layer for DataHub's native API.

**Key Requirements**:
1. API scope derived from MANIFESTO Feature Set and USE_CASE scenarios
2. Full compliance with `spec/API_DESIGN_PRINCIPLE_en.md`
3. Architecture alignment per `spec/ARCHITECTURE.md`
4. Dual-path strategy: DataSpoke native APIs + DataHub API reflection
5. Standalone OpenAPI 3.0 specification in `spec/API.md` for API-first development

---

## Path Convention

All DataSpoke APIs will follow a two-tier path structure to clearly separate DataSpoke-native functionality from DataHub API proxying:

```
/api/v1/dataspoke/{feature-group}/...    # DataSpoke native APIs
/api/v1/datahub/{resource}/...           # DataHub API reflection (proxy)
```

**Rationale**:
- **Clear boundary**: Users immediately understand whether they're calling DataSpoke logic or DataHub
- **Versioning**: `/v1/` allows future API evolution without breaking changes
- **Namespace safety**: `dataspoke` and `datahub` prefixes prevent path collisions

---

## Feature Group Mapping

### 1. Ingestion APIs (`/api/v1/dataspoke/ingestion`)

**Manifesto Feature**: Configuration and Orchestration of Ingestion + Python-based Custom Ingestion

**Use Case**: [Use Case 6: Legacy System Metadata Integration](../USE_CASE.md#use-case-6-ingestion--legacy-system-metadata-integration)

**Core Resources**:
```
/api/v1/dataspoke/ingestion/config               # Ingestion configurations (collection)
/api/v1/dataspoke/ingestion/config/{config_id}   # Single ingestion config

/api/v1/dataspoke/ingestion/run                  # Ingestion runs (collection)
/api/v1/dataspoke/ingestion/run/{run_id}         # Single ingestion run

/api/v1/dataspoke/ingestion/run/{run_id}/event   # Ingestion run event timeline
```

**Operations**:
| Endpoint | Method | Purpose | Use Case Ref |
|----------|--------|---------|-------------|
| `/config` | POST | Register new ingestion configuration | UC6 Step 1 |
| `/config` | GET | List all ingestion configurations | UC6 Dashboard |
| `/config/{id}` | GET | Retrieve single configuration | UC6 Monitoring |
| `/config/{id}` | PATCH | Update configuration (schedule, enrichment sources) | UC6 Iteration |
| `/config/{id}` | DELETE | Delete configuration | Cleanup |
| `/config/{id}/method/validate` | POST | Pre-flight validation of config | UC6 Registration |
| `/config/{id}/method/trigger` | POST | Manually trigger ingestion run | Ad-hoc refresh |
| `/run` | GET | List ingestion run history (filterable by config, status) | UC6 Step 5 |
| `/run/{id}` | GET | Retrieve single run details and results | UC6 Step 3 |
| `/run/{id}/event` | GET | Retrieve run execution timeline (phase logs) | UC6 Debugging |

**Meta-Classifier Usage**:
- `method/validate`: Business logic to pre-validate config before registration
- `method/trigger`: Action to start an ingestion run outside the schedule
- `event`: Audit log of run phases and status changes

---

### 2. Quality Control APIs (`/api/v1/dataspoke/quality`)

**Manifesto Feature**: Python-based Quality Model (ML-based time series anomaly detection)

**Use Case**: [Use Case 2: Predictive SLA Management](../USE_CASE.md#use-case-2-quality-control--predictive-sla-management)

**Core Resources**:
```
/api/v1/dataspoke/quality/rule                   # Quality rules (collection)
/api/v1/dataspoke/quality/rule/{rule_id}         # Single quality rule

/api/v1/dataspoke/quality/result                 # Quality check results (collection)
/api/v1/dataspoke/quality/result/{result_id}     # Single quality result

/api/v1/dataspoke/quality/alert                  # Quality alerts (collection)
/api/v1/dataspoke/quality/alert/{alert_id}       # Single quality alert
```

**Operations**:
| Endpoint | Method | Purpose | Use Case Ref |
|----------|--------|---------|-------------|
| `/rule` | POST | Create custom quality rule (Prophet model, thresholds) | UC2 Setup |
| `/rule` | GET | List all quality rules | Dashboard |
| `/rule/{id}` | GET | Retrieve single rule definition | Inspection |
| `/rule/{id}` | PATCH | Update rule parameters (threshold, model config) | Tuning |
| `/rule/{id}` | DELETE | Delete rule | Cleanup |
| `/rule/{id}/method/execute` | POST | Execute rule against a dataset (ad-hoc check) | Manual validation |
| `/result` | GET | List quality check results (filter by dataset, time range) | UC2 Historical trend |
| `/result/{id}` | GET | Retrieve single result (anomaly details, confidence) | UC2 Investigation |
| `/alert` | GET | List active alerts (filter by severity, status) | UC2 Dashboard |
| `/alert/{id}` | GET | Retrieve single alert details | UC2 Day 1 - 7:00 AM |
| `/alert/{id}/method/acknowledge` | POST | Acknowledge alert (mark as reviewed) | Incident management |
| `/alert/{id}/method/resolve` | POST | Mark alert as resolved with resolution notes | UC2 7:15 AM Response |

**Meta-Classifier Usage**:
- `method/execute`: Trigger quality rule execution outside scheduled runs
- `method/acknowledge`: State transition (new → acknowledged)
- `method/resolve`: State transition (acknowledged → resolved)

---

### 3. Self-Purifier APIs (`/api/v1/dataspoke/self-purifier`)

**Manifesto Feature**: Documentation Auditor + Health Score Dashboard

**Use Case**: [Use Case 4: Metadata Health Monitoring](../USE_CASE.md#use-case-4-self-purifier--metadata-health-monitoring) + [Use Case 5: AI-Driven Ontology Design](../USE_CASE.md#use-case-5-self-purification--ai-driven-ontology-design)

**Core Resources**:
```
/api/v1/dataspoke/self-purifier/health-score                   # Health scores (collection)
/api/v1/dataspoke/self-purifier/health-score/{entity_urn}      # Single entity health score

/api/v1/dataspoke/self-purifier/issue                          # Documentation issues (collection)
/api/v1/dataspoke/self-purifier/issue/{issue_id}               # Single issue

/api/v1/dataspoke/self-purifier/ontology                       # Ontology analysis (collection)
/api/v1/dataspoke/self-purifier/ontology/{cluster_id}          # Single semantic cluster
```

**Operations**:
| Endpoint | Method | Purpose | Use Case Ref |
|----------|--------|---------|-------------|
| `/health-score` | GET | List health scores (filter by dept, score range) | UC4 Week 1, Month 1 |
| `/health-score/{urn}` | GET | Retrieve single entity health score breakdown | UC4 Detailed Dept View |
| `/health-score/{urn}/event` | GET | Health score history timeline | UC4 Month 3 Trend |
| `/issue` | GET | List documentation issues (filter by severity, owner, status) | UC4 Marketing Dept Report |
| `/issue/{id}` | GET | Retrieve single issue details | UC4 Week 2 Notification |
| `/issue/{id}/method/fix` | POST | Auto-apply suggested fix (if available) | UC4 One-click resolution |
| `/issue/{id}/method/snooze` | POST | Snooze issue for N days | UC4 Email Actions |
| `/issue/{id}/method/delegate` | POST | Reassign issue to another owner | UC4 Team handoff |
| `/ontology` | GET | List semantic clusters with conflicts | UC5 Phase 1 |
| `/ontology/{cluster_id}` | GET | Retrieve cluster analysis (similarity matrix, proposals) | UC5 Phase 2 |
| `/ontology/{cluster_id}/method/approve-proposal` | POST | Approve ontology design proposal | UC5 User Decision |
| `/ontology/{cluster_id}/method/scan-violations` | POST | Trigger consistency check against ontology rules | UC5 Phase 3 |

**Meta-Classifier Usage**:
- `event`: Health score history over time
- `method/fix`, `method/snooze`, `method/delegate`: Issue management actions
- `method/approve-proposal`, `method/scan-violations`: Ontology workflow actions

---

### 4. Knowledge Base APIs (`/api/v1/dataspoke/knowledge-base`)

**Manifesto Feature**: Semantic Search API

**Use Case**: [Use Case 3: Semantic Data Discovery](../USE_CASE.md#use-case-3-knowledge-base--semantic-data-discovery)

**Core Resources**:
```
/api/v1/dataspoke/knowledge-base/search          # Semantic search endpoint
/api/v1/dataspoke/knowledge-base/embedding       # Embedding management (collection)
```

**Operations**:
| Endpoint | Method | Purpose | Use Case Ref |
|----------|--------|---------|-------------|
| `/search` | POST | Semantic search with natural language query | UC3 Query |
| `/search` | GET | Search with query params (alternative to POST) | Simple queries |
| `/embedding` | POST | Force regenerate embeddings for entity | Maintenance |
| `/embedding` | GET | List embedding status (stale, missing, fresh) | Health check |

**Request/Response Example** (UC3):
```json
POST /api/v1/dataspoke/knowledge-base/search
{
  "query": "Find tables with European user PII used by marketing analytics",
  "filters": {
    "tags": ["PII", "GDPR"],
    "domains": ["marketing"]
  },
  "limit": 10
}

Response:
{
  "results": [
    {
      "entity_urn": "urn:li:dataset:...",
      "name": "users.eu_customers_master",
      "relevance_score": 0.98,
      "pii_fields": ["email", "full_name", "phone"],
      "compliance_status": {...}
    }
  ],
  "total_count": 8,
  "query_time_ms": 2300
}
```

---

### 5. Context Verifier APIs (`/api/v1/dataspoke/verifier`)

**Manifesto Feature**: Context Verification API (Online Verifier)

**Use Case**: [Use Case 1: Online Verifier — AI Pipeline Context Verification](../USE_CASE.md#use-case-1-online-verifier--ai-pipeline-context-verification)

**Core Resources**:
```
/api/v1/dataspoke/verifier/context               # Context verification endpoint
```

**Operations**:
| Endpoint | Method | Purpose | Use Case Ref |
|----------|--------|---------|-------------|
| `/context` | POST | Verify entity context (quality, lineage, compliance) | UC1 Step 2 |

**Request/Response Example** (UC1):
```json
POST /api/v1/dataspoke/verifier/context
{
  "entity_urn": "urn:li:dataset:(urn:li:dataPlatform:postgres,users.activity_logs,PROD)",
  "intent": "ml_training",
  "caller": "claude-sonnet-4.5"
}

Response:
{
  "status": "degraded",
  "quality_issues": [
    {
      "type": "volume_anomaly",
      "severity": "high",
      "message": "Daily row count dropped from 5M to 3.5M",
      "recommendation": "Use users.activity_events instead"
    }
  ],
  "alternative_entities": ["urn:li:dataset:(urn:li:dataPlatform:postgres,users.activity_events,PROD)"],
  "blocking_issues": ["ongoing_investigation"]
}
```

---

## DataHub API Reflection (`/api/v1/datahub`)

### Rationale

While DataSpoke uses DataHub's GraphQL API and Python SDK internally, exposing DataHub's REST API through DataSpoke provides:
1. **Single API gateway**: Clients call one endpoint instead of two
2. **Unified authentication**: DataSpoke handles DataHub auth/authorization
3. **Enhanced responses**: DataSpoke can enrich DataHub responses with quality scores, health metrics
4. **Rate limiting**: Centralized rate limiting and monitoring
5. **Backward compatibility**: If DataHub API changes, DataSpoke can maintain stable interface

### Proxy Strategy

**Approach**: Pass-through proxy with optional enrichment

```
/api/v1/datahub/{resource}/{identifier}?...
  ↓
  [DataSpoke Middleware: Auth, Rate Limiting, Logging]
  ↓
  [Forward to DataHub GMS]
  ↓
  [Optional: Enrich response with DataSpoke metadata]
  ↓
  [Return to client]
```

### Example Endpoints

```
# DataHub entity retrieval
GET /api/v1/datahub/dataset/{urn}                 → DataHub GMS: GET /entities/{urn}
GET /api/v1/datahub/dataset/{urn}/lineage         → DataHub GraphQL: lineage query

# DataHub search
GET /api/v1/datahub/search?query=...&entity=...   → DataHub GMS: /search

# DataHub usage statistics
GET /api/v1/datahub/dataset/{urn}/usage           → DataHub GMS: usage API
```

**Enrichment Example**:
```json
GET /api/v1/datahub/dataset/urn:li:dataset:...

Response (DataHub native + DataSpoke enrichment):
{
  // DataHub native fields
  "urn": "urn:li:dataset:...",
  "name": "orders.daily_summary",
  "schema": {...},

  // DataSpoke enrichment (optional, via X-Dataspoke-Enrich: true header)
  "_dataspoke": {
    "health_score": 82,
    "quality_alerts": 0,
    "last_quality_check": "2026-02-17T08:30:00Z",
    "verification_status": "healthy"
  }
}
```

---

## API Design Compliance

### URI Structure

All APIs follow `spec/API_DESIGN_PRINCIPLE_en.md`:

✅ **Resource nouns** (not verbs):
- `/config` not `/createConfig`
- `/run` not `/listRuns`

✅ **Singular form** (per project convention from git log):
- `/ingestion/config/{id}` not `/ingestion/configs/{id}`
- `/quality/rule/{id}` not `/quality/rules/{id}`

✅ **Classifier / Identifier hierarchy**:
- `/ingestion/config/{config_id}/run/{run_id}`
- `/quality/rule/{rule_id}/result/{result_id}`

✅ **Meta-classifiers**:
- `attr`: Configuration attributes (e.g., `/config/{id}/attr/schedule`)
- `method`: Business actions (e.g., `/config/{id}/method/trigger`, `/alert/{id}/method/acknowledge`)
- `event`: Lifecycle logs (e.g., `/run/{id}/event`, `/health-score/{urn}/event`)

✅ **Query parameters** for filtering/sorting:
- `/quality/result?dataset_urn=...&status=anomaly&sort=severity_desc`
- `/self-purifier/issue?owner=john@company.com&status=open&severity=critical`

### Request/Response Format

✅ **Content-Type**: `application/json`

✅ **UTF-8 encoding**

✅ **Field naming**: `snake_case` (Python/FastAPI convention)

✅ **Date/Time**: ISO 8601 format (`YYYY-MM-DDTHH:mm:ssZ`)

✅ **Content/Metadata separation**:
```json
{
  // Content: requested resource data
  "ingestion_configs": [
    {"config_id": "ing_001", "name": "oracle_warehouse", ...}
  ],

  // Metadata: pagination, system info
  "offset": 0,
  "limit": 20,
  "total_count": 45,
  "resp_time": "2026-02-17T10:30:00Z"
}
```

✅ **HTTP Status Codes**:
- 200 OK: Successful GET/PATCH
- 201 Created: Successful POST
- 204 No Content: Successful DELETE
- 400 Bad Request: Validation error
- 401 Unauthorized: Auth failure
- 403 Forbidden: Permission denied
- 404 Not Found: Resource not found
- 409 Conflict: Duplicate resource
- 422 Unprocessable Entity: Semantic error
- 500 Internal Server Error: Server failure

✅ **Error responses**:
```json
{
  "error_code": "INVALID_PARAMETER",
  "message": "The 'threshold' field must be between 0 and 1.",
  "details": {
    "field": "threshold",
    "provided_value": 1.5,
    "allowed_range": [0, 1]
  }
}
```

---

## Implementation Approach

### Phase 1: Specification (API-First)

**Timeline**: Week 1-2

**Deliverable**: `spec/API.md` — Full OpenAPI 3.0 YAML specification

**Tasks**:
1. Define all endpoint paths following the structure above
2. Define request/response schemas for each endpoint (Pydantic models as JSON Schema)
3. Add examples for each endpoint from USE_CASE scenarios
4. Document authentication requirements (JWT bearer token)
5. Define error codes and responses
6. Add markdown companion documentation explaining design rationale

**Why API-first**:
- AI agents can iterate on API design without running backend
- Frontend can start development with mock servers (Prism, MSW)
- Clear contract for team alignment

### Phase 2: FastAPI Implementation

**Timeline**: Week 3-6

**Structure** (per `spec/ARCHITECTURE.md`):
```
src/api/
├── routers/
│   ├── ingestion.py         # Ingestion endpoints
│   ├── quality.py           # Quality Control endpoints
│   ├── self_purifier.py     # Self-Purifier endpoints
│   ├── knowledge_base.py    # Knowledge Base endpoints
│   ├── verifier.py          # Context Verifier endpoints
│   ├── datahub_proxy.py     # DataHub reflection endpoints
│   └── health.py            # System health endpoints
├── schemas/
│   ├── ingestion.py         # Pydantic models for Ingestion
│   ├── quality.py           # Pydantic models for Quality Control
│   ├── self_purifier.py     # Pydantic models for Self-Purifier
│   ├── knowledge_base.py    # Pydantic models for Knowledge Base
│   └── common.py            # Shared models (pagination, errors)
├── middleware/
│   ├── auth.py              # JWT authentication
│   ├── rate_limit.py        # Rate limiting
│   └── logging.py           # Request/response logging
├── dependencies.py          # FastAPI dependency injection
└── main.py                  # FastAPI app initialization
```

**Tasks**:
1. Generate Pydantic schemas from OpenAPI spec (automated with datamodel-code-generator)
2. Implement routers (one per feature group)
3. Implement DataHub proxy middleware
4. Add authentication (JWT bearer tokens)
5. Add rate limiting (per-user, per-endpoint)
6. Add request validation (Pydantic)
7. Add response formatting (content/metadata separation)
8. Add OpenAPI auto-generation from FastAPI decorators
9. Verify generated OpenAPI matches `spec/API.md`

### Phase 3: Backend Service Integration

**Timeline**: Week 7-10

**Tasks**:
1. Connect API routers to backend services (`src/backend/`)
2. Implement business logic for each feature group
3. Integrate with DataHub SDK for read/write operations
4. Implement Temporal workflow triggers from API endpoints
5. Add WebSocket support for real-time notifications (alerts, run status)

### Phase 4: Testing & Documentation

**Timeline**: Week 11-12

**Tasks**:
1. Unit tests for all endpoints (pytest + httpx)
2. Integration tests with DataHub test instance
3. E2E tests for key use case flows (Playwright)
4. API documentation generation (Swagger UI, ReDoc)
5. Postman collection for manual testing
6. Performance testing (locust)

---

## Dependencies

### External Dependencies
- DataHub GMS instance (GraphQL API accessible at configured URL)
- Kafka brokers (for DataHub event consumption)
- PostgreSQL (operational data)
- Qdrant (vector DB)
- Temporal (workflow orchestration)
- Redis (caching)

### Internal Dependencies
- `src/backend/` services must be implemented before API integration
- Authentication system (JWT issuer/validator)
- DataHub SDK client wrappers (`src/shared/datahub_client.py`)

### Configuration
```yaml
# config/production.yaml
api:
  host: "0.0.0.0"
  port: 8000
  base_path: "/api/v1"
  cors_origins: ["https://dataspoke.company.com"]

datahub:
  gms_url: "https://datahub.company.com"
  kafka_brokers: "datahub-kafka-1:9092,datahub-kafka-2:9092"

auth:
  jwt_secret_key: "${JWT_SECRET_KEY}"  # From env or secret manager
  jwt_algorithm: "HS256"
  access_token_expire_minutes: 60

rate_limit:
  default_per_minute: 60
  burst: 100
```

---

## Success Criteria

### Functional Requirements
✅ All four feature group APIs implemented per MANIFESTO scope
✅ DataHub proxy endpoints operational
✅ All USE_CASE scenarios executable via API calls
✅ Request/response format compliant with API_DESIGN_PRINCIPLE
✅ Error handling covers all edge cases with clear messages

### Non-Functional Requirements
✅ API response time p95 < 500ms (excluding long-running operations)
✅ 100% OpenAPI 3.0 specification coverage
✅ 90%+ unit test coverage for API routers
✅ Authentication required on all non-health endpoints
✅ Rate limiting enforced (60 req/min default)

### Documentation Requirements
✅ Complete OpenAPI spec in `spec/API.md`
✅ Swagger UI accessible at `/docs`
✅ ReDoc accessible at `/redoc`
✅ Postman collection with examples
✅ Integration guide for AI agents

---

## Open Questions

**Q1**: Should DataHub proxy endpoints require separate authorization from DataHub GMS, or trust DataSpoke's auth?
- **Proposed**: Trust DataSpoke auth; enforce permissions via middleware that maps DataSpoke users to DataHub permissions

**Q2**: What level of enrichment should DataHub proxy endpoints provide by default?
- **Proposed**: Opt-in enrichment via `X-Dataspoke-Enrich: true` header to avoid performance overhead

**Q3**: Should we implement GraphQL endpoint alongside REST for complex queries?
- **Proposed**: Start with REST only; add GraphQL in Phase 2 if frontend needs justify it

**Q4**: How to handle long-running operations (ingestion runs, quality scans)?
- **Proposed**: Synchronous POST returns 202 Accepted with `run_id`; client polls GET `/run/{id}` for status

**Q5**: Should API versioning be in URL (`/v1/`) or header (`X-API-Version: 1`)?
- **Proposed**: URL-based versioning for simplicity and cache-ability

---

## Next Steps

1. ✅ **Approve this plan** — Review with team, incorporate feedback
2. **Write `spec/API.md`** — Full OpenAPI 3.0 specification with examples from USE_CASE scenarios
3. **Set up FastAPI skeleton** — Initialize `src/api/` structure with routers and schemas
4. **Implement Phase 1 endpoints** — Start with Knowledge Base (simplest: stateless search) and Verifier (critical for AI agents)
5. **Iterate** — Add remaining feature groups incrementally

---

## References

- [MANIFESTO Feature Set](../MANIFESTO_en.md#2-feature-set)
- [USE_CASE Scenarios](../USE_CASE.md)
- [API Design Principle](../API_DESIGN_PRINCIPLE_en.md)
- [Architecture Overview](../ARCHITECTURE.md)
- [DataHub REST API](https://datahubproject.io/docs/api/restli/restli-overview)
- [DataHub GraphQL API](https://datahubproject.io/docs/api/graphql/overview)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
