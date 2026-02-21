# DataSpoke: System Architecture

> **Document Status**: Architecture Specification v0.3
> This document defines the high-level architecture, technology choices, and design decisions for the DataSpoke system.
> Aligned with MANIFESTO v2 (user-group-based feature taxonomy).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Principles](#core-principles)
3. [System Components](#system-components)
4. [Feature Architecture by User Group](#feature-architecture-by-user-group)
5. [Technology Stack](#technology-stack)
6. [Data Flow & Integration](#data-flow--integration)
7. [Deployment Architecture](#deployment-architecture)
8. [Repository Structure](#repository-structure)
9. [Design Decisions & Rationale](#design-decisions--rationale)

---

## Architecture Overview

### Hub-and-Spoke Model

DataSpoke implements a **loosely coupled architecture** with DataHub, maintaining separation of concerns while enabling seamless integration. DataHub is the Hub (metadata SSOT); each user-group-specific extension is a Spoke.

```
┌───────────────────────────────────────────────┐
│                 DataSpoke UI                  │
└───────────────────────┬───────────────────────┘
                        │
┌───────────────────────▼───────────────────────┐
│                DataSpoke API                  │
│         /api/v1/spoke/[de|da|dg]/...          │
└───────────┬───────────────────────┬───────────┘
            │                       │
┌───────────▼───────────┐ ┌────────▼────────────┐
│                       │ │      DataSpoke      │
│       DataHub         │ │  Backend / Pipeline │
│    (metadata SSOT)    │ │                     │
└───────────────────────┘ └─────────────────────┘
```

### DataHub Deployment Model

**Assumption**: DataHub is deployed and managed **separately** from DataSpoke.

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   DataSpoke Stack       │         │   DataHub Instance      │
│   (This Project)        │◄────────┤   (External)            │
│                         │  API    │                         │
│   - UI                  │  Events │   - GMS                 │
│   - API                 │  SDK    │   - Frontend (optional) │
│   - Backend / Pipeline  │         │   - Kafka               │
│   - Qdrant              │         │   - MySQL/Postgres      │
│   - Temporal            │         │   - Elasticsearch       │
└─────────────────────────┘         └─────────────────────────┘
```

**Rationale**:
1. DataSpoke is a **sidecar extension**, not a DataHub replacement
2. Enterprises typically have existing DataHub installations
3. Loose coupling enables independent deployment and evolution
4. Clear separation of responsibilities and ownership

**Configuration**:
```yaml
# config/production.yaml
datahub:
  gms_url: "https://datahub.company.com"
  kafka_brokers: "datahub-kafka-1:9092,datahub-kafka-2:9092"
```

**Development / Testing**:
For local development and CI/CD testing, DataHub is provisioned via Kubernetes + Helm using the scripts in `dev_env/`:
```bash
# Install DataHub + DataSpoke locally (first run: 5–10 min)
cd dev_env && ./install.sh

# Settings (cluster name, namespaces, chart versions) live in dev_env/.env
```

**Note**: The bundled dev environment is **NOT supported for production** deployments.

### Key Architectural Tenets

1. **DataHub-backed SSOT**: DataHub stores metadata; DataSpoke extends without modifying core
2. **API Convention Compliance**: Unified API spec across all user groups (`spec/API_DESIGN_PRINCIPLE_en.md`)
3. **User-Group Routing**: API endpoints segmented by DE/DA/DG for clear ownership
4. **API-First**: Standalone OpenAPI specs in `api/` enable parallel frontend/backend development
5. **Cloud-Native**: Kubernetes-ready with containerized deployments

---

## Core Principles

### 1. DataHub-backed Backend (SSOT)

DataHub is the **mandatory backend** for metadata persistence. DataSpoke never duplicates metadata storage — it reads from and writes to DataHub, adding a computational/analysis layer on top.

**Read Operations**:
- DataHub GraphQL API for metadata queries
- Kafka consumer for real-time change events (MCE/MAE)

**Write Operations**:
- DataHub Python SDK (`acryl-datahub`) via `DatahubRestEmitter`
- Custom aspects for DataSpoke-specific metadata

**Boundary**:
- DataHub = Source of truth for metadata persistence
- DataSpoke = Computational layer for analysis, validation, and enrichment

### 2. API Convention Compliance

A unified API specification is applied across all user groups to maintain cross-system consistency. All REST APIs conform to `spec/API_DESIGN_PRINCIPLE_en.md`, covering:

- URI structure and naming conventions
- Request/response format standardization
- Content/metadata separation in responses
- Meta-classifiers (`attrs`, `methods`, `events`)
- Query parameter conventions

### 3. API-First Design

API documentation exists as **standalone artifacts** in `api/`:
- Enable AI agents to iterate on API specs independently of backend
- Allow frontend development to start before backend is implemented
- Support API mocking and contract testing without running services
- Format: OpenAPI 3.0 specification + human-readable markdown

### 4. Layer Separation

The four system components (UI, API, Backend/Pipeline, DataHub) are strictly separated:
- Independent scaling (UI ≠ Backend resources)
- Technology flexibility (swap Next.js for Vue later)
- Security boundaries (UI never accesses DB directly)
- Team autonomy (frontend/backend teams work independently)

---

## System Components

DataSpoke consists of **four major components**, as defined in the MANIFESTO.

### 1. DataSpoke UI

**Technology**: Next.js (TypeScript)

Provides a portal-style interface with user-group-specific entry points (DE, DA, DG).

```
┌─────────────────────────────────────────────┐
│  Data Hub & Spokes                          │
│                                             │
│        (DE)                                 │
│           \                                 │
│            \         (DA)                   │
│             \       /                       │
│            [Hub]---/                        │
│              |                              │
│              |                              │
│             (DG)                            │
│                                             │
└─────────────────────────────────────────────┘
                 UI Main Page
```

**Key Characteristics**:
- Server-side rendering (SSR) for initial load performance
- Chart visualizations (Highcharts or Recharts)
- Real-time updates via WebSocket connections
- Responsive design for mobile/tablet access

**Source Layout**:
```
src/frontend/
├── app/            # Next.js pages per user group (de, da, dg)
├── components/     # Reusable UI components (charts, tables, common)
├── lib/            # API client, state management, custom hooks
└── styles/         # Global styles and themes
```

### 2. DataSpoke API

**Technology**: FastAPI (Python 3.11+)

Features a hierarchical URI structure separated by user group:

```
/api/v1/spoke/de/...   → Data Engineering endpoints
/api/v1/spoke/da/...   → Data Analysis endpoints
/api/v1/spoke/dg/...   → Data Governance endpoints
```

**API Types**:
- **RESTful API**: CRUD operations, synchronous queries
- **WebSocket**: Real-time notifications and streaming data

**Source Layout**:
```
src/api/
├── routers/        # One router per user group + system health
├── schemas/        # Pydantic request/response models
├── middleware/      # Auth, logging, rate limiting
└── main.py         # FastAPI application entry
```

### 3. DataSpoke Backend / Pipeline

**Technology**: Python 3.11+ (FastAPI framework), Temporal for orchestration

Handles core logic including ingestion, quality validation, documentation generation, semantic search, and metrics computation. Internal service decomposition is defined in `spec/feature/` specs per user group.

**Key Capabilities**:
- Custom ingestion from legacy and non-standard sources
- ML-based time series anomaly detection (Prophet, Isolation Forest)
- LLM integration for metadata extraction and documentation suggestions
- Embedding generation and vector search (Qdrant)
- Bidirectional communication with DataHub via `acryl-datahub` SDK

**Source Layout**:
```
src/backend/        # Feature service implementations
src/workflows/      # Temporal workflow definitions
src/shared/         # DataHub client wrappers, shared models
```

### 4. DataHub (External)

DataHub is deployed and managed separately. DataSpoke communicates with it through:

- **GraphQL API** (`datahub-gms`): Metadata queries
- **Kafka** (`MCE/MAE`): Real-time change event streams
- **Python SDK** (`acryl-datahub`): Metadata writes via `DatahubRestEmitter`

### Supporting Infrastructure

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Vector DB | Qdrant | Semantic search over metadata embeddings |
| Message Broker | Kafka | Event streaming (shared with DataHub) |
| Orchestration | Temporal | Durable workflow execution |
| Operational DB | PostgreSQL | DataSpoke-specific operational data |
| Cache | Redis | API response caching, rate limiting, sessions |

---

## Feature Architecture by User Group

This section maps the MANIFESTO's feature taxonomy to architectural concerns. Detailed designs live in `spec/feature/` per feature.

### Data Engineering (DE) Group

| Feature | Description | Key Infrastructure |
|---------|-------------|-------------------|
| **Deep Technical Spec Ingestion** | Collects platform-specific technical metadata (compression formats, Kafka replication levels, etc.) | Temporal workflows, DataHub SDK |
| **Online Data Validator** | Time-series monitoring and validation API; supports point-in-time and dry-run validation | ML models (Prophet, Isolation Forest), PostgreSQL |
| **Automated Doc Suggestions** | Source-code-based docs, similar-table differentiation, taxonomy/ontology proposals | LLM integration, Qdrant |

### Data Analysis (DA) Group

| Feature | Description | Key Infrastructure |
|---------|-------------|-------------------|
| **Natural Language Search** | Explore tables using natural language queries | Qdrant (vector similarity), LLM embeddings |
| **Text-to-SQL Optimized Metadata** | Curated metadata focused on data content for accurate SQL generation | DataHub GraphQL, Qdrant |
| **Online Data Validator** | Shared with DE group — same API, same backend | (shared with DE) |

### Data Governance (DG) Group

| Feature | Description | Key Infrastructure |
|---------|-------------|-------------------|
| **Enterprise Metrics Dashboard** | Time-series dashboards: dataset counts, total volume, availability ratios | PostgreSQL, Temporal (scheduled collection) |
| **Multi-Perspective Data Overview** | Taxonomy/ontology graph visualization, Medallion Architecture overview | Qdrant, DataHub GraphQL |

### Cross-Cutting Concerns

| Concern | Approach |
|---------|---------|
| **Kafka Event Consumers** | Vector DB sync on metadata changes, quality check triggers, alert notifications |
| **Temporal Workflows** | Scheduled ingestion, anomaly detection, embedding maintenance, metrics collection |
| **PostgreSQL Tables** | Ingestion configs/runs, quality rules/results, health scores, user preferences |

---

## Technology Stack

### Summary Table

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Frontend** | Next.js + TypeScript | SSR, React ecosystem, type safety |
| **API** | FastAPI | High performance, async support, auto docs |
| **Backend** | Python 3.11+ | Rich data libraries, ML ecosystem |
| **Vector DB** | Qdrant | High performance, self-hostable, simple deployment |
| **Message Broker** | Kafka | Standard for DataHub integration |
| **Orchestration** | Temporal | Workflow durability, developer experience |
| **Operational DB** | PostgreSQL | ACID guarantees, JSON support |
| **Cache** | Redis | Industry standard, versatile |
| **DataHub SDK** | acryl-datahub | Official Python SDK |
| **Charts** | Highcharts / Recharts | Rich visualization library |
| **Container Runtime** | Docker | Standard containerization |
| **Orchestrator** | Kubernetes | Cloud-native deployment |
| **IaC** | Helm Charts | K8s package management |

### Development Stack

| Purpose | Technology |
|---------|-----------|
| **API Testing** | pytest, httpx |
| **Frontend Testing** | Jest, React Testing Library |
| **E2E Testing** | Playwright |
| **Linting** | ruff (Python), ESLint (TS) |
| **Formatting** | black (Python), Prettier (TS) |
| **Type Checking** | mypy (Python), TypeScript |
| **CI/CD** | GitHub Actions |
| **Documentation** | MkDocs (Material theme) |

---

## Data Flow & Integration

### 1. Metadata Synchronization Flow

```
┌─────────────────────────────────────────────────────────────┐
│ External Data Sources                                       │
│ (GitHub, SQL Logs, Slack, Custom APIs)                      │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│ DataSpoke Backend: Ingestion (DE)                          │
│                                                            │
│  1. Extract data from sources                              │
│  2. Transform to DataHub metadata format                   │
│  3. Enrich with LLM (if applicable)                        │
│  4. Validate against schemas                               │
└────────────┬───────────────────────────────────────────────┘
             │ DataHub Python SDK
             ▼
┌────────────────────────────────────────────────────────────┐
│ DataHub GMS (Hub)                                          │
│  - Persist metadata                                        │
│  - Emit MetadataChangeEvent (MCE)                          │
└────────────┬───────────────────────────────────────────────┘
             │ Kafka: MCE/MAE
             ▼
┌────────────────────────────────────────────────────────────┐
│ DataSpoke Backend: Event Consumers                         │
│                                                            │
│  ┌───────────────────┐   ┌───────────────────┐             │
│  │ Vector DB Sync    │   │ Validator Trigger │             │
│  │ (DA: NL Search)   │   │ (DE: Quality)     │             │
│  └───────────────────┘   └───────────────────┘             │
└────────────────────────────────────────────────────────────┘
```

### 2. Semantic Search Flow (DA: Natural Language Search)

```
User Query: "Find PII tables used by marketing"
      │
      ▼
┌─────────────────────────────────────────┐
│ UI: Search Interface                    │
└─────────────┬───────────────────────────┘
              │ REST: /api/v1/spoke/da/search
              ▼
┌─────────────────────────────────────────┐
│ API → Backend: Search Service           │
│  1. Generate query embedding (LLM)      │
│  2. Vector similarity search (Qdrant)   │
│  3. Apply filters (tags, ownership)     │
│  4. Enrich with DataHub metadata        │
│  5. Rank and score results              │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Results with context + lineage          │
└─────────────────────────────────────────┘
```

### 3. Online Validation Flow (DE/DA: Online Data Validator)

```
AI Agent or User: data to validate
      │
      ▼
┌─────────────────────────────────────────┐
│ API: /api/v1/spoke/de/validator         │
│  - Validate request schema              │
│  - Authenticate caller                  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Backend: Validator Service              │
│  1. Retrieve entity context (DataHub    │
│     GraphQL + vector search)            │
│  2. Check data quality status           │
│  3. Validate schema / lineage           │
│  4. Return validation result +          │
│     recommendations                     │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Validation Result:                      │
│   status, issues, recommendations,      │
│   alternative_entities                  │
└─────────────────────────────────────────┘
```

### 4. DataHub Integration Patterns

#### Pattern A: Read-Only Queries
```python
from datahub.ingestion.graph.client import DatahubClientConfig, DataHubGraph

graph = DataHubGraph(DatahubClientConfig(server="http://datahub-gms:8080"))
dataset = graph.get_dataset(urn="urn:li:dataset:...")
```

#### Pattern B: Write Metadata
```python
from datahub.emitter.rest_emitter import DatahubRestEmitter

emitter = DatahubRestEmitter("http://datahub-gms:8080")
emitter.emit_mcp(metadata_change_proposal)
```

#### Pattern C: Event Subscription
```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'MetadataChangeEvent_v1',
    bootstrap_servers='datahub-broker:9092'
)
for message in consumer:
    handle_metadata_change(message.value)
```

---

## Deployment Architecture

### Kubernetes Architecture

**Assumption**: DataHub exists in a separate namespace or cluster.

```yaml
# DataSpoke namespace only
Namespace: dataspoke

Deployments:
  - dataspoke-frontend (Next.js)
    - Replicas: 3
    - Resources: 512Mi memory, 0.5 CPU
    - Ingress: /app/*

  - dataspoke-api (FastAPI)
    - Replicas: 5
    - Resources: 1Gi memory, 1 CPU
    - Ingress: /api/*

  - dataspoke-workers (Backend workers)
    - Replicas: 3
    - Resources: 2Gi memory, 1 CPU

  - temporal-server
    - Replicas: 2
    - Resources: 2Gi memory, 1 CPU

  - qdrant
    - StatefulSet
    - Persistent Volume: 100Gi
    - Resources: 4Gi memory, 2 CPU

  - postgresql (DataSpoke operational DB)
    - StatefulSet
    - Persistent Volume: 50Gi
    - Resources: 2Gi memory, 1 CPU

  - redis
    - Deployment
    - Replicas: 2 (master-replica)
    - Resources: 512Mi memory, 0.5 CPU

Services:
  - dataspoke-frontend-svc (ClusterIP)
  - dataspoke-api-svc (ClusterIP)
  - qdrant-svc (ClusterIP)
  - postgresql-svc (ClusterIP)
  - redis-svc (ClusterIP)

Ingress:
  - dataspoke.company.com → Frontend
  - api.dataspoke.company.com → API

# External DataHub Services (running separately)
External Dependencies:
  - datahub-gms.datahub.svc.cluster.local:8080 (GraphQL)
  - datahub-broker.datahub.svc.cluster.local:9092 (Kafka)

# ConfigMap for DataHub connection
ConfigMap:
  dataspoke-config:
    DATAHUB_GMS_URL: "http://datahub-gms.datahub.svc.cluster.local:8080"
    DATAHUB_KAFKA_BROKERS: "datahub-broker.datahub.svc.cluster.local:9092"
    DATAHUB_KAFKA_CONSUMER_GROUP: "dataspoke-consumers"
```

**Resource Estimate**: ~20 GB memory, ~10 CPU cores

**Network Requirements**:
- DataSpoke namespace must have network access to DataHub namespace
- Configure NetworkPolicy to allow traffic between namespaces if using strict policies

### Cloud Deployment Options

#### Option 1: AWS EKS
```
- EKS cluster for Kubernetes
- RDS for PostgreSQL
- ElastiCache for Redis
- MSK for Kafka (managed)
- S3 for backups and large files
- CloudWatch for monitoring
```

#### Option 2: Self-Hosted K8s
```
- On-premise Kubernetes cluster
- Self-managed databases
- Local persistent volumes
- Prometheus + Grafana for monitoring
```

---

## Repository Structure

```
dataspoke-baseline/
├── api/                # Standalone OpenAPI 3.0 specs (API-first design)
├── src/
│   ├── frontend/       # Next.js application (user-group pages: de, da, dg)
│   ├── api/            # FastAPI application (routers per user group, schemas, middleware)
│   ├── backend/        # Feature service implementations (detail in spec/feature/)
│   ├── workflows/      # Temporal workflow definitions
│   └── shared/         # DataHub client wrappers, shared models
├── helm-charts/        # Kubernetes deployment manifests
├── spec/               # Architecture specs and planning documents
│   ├── feature/        # Common/cross-cutting feature specs
│   ├── feature/spoke/  # User-group-specific feature specs (DE/DA/DG)
│   └── plan/           # Chronological decision plans/logs
├── dev_env/            # Local Kubernetes dev environment scripts
├── ref/                # External source code for AI reference (version-locked to dev_env; git-ignored)
│   └── github/datahub/ # DataHub OSS source (v1.4.0) — entity models, GraphQL, SDK, ingestion
├── tests/              # Unit, integration, and e2e test suites
├── migrations/         # Alembic database migrations
└── config/             # Environment-specific configuration files
```

---

## Design Decisions & Rationale

### 1. Why FastAPI over Flask/Django?

- Async/await support for high concurrency
- Automatic OpenAPI documentation generation
- Pydantic for request/response validation
- High performance (comparable to Node.js)
- Type hints for better IDE support

### 2. Why Next.js over Create React App?

- Server-side rendering improves initial load
- File-based routing simplifies structure
- Built-in optimization (images, fonts)
- Large ecosystem and community

### 3. Why Qdrant over Pinecone/Weaviate?

- Open-source and self-hostable
- High performance (Rust-based)
- Simple deployment (single binary)
- Cost-effective for on-premise

**Consider Weaviate if**: multi-tenancy features, complex schema relationships, or GraphQL-native interface are needed.

### 4. Why Temporal over Airflow?

- Better for long-running workflows
- Built-in retry and error handling
- Easier testing (workflow-as-code)
- Strong consistency guarantees

**Use Airflow if**: existing Airflow infrastructure exists or batch-oriented DAG editing is required.

### 5. Why Standalone API Documentation?

- AI agents can iterate on API design without backend
- Frontend development starts before backend implementation
- API mocking and contract testing without running services
- Documentation-driven development

### 6. Why PostgreSQL over MongoDB?

- ACID guarantees for critical operational data
- JSON support (JSONB) for flexibility
- Mature ecosystem and tooling
- Better for structured relational data (ingestion configs, quality results)

---

## Appendix

### Useful Commands

```bash
# Reference materials (AI context)
bash ref/setup.sh             # Download all reference materials (DataHub source)
bash ref/setup.sh --clean     # Remove all downloaded reference materials

# Local development (Kubernetes + Helm)
cd dev_env && ./install.sh    # Start all services locally
cd dev_env && ./uninstall.sh  # Stop all services
make test                     # Run all tests
make lint                     # Run linters

# Docker builds
make build-frontend       # Build frontend image
make build-api            # Build API image
make build-backend        # Build backend image

# Kubernetes deployment
helm install dataspoke ./helm-charts/dataspoke
helm upgrade dataspoke ./helm-charts/dataspoke
kubectl get pods -n dataspoke

# Database migrations
alembic upgrade head      # Apply migrations
alembic revision --autogenerate -m "message"
```

### Further Reading

- [DataHub Architecture](https://datahubproject.io/docs/architecture/architecture/)
- [Temporal Documentation](https://docs.temporal.io/)
- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/)
- [Next.js Documentation](https://nextjs.org/docs)
