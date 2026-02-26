# DataSpoke API

> This document is the master reference for the DataSpoke API — its route catalogue,
> authentication model, request/response conventions, middleware stack, error catalogue,
> and real-time channels.
>
> Conforms to [MANIFESTO](../MANIFESTO_en.md) (highest authority).
> Routing model defined in [ARCHITECTURE](../ARCHITECTURE.md).
> Request/response conventions derive from [API_DESIGN_PRINCIPLE](../API_DESIGN_PRINCIPLE_en.md).
> DataHub integration patterns are in [DATAHUB_INTEGRATION](../DATAHUB_INTEGRATION.md).

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication & Authorization](#authentication--authorization)
3. [Route Catalogue](#route-catalogue)
4. [Request & Response Conventions](#request--response-conventions)
5. [Middleware Stack](#middleware-stack)
6. [Error Catalogue](#error-catalogue)
7. [WebSocket Channels](#websocket-channels)

---

## Overview

The DataSpoke API is a FastAPI (Python 3.11+) service that acts as the single ingress for
all DataSpoke clients — the portal UI and external AI agents. It exposes a three-tier URI
structure that maps directly to the user-group taxonomy defined in the MANIFESTO:

```
/api/v1/spoke/common/…     — Cross-cutting features shared across DE, DA, and DG
/api/v1/spoke/de/…         — Data Engineering features
/api/v1/spoke/da/…         — Data Analysis features
/api/v1/spoke/dg/…         — Data Governance features
/api/v1/hub/…              — DataHub pass-through (optional ingress for clients)
```

The API is the **only** component that accesses DataHub, PostgreSQL, Redis, Qdrant, and
Temporal directly on behalf of UI and AI-agent clients. Backend services and Temporal
workers are internal and not exposed over HTTP.

```
Browser / AI Agent
       │
       ▼  HTTPS
┌──────────────────┐
│  DataSpoke API   │  ← this document
│  (FastAPI)       │
└──────────────────┘
   │      │      │
   ▼      ▼      ▼
DataHub  Postgres  Qdrant / Redis / Temporal
```

### API-First Design

Standalone OpenAPI 3.0 specifications live in `api/` as independent artifacts. AI agents
and the frontend team iterate on those specs without a running backend. The FastAPI
implementation must remain consistent with those artifacts. When a route changes, update
`api/` first, then the implementation.

---

## Authentication & Authorization

### Token Strategy

DataSpoke uses **JWT (JSON Web Tokens)** for stateless authentication.

| Token type | Lifetime | Storage |
|------------|----------|---------|
| Access token | 15 minutes | Memory / `Authorization` header |
| Refresh token | 7 days | HttpOnly cookie |

Token issuance and refresh are handled at:
- `POST /api/v1/auth/token` — issue access + refresh tokens (credential exchange)
- `POST /api/v1/auth/token/refresh` — issue new access token from refresh token
- `POST /api/v1/auth/token/revoke` — revoke refresh token (logout)

### JWT Claims

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "groups": ["de"],
  "exp": 1234567890,
  "iat": 1234567890
}
```

The `groups` claim is an array of user-group identifiers (`de`, `da`, `dg`). A user may
belong to multiple groups. The middleware enforces that a request targeting
`/spoke/de/…` must have `"de"` in the `groups` claim.

### Group-to-Route Access Control

| URI tier | Required group claim | Accessible to |
|----------|---------------------|---------------|
| `/spoke/common/…` | any valid group | DE, DA, DG |
| `/spoke/de/…` | `"de"` | DE (and admins) |
| `/spoke/da/…` | `"da"` | DA (and admins) |
| `/spoke/dg/…` | `"dg"` | DG (and admins) |
| `/hub/…` | any valid group | DE, DA, DG |
| `/auth/…` | none (public) | unauthenticated clients |

### Admin Role

Users with `"admin"` in `groups` bypass group-tier restrictions and can call any route.
Admin routes (user management, system configuration) live under `/api/v1/admin/…` and
require the `"admin"` claim exclusively.

### Auth Flow

```
Client                       DataSpoke API              Identity Store
  │                               │                          │
  │── POST /auth/token ──────────►│                          │
  │   {email, password}           │── verify credentials ───►│
  │                               │◄─ user record, groups ───│
  │◄── {access_token,             │
  │     refresh_token cookie} ────│
  │                               │
  │── GET /spoke/de/ingestion ───►│
  │   Authorization: Bearer <at>  │── validate JWT, check groups ─► 200 OK
```

---

## Route Catalogue

All routes are prefixed with `/api/v1`. Routes marked **WS** are WebSocket endpoints.

### Auth

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/auth/token` | Issue access + refresh tokens |
| `POST` | `/auth/token/refresh` | Refresh access token |
| `POST` | `/auth/token/revoke` | Revoke refresh token (logout) |

### Common (`/spoke/common`)

Cross-cutting features consumed by multiple user groups.

| Method | Path | Purpose | Feature | UC |
|--------|------|---------|---------|-----|
| `GET` | `/spoke/common/ontology` | List concept categories | Ontology Builder | UC4, UC8 |
| `GET` | `/spoke/common/ontology/{concept_id}` | Get concept detail + relationships | Ontology Builder | UC4, UC8 |
| `GET` | `/spoke/common/ontology/{concept_id}/attr` | Get concept attributes (confidence, parent) | Ontology Builder | UC4 |
| `GET` | `/spoke/common/ontology/{concept_id}/event` | Change history for a concept | Ontology Builder | UC4 |
| `POST` | `/spoke/common/ontology/{concept_id}/method/approve` | Approve a pending concept proposal | Ontology Builder | UC4 |
| `POST` | `/spoke/common/ontology/{concept_id}/method/reject` | Reject a pending concept proposal | Ontology Builder | UC4 |
| `GET` | `/spoke/common/quality/{dataset_urn}` | Get quality score for a dataset | Quality Score Engine | UC2, UC3, UC6 |
| `GET` | `/spoke/common/quality/{dataset_urn}/event` | Quality score history (time-series) | Quality Score Engine | UC2, UC3 |

### Data Engineering (`/spoke/de`)

| Method | Path | Purpose | Feature | UC |
|--------|------|---------|---------|-----|
| `GET` | `/spoke/de/ingestion` | List ingestion configs | Deep Technical Spec Ingestion | UC1 |
| `POST` | `/spoke/de/ingestion` | Create ingestion config | Deep Technical Spec Ingestion | UC1 |
| `GET` | `/spoke/de/ingestion/{config_id}` | Get ingestion config detail | Deep Technical Spec Ingestion | UC1 |
| `PUT` | `/spoke/de/ingestion/{config_id}` | Update ingestion config | Deep Technical Spec Ingestion | UC1 |
| `DELETE` | `/spoke/de/ingestion/{config_id}` | Delete ingestion config | Deep Technical Spec Ingestion | UC1 |
| `GET` | `/spoke/de/ingestion/{config_id}/event` | Ingestion run history | Deep Technical Spec Ingestion | UC1 |
| `POST` | `/spoke/de/ingestion/{config_id}/method/run` | Trigger ingestion run | Deep Technical Spec Ingestion | UC1 |
| `POST` | `/spoke/de/ingestion/{config_id}/method/dry-run` | Dry-run ingestion (no write) | Deep Technical Spec Ingestion | UC1 |
| `GET` | `/spoke/de/validator/{dataset_urn}` | Get validation result for dataset | Online Data Validator | UC2, UC3 |
| `POST` | `/spoke/de/validator/{dataset_urn}/method/validate` | Run validation (writes result) | Online Data Validator | UC2 |
| `POST` | `/spoke/de/validator/{dataset_urn}/method/dry-validate` | Dry-run validation (no write) | Online Data Validator | UC2 |
| `GET` | `/spoke/de/validator/{dataset_urn}/event` | Validation run history | Online Data Validator | UC2, UC3 |
| `GET` | `/spoke/de/docs/{dataset_urn}` | Get doc suggestion state | Automated Doc Suggestions | UC4 |
| `GET` | `/spoke/de/docs/{dataset_urn}/attr` | Get suggestion metadata (confidence, source) | Automated Doc Suggestions | UC4 |
| `POST` | `/spoke/de/docs/{dataset_urn}/method/generate` | Trigger doc suggestion generation | Automated Doc Suggestions | UC4 |
| `POST` | `/spoke/de/docs/{dataset_urn}/method/apply` | Apply approved suggestions to DataHub | Automated Doc Suggestions | UC4 |
| `GET` | `/spoke/de/docs/{dataset_urn}/event` | Doc suggestion history | Automated Doc Suggestions | UC4 |
| **WS** | `/spoke/de/validator/{dataset_urn}/stream` | Real-time validation progress stream | Online Data Validator | UC2 |

### Data Analysis (`/spoke/da`)

| Method | Path | Purpose | Feature | UC |
|--------|------|---------|---------|-----|
| `GET` | `/spoke/da/search` | Natural language search (`?q=…`) | Natural Language Search | UC5 |
| `GET` | `/spoke/da/search/{dataset_urn}` | Get search-indexed metadata for dataset | Natural Language Search | UC5 |
| `POST` | `/spoke/da/search/method/reindex` | Trigger reindex for a dataset | Natural Language Search | UC5 |
| `GET` | `/spoke/da/text-to-sql/context/{dataset_urn}` | Get text-to-SQL optimized context | Text-to-SQL Metadata | UC7 |
| `GET` | `/spoke/da/text-to-sql/join-paths` | Recommend join paths between datasets (`?from=…&to=…`) | Text-to-SQL Metadata | UC7 |
| `GET` | `/spoke/da/validator/{dataset_urn}` | Get validation result for dataset | Online Data Validator | UC2 |
| `POST` | `/spoke/da/validator/{dataset_urn}/method/validate` | Run validation (writes result) | Online Data Validator | UC2 |
| `POST` | `/spoke/da/validator/{dataset_urn}/method/dry-validate` | Dry-run validation (no write) | Online Data Validator | UC2 |
| `GET` | `/spoke/da/validator/{dataset_urn}/event` | Validation run history | Online Data Validator | UC2 |
| **WS** | `/spoke/da/validator/{dataset_urn}/stream` | Real-time validation progress stream | Online Data Validator | UC2 |

### Data Governance (`/spoke/dg`)

| Method | Path | Purpose | Feature | UC |
|--------|------|---------|---------|-----|
| `GET` | `/spoke/dg/metrics` | Get aggregated enterprise metrics snapshot | Enterprise Metrics Dashboard | UC6 |
| `GET` | `/spoke/dg/metrics/attr` | Get metrics config (thresholds, alert rules) | Enterprise Metrics Dashboard | UC6 |
| `PATCH` | `/spoke/dg/metrics/attr` | Update metrics config | Enterprise Metrics Dashboard | UC6 |
| `GET` | `/spoke/dg/metrics/event` | Metrics collection run history | Enterprise Metrics Dashboard | UC6 |
| `GET` | `/spoke/dg/metrics/{department_id}` | Get department-level metrics | Enterprise Metrics Dashboard | UC6 |
| `GET` | `/spoke/dg/metrics/{department_id}/event` | Department metrics history (time-series) | Enterprise Metrics Dashboard | UC6 |
| `GET` | `/spoke/dg/overview` | Get multi-perspective overview (graph + medallion) | Multi-Perspective Data Overview | UC8 |
| `GET` | `/spoke/dg/overview/attr` | Get visualization config (layout, coloring, filters) | Multi-Perspective Data Overview | UC8 |
| `PATCH` | `/spoke/dg/overview/attr` | Update visualization config | Multi-Perspective Data Overview | UC8 |
| `GET` | `/spoke/dg/overview/blind-spots` | List datasets with no taxonomy assignment or health score | Multi-Perspective Data Overview | UC8 |
| **WS** | `/spoke/dg/metrics/stream` | Real-time metrics update stream | Enterprise Metrics Dashboard | UC6 |

### DataHub Pass-Through (`/hub`)

Optional ingress that forwards requests to DataHub GMS. Useful for clients that want a
single base URL. Authentication is still enforced by DataSpoke; the request is proxied
after JWT validation.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/hub/graphql` | Proxy DataHub GraphQL queries |
| `GET` | `/hub/openapi/{path:path}` | Proxy DataHub REST OpenAPI endpoints |

### System

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness check (no auth required) |
| `GET` | `/ready` | Readiness check (verifies DataHub, PostgreSQL, Redis connectivity) |

---

## Request & Response Conventions

These rules apply `API_DESIGN_PRINCIPLE_en.md` concretely to DataSpoke.

### Field Naming

All request body and response fields use **snake_case**.

### Standard Response Envelope

All collection responses include a content key named after the resource + pagination
metadata:

```json
{
  "datasets": [
    { "urn": "urn:li:dataset:…", "name": "orders", "quality_score": 82 },
    { "urn": "urn:li:dataset:…", "name": "customers", "quality_score": 91 }
  ],
  "offset": 0,
  "limit": 20,
  "total_count": 143,
  "resp_time": "2026-02-27T10:00:00.000Z"
}
```

Single-resource responses return the object directly with `resp_time` at the top level:

```json
{
  "urn": "urn:li:dataset:…",
  "name": "orders",
  "quality_score": 82,
  "resp_time": "2026-02-27T10:00:00.000Z"
}
```

### Query Parameters

| Parameter | Type | Purpose |
|-----------|------|---------|
| `offset` | integer | Pagination start (default `0`) |
| `limit` | integer | Page size (default `20`, max `100`) |
| `sort` | string | Field + direction, e.g. `quality_score_desc` |
| `q` | string | Natural language query (search endpoints only) |

### Meta-Classifier Conventions

`attr`, `method`, and `event` sub-resources follow the `API_DESIGN_PRINCIPLE_en.md`
definitions:

- `attr` — Read or update a subset of resource attributes (configuration, thresholds,
  visualization settings). Use `GET` to read, `PATCH` to update partial fields.
- `method` — Business actions that go beyond CRUD: `run`, `dry-run`, `approve`, `reject`,
  `apply`, `generate`, `reindex`. Always `POST`.
- `event` — Immutable history log of occurrences on a resource. Always `GET`; supports
  `offset`/`limit` pagination and `sort=occurred_at_desc`.

### Date/Time

All timestamps use ISO 8601 with UTC: `2026-02-27T10:00:00.000Z`.

---

## Middleware Stack

Requests pass through middleware in the following order:

```
Incoming Request
       │
       ▼
┌─────────────────────────┐
│ 1. CORS                 │  Allow configured origins; reject others with 403
├─────────────────────────┤
│ 2. Request Logging      │  Log method, path, trace ID, client IP (before handler)
├─────────────────────────┤
│ 3. Auth (JWT Validate)  │  Verify signature, expiry, extract claims
│                         │  Skip for /health, /ready, /auth/*
├─────────────────────────┤
│ 4. Group Enforcement    │  Check groups claim against URI tier
│                         │  Return 403 if insufficient
├─────────────────────────┤
│ 5. Rate Limiting        │  Token-bucket per user (Redis-backed)
│                         │  Default: 120 req/min; burst: 20
├─────────────────────────┤
│ 6. Route Handler        │  FastAPI dependency injection + business logic
├─────────────────────────┤
│ 7. Response Logging     │  Log status code, latency, trace ID (after handler)
└─────────────────────────┘
       │
       ▼
Outgoing Response
```

### Trace ID

Every request is assigned a `X-Trace-Id` (UUID v4) at layer 2. If the client provides
`X-Trace-Id` in the request headers, that value is reused. The trace ID is included in
all log lines and in every response header.

---

## Error Catalogue

All errors follow the standard envelope:

```json
{
  "error_code": "DATASET_NOT_FOUND",
  "message": "No dataset found for URN 'urn:li:dataset:unknown'.",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### HTTP Status Codes

| Status | When used |
|--------|-----------|
| `200 OK` | Successful read or action |
| `201 Created` | Resource successfully created |
| `204 No Content` | Successful deletion |
| `400 Bad Request` | Malformed request, missing required fields, invalid parameter values |
| `401 Unauthorized` | Missing or expired access token |
| `403 Forbidden` | Valid token but insufficient group claim |
| `404 Not Found` | Resource does not exist |
| `409 Conflict` | Duplicate resource creation attempt |
| `422 Unprocessable Entity` | Pydantic validation failure (field type mismatch, constraint violation) |
| `429 Too Many Requests` | Rate limit exceeded; `Retry-After` header is set |
| `502 Bad Gateway` | DataHub GMS unreachable or returned an unexpected error |
| `503 Service Unavailable` | Temporal, PostgreSQL, or Qdrant connection failure |

### Application Error Codes

| `error_code` | HTTP | Description |
|-------------|------|-------------|
| `INVALID_PARAMETER` | 400 | Query param or body field fails validation |
| `MISSING_REQUIRED_FIELD` | 400 | Required body field not provided |
| `UNAUTHORIZED` | 401 | Token missing, expired, or malformed |
| `FORBIDDEN` | 403 | Valid token; groups claim does not satisfy route requirement |
| `DATASET_NOT_FOUND` | 404 | Dataset URN does not exist in DataHub |
| `CONCEPT_NOT_FOUND` | 404 | Ontology concept ID not found |
| `CONFIG_NOT_FOUND` | 404 | Ingestion config not found |
| `DUPLICATE_CONFIG` | 409 | Ingestion config with same name already exists |
| `INGESTION_RUNNING` | 409 | A run is already in progress for this config |
| `VALIDATION_RUNNING` | 409 | A validation is already in progress for this dataset |
| `DATAHUB_UNAVAILABLE` | 502 | DataHub GMS did not respond or returned an error |
| `STORAGE_UNAVAILABLE` | 503 | PostgreSQL, Redis, or Qdrant connection failed |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests; back off and retry |

---

## WebSocket Channels

WebSocket connections follow the same authentication model as REST: the client must send
a valid JWT in the first message after opening the connection.

### Connection Handshake

```
Client                        DataSpoke API
  │                                │
  │── WS upgrade ─────────────────►│
  │                                │
  │── {"type":"auth",              │
  │    "token":"<access_token>"} ──►│
  │                                │── validate JWT
  │◄── {"type":"auth_ok"} ─────────│
  │                                │   (stream begins)
  │◄── {"type":"progress", …} ─────│
  │◄── {"type":"result", …} ───────│
  │                                │── server closes on completion
```

If auth fails, the server sends `{"type":"auth_error","error_code":"UNAUTHORIZED"}` and
closes the connection.

### Validation Progress Stream (`/spoke/de/validator/{urn}/stream`, `/spoke/da/…`)

Messages sent during a validation run:

```json
{"type": "progress", "step": "fetch_aspects", "pct": 20, "msg": "Fetching DataHub aspects"}
{"type": "progress", "step": "compute_score", "pct": 60, "msg": "Computing quality score"}
{"type": "progress", "step": "anomaly_detect", "pct": 80, "msg": "Running anomaly detection"}
{"type": "result",
 "status": "completed",
 "quality_score": 78,
 "issues": [{"type": "freshness", "severity": "warning", "detail": "Last updated 3 days ago"}],
 "recommendations": ["Review freshness SLA", "Add ownership tag"]}
```

### Enterprise Metrics Stream (`/spoke/dg/metrics/stream`)

Pushed when the Temporal metrics collection workflow emits an update:

```json
{"type": "metrics_update",
 "snapshot_at": "2026-02-27T10:00:00.000Z",
 "total_datasets": 1420,
 "avg_quality_score": 74,
 "departments_below_threshold": ["Marketing", "Legal"]}
```
