# Data Spoke: System Architecture

> **Document Status**: Architecture Specification v0.1
> This document defines the high-level architecture, technology choices, and design decisions for the Data Spoke system.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
   - [Hub-and-Spoke Model](#hub-and-spoke-model)
   - [DataHub Deployment Model](#datahub-deployment-model)
2. [Core Principles](#core-principles)
3. [System Components](#system-components)
4. [Technology Stack](#technology-stack)
5. [Data Flow & Integration](#data-flow--integration)
6. [Deployment Architecture](#deployment-architecture)
7. [Repository Structure](#repository-structure)
8. [Design Decisions & Rationale](#design-decisions--rationale)

---

## Architecture Overview

### Hub-and-Spoke Model

Data Spoke implements a **loosely coupled architecture** with DataHub, maintaining separation of concerns while enabling seamless integration.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Data Spoke System                         │
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Frontend   │◄───┤   API Layer  │◄───┤   Backend    │      │
│  │   (Next.js)  │    │  (FastAPI)   │    │  (Python)    │      │
│  └──────────────┘    └──────────────┘    └──────┬───────┘      │
│                                                    │               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────▼───────┐      │
│  │  Vector DB   │    │ Message Queue│    │ Orchestrator │      │
│  │   (Qdrant)   │    │   (Kafka)    │    │  (Temporal)  │      │
│  └──────────────┘    └──────┬───────┘    └──────────────┘      │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────┘
                               │
                     ┌─────────▼──────────┐
                     │                     │
                     │   DataHub (Hub)     │
                     │                     │
                     │  ┌──────────────┐  │
                     │  │     GMS      │  │
                     │  │  (GraphQL)   │  │
                     │  └──────────────┘  │
                     │  ┌──────────────┐  │
                     │  │  MCE/MAE     │  │
                     │  │  (Kafka)     │  │
                     │  └──────────────┘  │
                     │  ┌──────────────┐  │
                     │  │   Metadata   │  │
                     │  │   Storage    │  │
                     │  └──────────────┘  │
                     └─────────────────────┘
```

### DataHub Deployment Model

**Assumption**: DataHub is deployed and managed **separately** from Data Spoke

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   Data Spoke Stack      │         │   DataHub Instance      │
│   (This Project)        │◄────────┤   (External)            │
│                         │  API    │                         │
│   - Frontend            │  Events │   - GMS                 │
│   - API                 │  SDK    │   - Frontend (optional) │
│   - Backend             │         │   - Kafka               │
│   - Qdrant              │         │   - MySQL/Postgres      │
│   - Temporal            │         │   - Elasticsearch       │
└─────────────────────────┘         └─────────────────────────┘
```

**Rationale**:
1. Data Spoke is a **sidecar extension**, not a DataHub replacement
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

**Development/Testing Only**:
For local development and CI/CD testing, a bundled DataHub can be spun up via `docker-compose`:
```yaml
# docker-compose.dev.yml
services:
  datahub-gms:
    image: acryldata/datahub-gms:latest
    # ... minimal config for testing

  data-spoke-api:
    build: ./src/api
    environment:
      DATAHUB_GMS_URL: "http://datahub-gms:8080"
```

**Note**: Bundled DataHub is **NOT supported for production** deployments.

### Key Architectural Tenets

1. **Separation of Concerns**: Frontend, API, and Backend are strictly separated
2. **Loose Coupling**: DataHub acts as SSOT; Data Spoke extends without modifying core
3. **Event-Driven**: Real-time synchronization via Kafka message streams
4. **API-First**: Standalone API documentation facilitates AI agent integration
5. **Cloud-Native**: Kubernetes-ready with containerized deployments

---

## Core Principles

### 1. Strict Layer Separation

```
┌─────────────────────────────────────────────┐
│ Presentation Layer (Frontend)                │
│ - Next.js + TypeScript                       │
│ - React Components                           │
│ - Client-side state management               │
└─────────────────┬───────────────────────────┘
                  │ HTTP/WebSocket
┌─────────────────▼───────────────────────────┐
│ API Gateway Layer                            │
│ - RESTful API + GraphQL                      │
│ - Authentication & Authorization             │
│ - Request validation & rate limiting         │
└─────────────────┬───────────────────────────┘
                  │ Internal RPC
┌─────────────────▼───────────────────────────┐
│ Business Logic Layer (Backend)               │
│ - FastAPI application                        │
│ - Service layer (ingestion, quality, search) │
│ - ML models (Prophet, Isolation Forest)      │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│ Data & Integration Layer                     │
│ - Vector DB, Message Queue, Orchestrator     │
│ - DataHub SDK integration                    │
│ - External system connectors                 │
└─────────────────────────────────────────────┘
```

### 2. API-First Design

API documentation exists as **standalone artifacts** in a separate directory:
- **Purpose 1**: Enable AI agents to iterate on API specifications independently
- **Purpose 2**: Allow API documentation and testing without running backend
- **Format**: OpenAPI 3.0 specification + human-readable markdown

### 3. DataHub Integration Strategy

**Read Operations**:
- DataHub GraphQL API for metadata queries
- Kafka consumer for real-time change events (MCE/MAE)

**Write Operations**:
- DataHub Python SDK (`acryl-datahub`) for metadata ingestion
- Custom aspects for Data Spoke-specific metadata

**Boundary**:
- DataHub = Source of truth for metadata persistence
- Data Spoke = Computational layer for analysis, validation, and enrichment

---

## System Components

### Frontend Layer

**Technology**: Next.js (TypeScript)

**Components**:
```
src/frontend/
├── app/                    # Next.js app directory
│   ├── dashboard/          # Main dashboard views
│   ├── lineage/            # Lineage visualization
│   ├── quality/            # Quality monitoring UI
│   └── search/             # Semantic search interface
├── components/             # Reusable UI components
│   ├── charts/             # Highcharts wrappers
│   ├── tables/             # Data grid components
│   └── common/             # Shared UI elements
├── lib/                    # Client-side utilities
│   ├── api-client.ts       # API communication layer
│   ├── state/              # State management (Zustand/Redux)
│   └── hooks/              # Custom React hooks
└── styles/                 # Global styles and themes
```

**Key Features**:
- Server-side rendering (SSR) for initial load performance
- Chart visualizations using Highcharts or Recharts
- Real-time updates via WebSocket connections
- Responsive design for mobile/tablet access

### API Layer

**Technology**: FastAPI (Python 3.11+)

**Structure**:
```
src/api/
├── routers/                # API endpoint definitions
│   ├── ingestion.py        # Ingestion management endpoints
│   ├── quality.py          # Quality monitoring endpoints
│   ├── search.py           # Semantic search endpoints
│   └── health.py           # Health check & system status
├── schemas/                # Pydantic models
│   ├── requests/           # Request validation schemas
│   └── responses/          # Response serialization schemas
├── middleware/             # Cross-cutting concerns
│   ├── auth.py             # Authentication/authorization
│   ├── logging.py          # Request/response logging
│   └── rate_limit.py       # Rate limiting
├── dependencies.py         # Dependency injection
└── main.py                 # FastAPI application entry
```

**API Types**:
- **RESTful API**: CRUD operations, synchronous queries
- **GraphQL** (optional): Complex nested queries for frontend flexibility
- **WebSocket**: Real-time notifications and streaming data

### Backend Layer

**Technology**: Python 3.11+ (FastAPI framework)

**Core Services**:

```
src/backend/
├── services/
│   ├── ingestion/          # Custom data source synchronization
│   │   ├── connectors/     # Source-specific connectors
│   │   ├── schedulers/     # Ingestion scheduling logic
│   │   └── transformers/   # Data transformation pipelines
│   ├── quality/            # Data quality analysis
│   │   ├── models/         # ML models (Prophet, IF, etc.)
│   │   ├── rules/          # Rule-based validation
│   │   └── anomaly.py      # Anomaly detection engine
│   ├── search/             # Semantic search service
│   │   ├── embeddings/     # Text embedding generation
│   │   ├── indexing/       # Vector DB indexing
│   │   └── ranking.py      # Search result ranking
│   └── metadata/           # Metadata health monitoring
│       ├── auditor.py      # Documentation auditing
│       ├── scoring.py      # Health score calculation
│       └── alerts.py       # Alerting and notifications
├── models/                 # Domain models
├── repositories/           # Data access layer
├── utils/                  # Shared utilities
└── config.py               # Configuration management
```

**Key Capabilities**:
- **Custom Connectors**: REST API-based sync for non-standard sources
- **ML Models**: Time series analysis, anomaly detection
- **LLM Integration**: Process unstructured data (Slack, docs) for metadata extraction
- **DataHub SDK**: Bidirectional communication with DataHub GMS

### Data & Storage Layer

#### 1. Vector Database (Qdrant)

**Purpose**: Semantic search over metadata

**Schema**:
```python
{
  "collection": "metadata_embeddings",
  "vector_size": 1536,  # OpenAI ada-002 or similar
  "distance": "Cosine",
  "payload": {
    "entity_urn": "urn:li:dataset:...",
    "entity_type": "dataset",
    "name": "...",
    "description": "...",
    "tags": [...],
    "owners": [...],
    "quality_score": 0.95,
    "last_updated": "2024-02-09T..."
  }
}
```

**Alternative**: Weaviate (if schema flexibility and multi-tenant support needed)

#### 2. Message Broker (Kafka)

**Topics**:
- `datahub.MetadataChangeEvent_v1`: DataHub metadata changes
- `datahub.MetadataAuditEvent_v1`: DataHub audit events
- `dataspoke.quality.alerts`: Quality issue notifications
- `dataspoke.ingestion.status`: Ingestion job status updates

**Consumer Groups**:
- `dataspoke-vector-sync`: Updates vector DB on metadata changes
- `dataspoke-quality-monitor`: Triggers quality checks on data updates
- `dataspoke-notification`: Sends alerts to users

#### 3. Operational Database (PostgreSQL)

**Purpose**: Store Data Spoke-specific operational data

**Tables**:
- `ingestion_configs`: Custom ingestion configurations
- `ingestion_runs`: Execution history and status
- `quality_rules`: Custom quality rule definitions
- `quality_results`: Quality check results over time
- `health_scores`: Metadata health scores by entity
- `user_preferences`: User settings and notifications

#### 4. Cache Layer (Redis)

**Purpose**: Performance optimization

**Use Cases**:
- API response caching (5-60 min TTL)
- Rate limiting state
- Session management
- Real-time notification queue

### Orchestration Layer

**Technology**: Temporal (preferred) or Airflow (alternative)

**Workflows**:
```
workflows/
├── ingestion/
│   ├── scheduled_sync.py      # Periodic DataHub sync
│   ├── custom_source_sync.py  # Custom connector execution
│   └── backfill.py             # Historical data backfill
├── quality/
│   ├── anomaly_detection.py   # Run ML models on datasets
│   ├── rule_validation.py     # Execute quality rules
│   └── health_scoring.py      # Calculate health scores
├── search/
│   ├── embedding_generation.py # Generate embeddings
│   └── index_maintenance.py    # Vector DB maintenance
└── notifications/
    └── digest_sender.py        # Send daily/weekly digests
```

**Why Temporal over Airflow**:
- Better support for long-running workflows
- Built-in retry and error handling
- Easier testing and local development
- Strong consistency guarantees

**Airflow Alternative**: Use if existing Airflow infrastructure exists

---

## Technology Stack

### Summary Table

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Frontend** | Next.js + TypeScript | SSR, React ecosystem, type safety |
| **API** | FastAPI | High performance, async support, auto docs |
| **Backend** | Python 3.11+ | Rich data libraries, ML ecosystem |
| **Vector DB** | Qdrant | High performance, simple deployment |
| **Message Broker** | Kafka | Standard for DataHub integration |
| **Orchestration** | Temporal | Workflow durability, developer experience |
| **Operational DB** | PostgreSQL | Robust, open-source, JSON support |
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
│ External Data Sources                                        │
│ (GitHub, SQL Logs, Slack, Custom APIs)                      │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│ Data Spoke: Custom Ingestion Service                        │
│                                                              │
│  1. Extract data from sources                               │
│  2. Transform to DataHub metadata format                    │
│  3. Enrich with LLM (if needed)                             │
│  4. Validate against schemas                                │
└────────────┬───────────────────────────────────────────────┘
             │ DataHub Python SDK
             ▼
┌────────────────────────────────────────────────────────────┐
│ DataHub GMS (Hub)                                           │
│  - Persist metadata                                         │
│  - Emit MetadataChangeEvent (MCE)                          │
└────────────┬───────────────────────────────────────────────┘
             │ Kafka: MCE/MAE
             ▼
┌────────────────────────────────────────────────────────────┐
│ Data Spoke: Event Consumers                                 │
│                                                              │
│  ┌─────────────────┐   ┌─────────────────┐                │
│  │ Vector DB Sync  │   │ Quality Monitor │                │
│  │ - Update vectors│   │ - Trigger checks│                │
│  └─────────────────┘   └─────────────────┘                │
└────────────────────────────────────────────────────────────┘
```

### 2. Semantic Search Flow

```
User Query: "Find PII tables used by marketing"
      │
      ▼
┌─────────────────────────────────────────┐
│ Frontend: Search Interface               │
└─────────────┬───────────────────────────┘
              │ REST API
              ▼
┌─────────────────────────────────────────┐
│ API Layer: /search/semantic             │
│  - Validate query                        │
│  - Extract filters                       │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Backend: Search Service                  │
│  1. Generate query embedding (LLM)       │
│  2. Vector similarity search (Qdrant)    │
│  3. Apply filters (tags, ownership)      │
│  4. Enrich with DataHub metadata         │
│  5. Rank and score results               │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ Results with context + lineage          │
└─────────────────────────────────────────┘
```

### 3. Quality Monitoring Flow

```
┌─────────────────────────────────────────┐
│ Temporal Workflow: Daily Quality Scan    │
└─────────────┬───────────────────────────┘
              │ Schedule: 0 8 * * *
              ▼
┌─────────────────────────────────────────┐
│ 1. Fetch datasets from DataHub          │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 2. For each dataset:                     │
│    - Fetch historical metrics            │
│    - Run Prophet model                   │
│    - Detect anomalies                    │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 3. If anomaly detected:                  │
│    - Create alert                        │
│    - Notify owners (email/Slack)         │
│    - Update DataHub with quality aspect  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 4. Store results in PostgreSQL           │
│    - Historical trend analysis           │
│    - Dashboard visualization             │
└─────────────────────────────────────────┘
```

### 4. DataHub Integration Patterns

#### Pattern A: Read-Only Queries
```python
from datahub.ingestion.graph.client import DatahubClientConfig, DataHubGraph

# Query DataHub GraphQL
graph = DataHubGraph(DatahubClientConfig(server="http://datahub-gms:8080"))
dataset = graph.get_dataset(urn="urn:li:dataset:...")
```

#### Pattern B: Write Metadata
```python
from datahub.emitter.mce_builder import make_dataset_urn
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

**Assumption**: DataHub exists in a separate namespace or cluster

```yaml
# Data Spoke namespace only
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

  - postgresql (Data Spoke operational DB)
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
- Data Spoke namespace must have network access to DataHub namespace
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
dataspoke/
├── .github/
│   └── workflows/              # CI/CD pipelines
│       ├── test-backend.yml
│       ├── test-frontend.yml
│       └── deploy.yml
│
├── docker-images/              # Custom Docker images
│   ├── backend/
│   │   └── Dockerfile
│   ├── frontend/
│   │   └── Dockerfile
│   └── workers/
│       └── Dockerfile
│
├── helm-charts/                # Kubernetes deployment
│   └── dataspoke/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml
│
├── docs/                       # Documentation
│   ├── installation/
│   ├── operations/
│   ├── api/
│   └── development/
│
├── api/                        # Standalone API documentation
│   ├── openapi.yaml            # OpenAPI 3.0 spec
│   ├── README.md               # API overview
│   └── examples/               # Request/response examples
│
├── src/                        # Source code
│   ├── frontend/               # Next.js application
│   │   ├── app/
│   │   ├── components/
│   │   ├── lib/
│   │   └── package.json
│   │
│   ├── api/                    # FastAPI application
│   │   ├── routers/
│   │   ├── schemas/
│   │   ├── middleware/
│   │   └── main.py
│   │
│   ├── backend/                # Backend services
│   │   ├── services/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── config.py
│   │
│   ├── workflows/              # Temporal workflows
│   │   ├── ingestion/
│   │   ├── quality/
│   │   └── notifications/
│   │
│   └── shared/                 # Shared utilities
│       ├── datahub/            # DataHub client wrappers
│       ├── models/             # Shared data models
│       └── utils/
│
├── tests/                      # Test suites
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── scripts/                    # Utility scripts
│   ├── setup-dev.sh
│   ├── seed-data.sh
│   └── migrate-db.sh
│
├── migrations/                 # Database migrations
│   └── versions/
│
├── config/                     # Configuration files
│   ├── dev.yaml
│   ├── staging.yaml
│   └── production.yaml
│
├── docker-compose.yml          # Local development (includes DataHub for testing)
├── Makefile                    # Common commands
├── pyproject.toml              # Python dependencies
├── package.json                # Node dependencies (root)
└── README.md                   # Project overview
```

---

## Design Decisions & Rationale

### 1. Why FastAPI over Flask/Django?

**Decision**: FastAPI for API layer

**Rationale**:
- ✅ Async/await support for high concurrency
- ✅ Automatic OpenAPI documentation generation
- ✅ Pydantic for request/response validation
- ✅ High performance (comparable to Node.js)
- ✅ Type hints for better IDE support
- ❌ Flask: Less modern, no async, manual docs
- ❌ Django: Too heavy, unnecessary ORM overhead

### 2. Why Next.js over Create React App?

**Decision**: Next.js for frontend

**Rationale**:
- ✅ Server-side rendering improves initial load
- ✅ File-based routing simplifies structure
- ✅ API routes for simple backend needs
- ✅ Built-in optimization (images, fonts)
- ✅ Large ecosystem and community
- ❌ CRA: No SSR, deprecated

### 3. Why Qdrant over Pinecone/Weaviate?

**Decision**: Qdrant for vector database

**Rationale**:
- ✅ Open-source and self-hostable
- ✅ High performance (Rust-based)
- ✅ Simple deployment (single binary)
- ✅ Good Python SDK
- ✅ Cost-effective for on-premise
- ❌ Pinecone: Vendor lock-in, expensive at scale
- ❌ Weaviate: More complex, heavier resource usage

**Weaviate Alternative**: Consider if:
- Need multi-tenancy features
- Require complex schema relationships
- Want GraphQL-native interface

### 4. Why Temporal over Airflow?

**Decision**: Temporal (preferred), Airflow (alternative)

**Rationale for Temporal**:
- ✅ Better for long-running workflows
- ✅ Built-in retry and error handling
- ✅ Easier testing (workflow-as-code)
- ✅ Strong consistency guarantees
- ✅ Better developer experience

**When to use Airflow**:
- Existing Airflow infrastructure
- Batch-oriented workloads
- Team familiarity
- Visual DAG editor requirement

### 5. Why Standalone API Documentation?

**Decision**: API specs in separate `/api` directory

**Rationale**:
- ✅ AI agents can iterate on API design without backend
- ✅ Frontend development can start before backend implementation
- ✅ API mocking and testing without running services
- ✅ Clear contract between teams
- ✅ Documentation-driven development

### 6. Why Strict Layer Separation?

**Decision**: Separate frontend, API, backend completely

**Rationale**:
- ✅ Independent scaling (frontend ≠ backend resources)
- ✅ Technology flexibility (swap Next.js for Vue later)
- ✅ Security boundaries (frontend never accesses DB)
- ✅ Team autonomy (frontend/backend teams work independently)
- ✅ Clear ownership and responsibilities

### 7. PostgreSQL vs MongoDB?

**Decision**: PostgreSQL for operational database

**Rationale**:
- ✅ ACID guarantees for critical data
- ✅ JSON support (JSONB) for flexibility
- ✅ Mature ecosystem and tooling
- ✅ Better for relational data (ingestion configs, runs)
- ✅ Strong consistency needed for workflows
- ❌ MongoDB: Less suitable for structured operational data

---

## Security Considerations

### 1. Authentication & Authorization

```python
# JWT-based authentication
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer

security = HTTPBearer()

async def verify_token(credentials: HTTPBearer = Depends(security)):
    # Verify JWT token
    # Check user permissions
    # Return user context
```

**Strategy**:
- JWT tokens for API authentication
- Integration with corporate SSO (OIDC/SAML)
- Role-based access control (RBAC)
- DataHub permissions synchronized

### 2. Data Security

- **At Rest**: Encrypt PostgreSQL volumes, Qdrant storage
- **In Transit**: TLS/SSL for all communications
- **Secrets**: Use Kubernetes secrets or HashiCorp Vault
- **Audit Logging**: Log all data access and modifications

### 3. Network Security

- **Ingress**: WAF (Web Application Firewall)
- **Internal**: Service mesh (Istio) for mTLS between services
- **Egress**: Whitelist external API calls
- **Rate Limiting**: Per-user and per-IP limits

---

## Monitoring & Observability

### Metrics (Prometheus)

```yaml
Metrics to collect:
  - API latency (p50, p95, p99)
  - Error rates by endpoint
  - Vector DB query performance
  - Kafka consumer lag
  - Quality check execution time
  - Ingestion job success rate
```

### Logging (ELK Stack or Loki)

```yaml
Log aggregation:
  - Structured logging (JSON format)
  - Correlation IDs across services
  - Error stack traces
  - User action audit logs
```

### Tracing (Jaeger or Tempo)

```yaml
Distributed tracing:
  - End-to-end request tracing
  - Service dependency mapping
  - Performance bottleneck identification
```

### Dashboards (Grafana)

- System health overview
- API performance metrics
- Data quality trends
- Ingestion job status
- User activity analytics

---

## Scalability Considerations

### Horizontal Scaling

| Component | Scaling Strategy |
|-----------|-----------------|
| Frontend | Add replicas (stateless) |
| API | Add replicas (stateless) |
| Backend Workers | Add replicas (task queue) |
| Qdrant | Sharding by collection |
| Kafka | Add brokers and partitions |
| PostgreSQL | Read replicas for queries |

### Performance Optimizations

- **Caching**: Redis for frequently accessed data
- **CDN**: Static assets served via CDN
- **Connection Pooling**: Database connection pooling
- **Batch Processing**: Bulk operations for metadata updates
- **Async I/O**: Non-blocking operations throughout

---

## Migration & Integration

### Phase 1: Standalone Deployment
- Deploy Data Spoke alongside existing DataHub
- Configure Kafka consumer for DataHub events
- Minimal changes to DataHub configuration

### Phase 2: Custom Ingestion
- Develop custom connectors
- Migrate from manual processes to Data Spoke
- Integrate with existing data sources

### Phase 3: Quality Automation
- Deploy ML models for anomaly detection
- Configure alerting rules
- Integrate with incident management (PagerDuty, Slack)

### Phase 4: Semantic Search
- Build vector embeddings for all metadata
- Train ranking models
- Roll out to users incrementally

---

## Appendix

### Useful Commands

```bash
# Local development
make dev-up               # Start all services locally
make dev-down             # Stop all services
make test                 # Run all tests
make lint                 # Run linters

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

### Configuration Examples

See `config/` directory for environment-specific configurations.

### Further Reading

- [DataHub Architecture](https://datahubproject.io/docs/architecture/architecture/)
- [Temporal Documentation](https://docs.temporal.io/)
- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/)
- [Next.js Documentation](https://nextjs.org/docs)
