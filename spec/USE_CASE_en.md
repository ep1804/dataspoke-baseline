# DataSpoke: Detailed Use Case Scenarios

> **Note on Document Purpose**
> This document presents conceptual scenarios for ideation and vision alignment. These use cases illustrate the intended capabilities and value propositions of DataSpoke, but are not implementation specifications or technical requirements. Actual implementation details, technical architecture, and feature prioritization will be defined in separate technical specification documents.

This document provides detailed, real-world scenarios demonstrating how DataSpoke enhances DataHub capabilities across its three user groups: **Data Engineering (DE)**, **Data Analysis (DA)**, and **Data Governance (DG)**.

All scenarios share a single imaginary company context — **Imazon**, an online bookstore — so that the use cases coexist and reinforce each other.

---

## Imaginary Company Profile: Imazon

Imazon is a 15-year-old online bookstore. Its data landscape reflects years of organic growth:

- **Legacy Oracle data warehouse** — 500+ tables covering book catalog, customers, orders, reviews, publishers, inventory, and shipping
- **Departments** — Engineering, Data Science, Marketing, Finance, Legal, Operations, Publisher Relations, Customer Support
- **Key data domains** — `catalog.*` (books, authors, genres), `customers.*`, `orders.*`, `reviews.*`, `recommendations.*`, `publishers.*`, `inventory.*`, `shipping.*`
- **DataHub adoption** — recently deployed; standard Oracle connector imported schema metadata but missed business context, stored-procedure lineage, and tribal knowledge locked in Confluence and spreadsheets

---

## Feature Mapping

| Use Case | User Group | Feature |
|----------|-----------|---------|
| [Use Case 1: Deep Ingestion — Legacy Book Catalog Enrichment](#use-case-1-deep-ingestion--legacy-book-catalog-enrichment) | DE | Deep Technical Spec Ingestion |
| [Use Case 2: Online Validator — Recommendation Pipeline Verification](#use-case-2-online-validator--recommendation-pipeline-verification) | DE / DA | Online Data Validator |
| [Use Case 3: Predictive SLA — Fulfillment Pipeline Early Warning](#use-case-3-predictive-sla--fulfillment-pipeline-early-warning) | DE | Online Data Validator |
| [Use Case 4: Doc Suggestions — Post-Acquisition Ontology Reconciliation](#use-case-4-doc-suggestions--post-acquisition-ontology-reconciliation) | DE | Automated Documentation Suggestions |
| [Use Case 5: NL Search — GDPR Compliance Audit](#use-case-5-nl-search--gdpr-compliance-audit) | DA | Natural Language Search |
| [Use Case 6: Metrics Dashboard — Enterprise Metadata Health](#use-case-6-metrics-dashboard--enterprise-metadata-health) | DG | Enterprise Metrics Time-Series Monitoring |

---

## Data Engineering (DE) Group

### Use Case 1: Deep Ingestion — Legacy Book Catalog Enrichment

**Feature**: Deep Technical Spec Ingestion

#### Scenario: Enriching the Legacy Oracle Book Catalog

**Background:**
Imazon's Oracle data warehouse holds 500+ tables built over 15 years. Standard DataHub connectors captured schema metadata — table names, column types, primary keys — but missed the rich business context stored outside the database: Confluence pages describing editorial taxonomy, Excel feeds from publishers mapping ISBNs to imprints, an internal API for genre classification, and lineage hidden inside PL/SQL stored procedures that compute bestseller rankings and royalty calculations.

#### Without DataSpoke

Standard Oracle connector output: 500 tables with column types and keys — nothing else. No business descriptions (stored in Confluence), no publisher metadata (Excel), no genre taxonomy (API), no stored-proc lineage. Data consumers browse DataHub and see bare technical schemas with no way to determine what `catalog.title_master` actually tracks or how `reports.monthly_royalties` is computed.

#### With DataSpoke

**Register a multi-source enrichment config:**

```python
# POST /api/v1/spoke/de/ingestion/configs
dataspoke.ingestion.register_config({
  "name": "oracle_book_catalog_enriched",
  "source_type": "oracle",
  "schedule": "0 2 * * *",  # Daily at 2 AM

  "enrichment_sources": [
    {
      "type": "confluence",
      "space": "BOOK_DATA_DICTIONARY",
      "page_prefix": "Table: ",
      "fields_mapping": {
        "description": "confluence.content.body",
        "business_owner": "confluence.labels.owner",
        "pii_classification": "confluence.labels.pii"
      }
    },
    {
      "type": "excel",
      "path": "s3://imazon-docs/publisher-feeds/isbn-imprint-mapping.xlsx",
      "sheet": "ISBN_Classifications",
      "key_column": "table_name",
      "fields_mapping": {
        "publisher_domain": "Imprint",
        "content_rating": "Rating",
        "genre_taxonomy": "Genre_Path"
      }
    },
    {
      "type": "custom_api",
      "endpoint": "https://taxonomy-api.imazon.internal/genres",
      "auth": "bearer_token",
      "fields_mapping": {
        "genre_hierarchy": "$.genre.path",
        "editorial_tags": "$.genre.editorial_tags"
      }
    }
  ],

  "custom_extractors": [
    {
      "name": "plsql_lineage_parser",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_lineage",
      "function": "extract_stored_proc_lineage",
      "params": { "parse_insert_select": true, "parse_merge_statements": true }
    },
    {
      "name": "quality_rule_extractor",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_quality",
      "function": "extract_check_constraints_as_rules"
    }
  ]
})
```

**Custom PL/SQL lineage extractor** (excerpt):

```python
# dataspoke/custom/oracle_lineage.py
class OraclePLSQLLineageExtractor(CustomExtractor):
    def extract_stored_proc_lineage(self, procedure_name, procedure_body, params):
        lineage_edges = []
        for stmt in sqlparse.parse(procedure_body):
            if self._is_insert_select(stmt):
                for source in self._extract_source_tables(stmt):
                    lineage_edges.append(LineageEdge(
                        source_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{source},PROD)",
                        target_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{self._extract_target_table(stmt)},PROD)",
                        transformation_type="stored_procedure",
                        transformation_logic=procedure_name,
                        confidence_score=0.95
                    ))
        return lineage_edges
```

**Enriched metadata example — `catalog.title_master`:**

```yaml
Dataset: catalog.title_master
Platform: Oracle / DWPROD

# Base Schema (Standard Connector)
Columns: 62 | Primary Key: isbn, edition_id

# Enriched — Business Context (Confluence)
Description: |
  Master catalog of all book titles. One row per ISBN+edition.
  Source of truth for pricing, availability, and editorial classification.
  Updated nightly from publisher feeds and editorial review queue.

# Enriched — Ownership (Confluence + HR API)
Owner: maria.garcia@imazon.com | Team: Catalog Engineering

# Enriched — Publisher Metadata (Excel)
Publisher Domain: All imprints | Genre Taxonomy: 4-level hierarchy

# Enriched — Lineage (PL/SQL Parser)
Upstream: publishers.feed_raw, editorial.review_queue, pricing.base_rates
Generated By: PROC_NIGHTLY_CATALOG_REFRESH (stored procedure)
Downstream: recommendations.book_features, reports.catalog_summary

# Enriched — Quality Rules (CHECK Constraints)
1. list_price > 0
2. publication_date <= SYSDATE
3. isbn IS NOT NULL AND LENGTH(isbn) IN (10, 13)
```

#### DataHub Integration Points

All enriched metadata is persisted to DataHub via `DatahubRestEmitter`, which internally calls the OpenAPI endpoint `POST /openapi/v3/entity/dataset`. Each category maps to a DataHub aspect emitted as an MCP:

| Ingestion Phase | DataHub Aspect | REST API Path | What It Stores |
|----------------|---------------|---------------|----------------|
| Base Schema | `schemaMetadata` | `POST /openapi/v3/entity/dataset` | Column names, types, keys |
| Business Descriptions | `datasetProperties` | `POST /openapi/v3/entity/dataset` | `description` from Confluence |
| PII / Editorial Tags | `globalTags` | `POST /openapi/v3/entity/dataset` | `urn:li:tag:PII`, `urn:li:tag:Editorial_Reviewed` |
| Publisher Classification | `datasetProperties.customProperties` | `POST /openapi/v3/entity/dataset` | `publisher_domain`, `genre_taxonomy`, `content_rating` |
| Ownership | `ownership` | `POST /openapi/v3/entity/dataset` | Owner URN + `BUSINESS_OWNER` type |
| PL/SQL Lineage | `upstreamLineage` | `POST /openapi/v3/entity/dataset` | Source → target dataset URN edges |
| Quality Rules | `assertionInfo` + `assertionRunEvent` | `POST /openapi/v3/entity/assertion` | CHECK constraints as assertions |

```python
from datahub.emitter.rest_emitter import DatahubRestEmitter
from datahub.emitter.mcp import MetadataChangeProposalWrapper
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.metadata.schema_classes import (
    DatasetLineageTypeClass,
    DatasetPropertiesClass,
    UpstreamClass,
    UpstreamLineageClass,
)

emitter = DatahubRestEmitter(gms_server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN)
dataset_urn = make_dataset_urn(platform="oracle", name="catalog.title_master", env="PROD")

# Description + custom properties — business context from Confluence
# REST: POST /openapi/v3/entity/dataset  (aspect: datasetProperties)
emitter.emit_mcp(MetadataChangeProposalWrapper(
    entityUrn=dataset_urn,
    aspect=DatasetPropertiesClass(
        description="Master catalog of all book titles...",
        customProperties={"genre_taxonomy": "4-level", "publisher_domain": "All imprints"},
    ),
))

# Lineage — upstream tables extracted from PL/SQL stored procedures
# REST: POST /openapi/v3/entity/dataset  (aspect: upstreamLineage)
emitter.emit_mcp(MetadataChangeProposalWrapper(
    entityUrn=dataset_urn,
    aspect=UpstreamLineageClass(
        upstreams=[UpstreamClass(
            dataset=make_dataset_urn(platform="oracle", name="publishers.feed_raw", env="PROD"),
            type=DatasetLineageTypeClass.TRANSFORMED,
        )],
    ),
))
```

> **Key point**: DataHub provides no enrichment logic — it only persists what DataSpoke sends.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **Ingestion Config Registry** | Store enrichment configs (connections, field mappings, extractors) | DataHub recipes handle standard connectors only |
| **Enrichment Source Connectors** | Fetch from Confluence, Excel/S3, taxonomy API | DataHub connectors are database/platform-focused |
| **Custom Extractor Framework** | Plugin system for PL/SQL lineage parsing, CHECK constraint extraction | Parsing stored procedure bodies is outside DataHub's scope |
| **Field Mapping Engine** | Map Confluence labels → tags, Excel columns → custom properties | DataHub accepts structured aspects but doesn't transform unstructured inputs |
| **Orchestration (Temporal)** | Schedule, per-phase retry, notifications | DataHub runs recipes atomically; multi-source orchestration requires Temporal |
| **Vector Index Sync** | Generate embeddings → Qdrant on successful ingestion | DataHub has Elasticsearch keyword search, not vector similarity |

#### Outcome

| Aspect | Standard Connector | DataSpoke Deep Ingestion |
|--------|-------------------|--------------------------|
| Schema Coverage | 500 tables | 500 tables |
| Business Descriptions | 0% | 89% (445/500) |
| Ownership | 0% | 74% (370/500) |
| Genre / Publisher Tags | 0% | 100% |
| Stored Proc Lineage | Not supported | 210 edges extracted |
| Quality Rules | Manual entry only | 380 auto-extracted |
| Update Frequency | Manual re-run | Automated daily |

---

### Use Case 2: Online Validator — Recommendation Pipeline Verification

**Feature**: Online Data Validator (shared with DA group)

#### Scenario: AI Agent Builds a Book Recommendation Pipeline

**Background:**
A data scientist asks an AI Agent: "Build a daily book recommendation pipeline using `reviews.user_ratings` and `orders.purchase_history`." The Validator ensures the agent selects healthy data sources and produces compliant output.

#### Without DataSpoke

The AI Agent searches DataHub for "reviews" and "orders" tables, picks candidates by naming convention, generates code without understanding data quality, and deploys a pipeline that may use a degraded table (`reviews.user_ratings_legacy` has a 30% null rate on `rating_score` since a migration bug last week).

#### With DataSpoke

**Step 1: Semantic Discovery**

```
AI Agent Query: "Find review and purchase tables suitable for ML training"

DataSpoke Response (via /api/v1/spoke/de/validator):
- reviews.user_ratings (✓ Quality Score: 96)
  Last refreshed: 1 hour ago | Completeness: 99.7% | 28 downstream consumers

- reviews.user_ratings_legacy (⚠ Quality Issues)
  Anomaly: 30% null rate on rating_score since 2024-02-03
  Recommendation: Avoid — use reviews.user_ratings instead

- orders.purchase_history (✓ Recommended)
  SLA: 99.9% on-time | Documentation: 100% | Certified for ML use
```

**Step 2: Context Verification**

```python
# POST /api/v1/spoke/de/validator/context
dataspoke.validator.verify_context("reviews.user_ratings_legacy")

# Response:
{
  "status": "degraded",
  "quality_issues": [{
    "type": "null_rate_anomaly",
    "severity": "high",
    "message": "rating_score null rate jumped from 0.3% to 30%",
    "recommendation": "Use reviews.user_ratings instead"
  }],
  "alternative_entities": ["reviews.user_ratings"]
}
```

**Step 3: Pipeline Validation**

```yaml
Pipeline: book_recommendations_daily_v1
Author: AI Agent (claude-sonnet-4.5)

Validation Results:
✓ Documentation: Description present, owner assigned to data-science-team
✓ Naming Convention: book_recommendation_features (compliant)
✓ Quality Checks: NULL handling implemented, schema backward-compatible
✓ Lineage Impact: 2 upstream tables (both healthy), no circular deps
⚠ Recommendations: Add freshness check, implement monitoring alert
```

**Step 4**: AI Agent deploys with verified sources, compliant structure, and quality checks.

#### DataHub Integration Points

The Validator is primarily a **read** consumer. It queries multiple DataHub aspects to assemble health assessments:

| Validator Step | DataHub Aspect | REST API Path | What It Returns |
|---------------|----------------------|---------------|----------------|
| Semantic Discovery | `datasetProperties` | `GET /aspects/{urn}?aspect=datasetProperties` | Description, tags — match semantic intent |
| Quality Score | `datasetProfile` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | Row counts, null rates over time |
| Freshness | `operation` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | `lastUpdatedTimestamp` |
| Downstream count | `upstreamLineage` | GraphQL: `searchAcrossLineage` | Count of downstream consumers |
| Deprecation | `deprecation` | `GET /aspects/{urn}?aspect=deprecation` | `deprecated` flag, replacement URN |
| Assertion history | `assertionRunEvent` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | Pass/fail history |
| Schema validation | `schemaMetadata` | `GET /aspects/{urn}?aspect=schemaMetadata` | Column names, types for naming checks |

```python
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.metadata.schema_classes import (
    DatasetProfileClass,
    OperationClass,
    UpstreamLineageClass,
)

graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))
dataset_urn = make_dataset_urn(platform="oracle", name="reviews.user_ratings_legacy", env="PROD")

# Profile history — null rates over time for anomaly detection
# REST: POST /aspects?action=getTimeseriesAspectValues
profiles = graph.get_timeseries_values(
    dataset_urn, DatasetProfileClass, filter={}, limit=30,
)

# Last operation — freshness check
# REST: POST /aspects?action=getTimeseriesAspectValues
operations = graph.get_timeseries_values(
    dataset_urn, OperationClass, filter={}, limit=1,
)

# Upstream lineage — are dependencies healthy?
# REST: GET /aspects/{urn}?aspect=upstreamLineage
upstream = graph.get_aspect(dataset_urn, UpstreamLineageClass)
```

> **Key point**: DataHub is a passive data store. It provides raw signals; DataSpoke computes quality scores, anomaly detection, and recommendations.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **Quality Score Engine** | Aggregate profiles, assertions, docs, freshness → single 0–100 score | DataHub has no cross-aspect scoring |
| **Null Rate Anomaly Detection** | Time-series analysis on `datasetProfile` null rates | DataHub stores profiles, no statistical analysis |
| **Alternative Recommendation** | Query Qdrant for semantically similar healthy datasets | DataHub has keyword search only |
| **Pipeline Validation Engine** | Validate naming, schema compatibility, lineage impact | DataHub stores metadata but doesn't validate against it |
| **Validation Result Cache** | Redis cache for AI agents in tight coding loops | DataHub has no caching for computed results |

#### Outcome

| Metric | Without DataSpoke | With DataSpoke |
|--------|------------------|----------------|
| Pipeline failure rate | ~30% (bad data) | <5% (pre-verified) |
| Human review time | Hours per pipeline | Minutes (automated) |
| Data quality incidents | Frequent | Near zero |

---

### Use Case 3: Predictive SLA — Fulfillment Pipeline Early Warning

**Feature**: Online Data Validator (time-series monitoring)

#### Scenario: Shipping Partner API Rate-Limiting Threatens Order Fulfillment Dashboard

**Background:**
Imazon's `orders.daily_fulfillment_summary` table powers the logistics dashboard used by Operations, Finance, and Customer Support. It normally processes 1.5M rows daily by 9 AM, aggregating data from `orders.raw_events`, `shipping.carrier_status`, and an external shipping partner API.

#### Without DataSpoke

```
9:00 AM — Alert: orders.daily_fulfillment_summary is empty
Status: SLA BREACH — logistics dashboard down
Response: Manual investigation begins. Root cause found at 10:30 AM (shipping API throttled).
Total downtime: 2.5 hours.
```

#### With DataSpoke

**7:00 AM — Early Warning (2 hours before SLA):**

```
DataSpoke Predictive Alert:
⚠ Anomaly: orders.daily_fulfillment_summary

Current volume at 7 AM: 320K rows
Expected (weekday 7 AM): 900K ±5%
Deviation: -64% (outside 3σ threshold)

Upstream Analysis:
  orders.raw_events: ✓ Normal (1.4M rows at 6:30 AM)
  shipping.carrier_status: ⚠ Delayed 40 min (unusual)
    └─ Dependency: shipping_partner_api.tracking
       └─ Issue: API rate limit exceeded (429 responses)

Root Cause (Likely): Shipping partner API throttling
Prediction: Will miss 9 AM SLA by ~1.5 hours

Recommended Actions:
  1. Check shipping_partner_api rate limits
  2. Contact logistics-eng about API quota
  3. Consider fallback: cached carrier data from last successful pull

Impact:
  - Logistics Dashboard (12 viewers — Operations team)
  - Finance Daily Shipment Report (auto-scheduled 9:30 AM)
  - Customer Support SLA Tracker (8 viewers)
```

**7:15 AM** — Operations engineer confirms API throttling, requests quota increase. Pipeline recovers by 8:00 AM. SLA met with 1-hour buffer.

**Week 2 — Pattern Learning:**

```
DataSpoke Insight: orders.daily_fulfillment_summary
Pattern: Monday 7 AM volume consistently -12% vs other weekdays (4-week trend)
Hypothesis: Weekend order backlog creates Monday morning batch delay
Auto-adjusted threshold: Monday 7 AM: 790K ±5% (from 900K)
```

#### DataHub Integration Points

The Predictive SLA engine is a **read** consumer. It queries timeseries profiles and lineage to detect anomalies before SLA breaches:

| Monitoring Step | DataHub Aspect | REST API Path | What It Returns |
|----------------|---------------|---------------|----------------|
| Volume tracking | `datasetProfile` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | `rowCount` over time — basis for 3σ deviation |
| Freshness check | `operation` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | `lastUpdatedTimestamp` — expected vs actual |
| Upstream dependency | `upstreamLineage` | `GET /aspects/{urn}?aspect=upstreamLineage` | Upstream dataset URNs for root cause traversal |
| Downstream impact | — | GraphQL: `searchAcrossLineage` | Dashboards/consumers affected by SLA miss |

```python
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.metadata.schema_classes import (
    DatasetProfileClass,
    UpstreamLineageClass,
)

graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))
dataset_urn = make_dataset_urn(platform="oracle", name="orders.daily_fulfillment_summary", env="PROD")

# Profile history — rowCount over time for 3σ anomaly detection
# REST: POST /aspects?action=getTimeseriesAspectValues
profiles = graph.get_timeseries_values(
    dataset_urn, DatasetProfileClass, filter={}, limit=30,
)

# Upstream lineage — traverse dependencies for root cause analysis
# REST: GET /aspects/{urn}?aspect=upstreamLineage
upstream = graph.get_aspect(dataset_urn, UpstreamLineageClass)
```

> **Key point**: DataHub stores raw profile history and lineage graphs. DataSpoke adds statistical modeling, SLA definitions, and predictive alerting on top.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **Prophet/Isolation Forest Engine** | Time-series anomaly detection on `rowCount` history | DataHub stores profiles, no statistical modeling |
| **SLA Configuration** | Define per-dataset SLA targets (e.g., 9 AM deadline) | DataHub has no SLA concept |
| **Upstream Root Cause Analyzer** | Traverse lineage, check each upstream's health, identify bottleneck | DataHub provides lineage graph but no health assessment |
| **Predictive Alert System** | Generate pre-breach warnings with confidence scores | DataHub has no alerting/prediction engine |
| **Threshold Auto-Adjustment** | Learn day-of-week patterns, auto-update baselines | DataHub stores raw data, no pattern learning |

#### Outcome

| Metric | Traditional Monitoring | DataSpoke Predictive |
|--------|----------------------|----------------------|
| Detection Time | 9:00 AM (breach) | 7:00 AM (pre-breach) |
| Response Window | 0 min (already late) | 120 min (proactive) |
| Business Impact | 2.5hr dashboard downtime | Zero downtime |
| Root Cause ID | 90 min investigation | 2 min (auto-analyzed) |

---

### Use Case 4: Doc Suggestions — Post-Acquisition Ontology Reconciliation

**Feature**: Automated Documentation Suggestions (taxonomy/ontology proposals)

#### Scenario: Imazon Acquires "eBookNow" Digital Startup

**Background:**
Imazon acquires eBookNow, a digital-only book platform. Post-merger, the combined DataHub catalog has 700+ datasets — 200 from eBookNow — with overlapping concepts. Six tables represent the idea of "a book/product" differently across the two companies. The data governance team cannot manually audit 700 datasets.

#### Without DataSpoke

```
Concept: "Book / Product"

Imazon (legacy):
  - catalog.title_master          → isbn, title, author_id, list_price
  - catalog.editions              → edition_id, isbn, format, pub_date
  - inventory.book_stock          → isbn, warehouse_id, qty_on_hand

eBookNow (acquired):
  - products.digital_catalog      → product_id, title, creator, price_usd
  - content.ebook_assets          → asset_id, product_ref, file_format
  - storefront.listing_items      → listing_id, item_name, seller_price

Problems:
  ✗ 6 tables represent "Book/Product" with different schemas and naming
  ✗ No documented relationship between isbn and product_id
  ✗ Downstream pipelines join across them inconsistently
  ✗ Recommendation engine double-counts titles available in both print and digital
```

#### With DataSpoke

**Phase 1: Semantic Clustering**

```
DataSpoke Doc Suggestions — Semantic Clustering:

Analyzed: 700 datasets
Semantic clusters detected: 38
Clusters with conflicts: 9

Cluster: BOOK / PRODUCT (Critical)
6 tables detected representing the same concept

Similarity Matrix (embedding cosine distance):
  catalog.title_master   ←→ products.digital_catalog    0.93
  catalog.editions       ←→ content.ebook_assets         0.90
  inventory.book_stock   ←→ storefront.listing_items     0.86

Evidence:
  - All 6 contain title-like fields (100% semantic match)
  - All 6 contain a price field (95% match)
  - Overlapping downstream lineage: 18 shared consumers
  - Sample record overlap (estimated): 72% by ISBN/title match
```

**Phase 2: Ontology Proposal**

```
Proposed Canonical Entity: catalog.product_master

Fields (merged schema):
  - product_id          (surrogate key, new)
  - isbn                (nullable — digital-only titles lack ISBN)
  - title               (normalized)
  - format              (enum: print | ebook | audiobook)
  - source_system       ("imazon" | "ebooknow")
  - legacy_isbn         (maps to catalog.title_master.isbn)
  - legacy_product_id   (maps to products.digital_catalog.product_id)
  - list_price          (normalized to USD)
  - publication_date

Proposed Table Roles:
  catalog.product_master        → NEW canonical SSOT
  catalog.title_master          → Print view (keep, alias to canonical)
  catalog.editions              → Edition detail view (keep)
  products.digital_catalog      → Deprecated → migrate to canonical
  content.ebook_assets          → Digital asset view (keep)
  inventory.book_stock          → Inventory view (keep)
  storefront.listing_items      → Deprecated → migrate to canonical

Consistency Rules:
  R1. New pipelines MUST join on catalog.product_master
  R2. title normalized: TRIM + title-case
  R3. product_id immutable once assigned
  R4. source_system tag required on all book-originating events

Impact: 18 pipelines need update | Effort: Medium (schema additive)
```

**Phase 3: Weekly Consistency Check** — DataSpoke scans for rule violations. Example: a new pipeline joins on `products.digital_catalog` instead of `catalog.product_master`, excluding 60% of print-only titles from recommendations. Auto-correction proposed with 92% confidence.

#### DataHub Integration Points

Doc Suggestions is a **read + write** consumer. It reads schemas and properties for clustering analysis, then writes deprecation markers and tags back to DataHub:

| Analysis Step | DataHub Aspect | REST API Path | What It Returns / Stores |
|--------------|---------------|---------------|--------------------------|
| Schema similarity | `schemaMetadata` | `GET /aspects/{urn}?aspect=schemaMetadata` | Column names, types — input to embedding similarity |
| Description analysis | `datasetProperties` | `GET /aspects/{urn}?aspect=datasetProperties` | Descriptions for semantic matching |
| Shared consumers | `upstreamLineage` | GraphQL: `searchAcrossLineage` | Downstream overlap across candidate tables |
| Mark deprecated | `deprecation` | `POST /openapi/v3/entity/dataset` | `deprecated=true`, `note`, `replacement` URN |
| Tag source system | `globalTags` | `POST /openapi/v3/entity/dataset` | `urn:li:tag:source_imazon`, `urn:li:tag:source_ebooknow` |

```python
from datahub.emitter.rest_emitter import DatahubRestEmitter
from datahub.emitter.mcp import MetadataChangeProposalWrapper
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
from datahub.metadata.schema_classes import (
    DeprecationClass,
    SchemaMetadataClass,
)

graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))
emitter = DatahubRestEmitter(gms_server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN)

# Read schema — column names and types for embedding-based similarity
# REST: GET /aspects/{urn}?aspect=schemaMetadata
imazon_urn = make_dataset_urn(platform="oracle", name="catalog.title_master", env="PROD")
schema = graph.get_aspect(imazon_urn, SchemaMetadataClass)

# Mark deprecated — old eBookNow table replaced by canonical entity
# REST: POST /openapi/v3/entity/dataset  (aspect: deprecation)
ebooknow_urn = make_dataset_urn(platform="oracle", name="products.digital_catalog", env="PROD")
emitter.emit_mcp(MetadataChangeProposalWrapper(
    entityUrn=ebooknow_urn,
    aspect=DeprecationClass(
        deprecated=True,
        note="Migrated to catalog.product_master per ontology reconciliation",
        replacement=make_dataset_urn(platform="oracle", name="catalog.product_master", env="PROD"),
    ),
))
```

> **Key point**: DataHub persists schema metadata and deprecation markers. DataSpoke adds embedding-based clustering, ontology proposal logic, and consistency rule enforcement.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **Embedding-Based Clustering** | Generate column/description embeddings, compute cosine similarity matrices via Qdrant | DataHub has keyword search only, no vector similarity |
| **Ontology Proposal Engine** | Propose canonical entities with merged schemas and table role assignments | DataHub stores metadata but has no schema merging logic |
| **Consistency Rule Engine** | Define and enforce ontology rules (R1–R4), scan for violations weekly | DataHub has no rule definition or violation scanning |
| **Auto-Correction Proposer** | Suggest SQL join replacements with confidence scores | DataHub has no code-level analysis capability |

#### Outcome

| Metric | Manual Reconciliation | DataSpoke Doc Suggestions |
|--------|----------------------|---------------------------|
| Time to proposal | ~3 months (manual audit) | Hours (automated clustering) |
| Catalog AI-readiness | 58% | 91% |
| Ongoing violations/month | Untracked | 2–3 (auto-detected) |

---

## Data Analysis (DA) Group

### Use Case 5: NL Search — GDPR Compliance Audit

**Feature**: Natural Language Search

#### Scenario: Legal Team Searches for European Customer PII Used by Marketing

**Background:**
Imazon's Legal team is preparing for a GDPR audit and asks: "Find all tables containing European customer PII that are accessed by marketing analytics pipelines." This requires cross-referencing PII classification, geographic scope, and lineage — a multi-dimensional query that keyword search cannot handle.

#### Without DataSpoke

Manual process: search DataHub for "customer" tables, check each description for "EU"/"Europe", grep column names for `email`/`name`/`address`, manually trace lineage to marketing consumers, review 50+ tables. **Time: 4–6 hours. Accuracy: ~70%** (depends on documentation quality).

#### With DataSpoke

**Query:**

```
Natural Language Input (via /api/v1/spoke/da/search):
"Find tables with European customer PII used by marketing analytics"
```

**Response (2.3 seconds):**

```
Found 7 Tables Matching Criteria

HIGH PRIORITY (Direct PII + Marketing Usage)

1. customers.eu_profiles (Relevance: 98%)
   PII Fields: email, full_name, shipping_address, date_of_birth
   Geographic Tag: EU/GDPR
   Marketing Lineage:
     └─ marketing.eu_email_campaigns (active)
        └─ dashboards.eu_campaign_performance
   Compliance: ✓ Retention: 2yr | ✓ Encryption: at-rest + transit
              ⚠ Right-to-deletion: manual process

2. orders.eu_purchase_history (Relevance: 94%)
   PII Fields: customer_id (linkable), shipping_address, payment_last4
   Marketing Lineage:
     └─ marketing.eu_buyer_segmentation
        └─ recommendations.eu_personalized_picks
   Compliance: ✓ Anonymization after 90 days | ✓ GDPR retention

MEDIUM PRIORITY (Derived / Pseudonymized)

3. marketing.eu_reader_segments (Relevance: 87%)
   PII Fields: hashed_email, aggregate_reading_score
   Upstream PII: customers.eu_profiles (1 hop)
   Active campaigns: 8 | Dashboard deps: 4

[... 4 more tables ...]

Summary:
  Direct PII tables: 2 | Derived PII tables: 5
  Active marketing pipelines: 11
  GDPR compliance gaps: 1 (right-to-deletion automation)
```

**Follow-up:** "Which tables lack automated right-to-deletion?" → DataSpoke identifies `customers.eu_profiles` (requires manual SQL) and `reviews.eu_book_reviews_archive` (cold storage, 48hr restore). Recommends automated deletion jobs.

#### DataHub Integration Points

NL Search is a **read** consumer. It queries multiple DataHub aspects to build the vector search index and enrich query results:

| Search Step | DataHub Aspect | REST API Path | What It Returns |
|------------|---------------|---------------|----------------|
| Embedding source | `datasetProperties` | `GET /aspects/{urn}?aspect=datasetProperties` | Descriptions — vectorized into Qdrant |
| Column-level PII detection | `schemaMetadata` | `GET /aspects/{urn}?aspect=schemaMetadata` | Column names (`email`, `full_name`, etc.) |
| PII / GDPR tags | `globalTags` | `GET /aspects/{urn}?aspect=globalTags` | `urn:li:tag:PII`, `urn:li:tag:GDPR` |
| Marketing lineage | `upstreamLineage` | GraphQL: `searchAcrossLineage` | Downstream consumers in marketing domain |
| Ownership | `ownership` | `GET /aspects/{urn}?aspect=ownership` | Data steward for compliance contact |
| Usage frequency | `datasetUsageStatistics` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | `uniqueUserCount`, `totalSqlQueries` |

```python
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.metadata.schema_classes import (
    DatasetUsageStatisticsClass,
    GlobalTagsClass,
)

graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))
dataset_urn = make_dataset_urn(platform="oracle", name="customers.eu_profiles", env="PROD")

# PII tags — check for GDPR-relevant classification tags
# REST: GET /aspects/{urn}?aspect=globalTags
tags = graph.get_aspect(dataset_urn, GlobalTagsClass)

# Downstream lineage — find marketing consumers via GraphQL
# GraphQL: searchAcrossLineage(input: {urn, direction: DOWNSTREAM, types: [DATASET]})
downstream = graph.execute_graphql("""
    query {
        searchAcrossLineage(input: {
            urn: "%s",
            direction: DOWNSTREAM,
            types: [DATASET],
            query: "*marketing*"
        }) { searchResults { entity { urn } } }
    }
""" % dataset_urn)

# Usage statistics — prioritize high-traffic tables in search results
# REST: POST /aspects?action=getTimeseriesAspectValues
usage = graph.get_timeseries_values(
    dataset_urn, DatasetUsageStatisticsClass, filter={}, limit=30,
)
```

> **Key point**: DataHub provides keyword search and raw metadata. DataSpoke adds natural language parsing, vector similarity, PII classification logic, and conversational refinement.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **NL Query Parser** | Parse natural language into structured intent (entity type, filters, compliance context) | DataHub search is keyword-based, no intent parsing |
| **Vector Search (Qdrant)** | Hybrid search: vector similarity + graph traversal for multi-dimensional queries | DataHub has Elasticsearch keyword search only |
| **PII Classification Engine** | Detect PII fields by column name patterns + tag presence, classify into tiers | DataHub stores tags but has no classification logic |
| **Compliance Report Generator** | Auto-generate GDPR audit reports with lineage diagrams and gap analysis | DataHub provides raw metadata, no report generation |
| **Conversational Refinement** | Support follow-up queries in context ("Which tables lack...") | DataHub search is stateless, no conversation support |

#### Outcome

| Metric | Traditional Search | DataSpoke NL Search |
|--------|-------------------|---------------------|
| Time | 4–6 hours | 2–5 minutes |
| Accuracy | ~70% | ~98% |
| Follow-up queries | Start over | Conversational refinement |
| Audit report | Manual creation | Auto-generated |

---

## Data Governance (DG) Group

### Use Case 6: Metrics Dashboard — Enterprise Metadata Health

**Feature**: Enterprise Metrics Time-Series Monitoring

#### Scenario: CDO Launches Metadata Health Initiative Across 6 Departments

**Background:**
Imazon's Chief Data Officer launches a company-wide initiative to improve data documentation and ownership accountability. Six departments manage 400+ datasets, but documentation coverage and ownership assignment vary wildly. The governance team currently runs quarterly manual audits that take 2 weeks each and produce point-in-time spreadsheets that go stale immediately.

#### Without DataSpoke

Manual audit cycle: governance team reviews tables, creates tracking spreadsheet, emails department leads, follows up in 2 weeks, repeats quarterly. **Problems:** labor-intensive (2 weeks/audit), point-in-time snapshots, no automated tracking, hard to measure improvement.

#### With DataSpoke

**Week 1 — Initial Assessment:**

```
DataSpoke Metrics Dashboard:
Enterprise Metadata Health Score: 59/100

Department Breakdown:
┌─────────────────────┬────────┬──────────┬────────┬─────────┐
│ Department          │ Score  │ Datasets │ Issues │ Trend   │
├─────────────────────┼────────┼──────────┼────────┼─────────┤
│ Engineering         │ 76/100 │ 95       │ 23     │ ↑ +3%   │
│ Data Science        │ 69/100 │ 72       │ 22     │ → 0%    │
│ Marketing           │ 54/100 │ 80       │ 37     │ ↓ -2%   │
│ Finance             │ 81/100 │ 38       │ 7      │ ↑ +5%   │
│ Operations          │ 45/100 │ 65       │ 36     │ → 0%    │
│ Publisher Relations  │ 40/100 │ 55       │ 33     │ ↓ -1%   │
└─────────────────────┴────────┴──────────┴────────┴─────────┘

Critical Issues: 42 | High: 78 | Medium: 118
```

**Detailed view — Marketing:**

```
Marketing Department — Score: 54/100 (Target: 70)

Critical (12 datasets):
  - Missing owners for high-usage tables
  - No description on marketing.campaign_metrics_daily (38 downstream users!)

Auto-generated Action Items → marketing-data-lead@imazon.com:
  Priority 1 (Due: 1 week):
  [ ] Assign owner to marketing.campaign_metrics_daily
  [ ] Add descriptions to top 5 high-usage undocumented tables
  Priority 2 (Due: 2 weeks):
  [ ] Add PII classification to customer-facing tables
  [ ] Document update frequencies for all metrics tables
```

**Week 2 — Automated Notifications** — DataSpoke emails dataset owners with specific action items, estimated fix time (~5–10 min each), and projected score impact.

**Month 1 — Progress:**

```
Enterprise Health Score: 59 → 70 (+11 points)

Most Improved: Marketing 54 → 71 (+17) — Department of the Month
  Resolved 35/37 critical issues | Avg response: 3 days (from 12)

Needs Attention: Publisher Relations 40 → 44 (+4) — below target pace
  Recommendation: Schedule 1:1 with team lead

Metrics:
  Documentation coverage: 64% → 78% (+14%)
  Owner assignment rate: 79% → 93% (+14%)
  Avg issue resolution: 4.1 days (target: 5) ✓
```

**Month 3 — Milestone:** Enterprise score reaches 77/100 (target: 70). All departments above minimum threshold. Documentation decay rate tracked at -2.1%/month (new tables created faster than documented). DataSpoke recommends mandatory documentation checklist for new table creation.

#### DataHub Integration Points

The Metrics Dashboard is a **read** consumer. It queries across all datasets to compute aggregate health scores:

| Health Metric | DataHub Aspect | REST API Path | What It Returns |
|--------------|---------------|---------------|----------------|
| Description coverage | `datasetProperties` | `GET /aspects/{urn}?aspect=datasetProperties` | Presence/absence of `description` field |
| Owner assignment | `ownership` | `GET /aspects/{urn}?aspect=ownership` | Owner URN list — empty = unassigned |
| Column documentation | `schemaMetadata` | `GET /aspects/{urn}?aspect=schemaMetadata` | Per-column `description` — empty = undocumented |
| Tag coverage | `globalTags` | `GET /aspects/{urn}?aspect=globalTags` | PII classification tags present or missing |
| Usage popularity | `datasetUsageStatistics` (timeseries) | `POST /aspects?action=getTimeseriesAspectValues` | `uniqueUserCount` — prioritize high-usage gaps |
| Entity enumeration | — | GraphQL: `scrollAcrossEntities` | List all datasets per domain/department |

```python
from datahub.ingestion.graph.client import DataHubGraph, DatahubClientConfig
from datahub.emitter.mce_builder import make_dataset_urn
from datahub.metadata.schema_classes import (
    DatasetPropertiesClass,
    OwnershipClass,
)

graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))

# Enumerate all datasets — iterate for health scoring
# GraphQL: scrollAcrossEntities or REST filter
dataset_urns = list(graph.get_urns_by_filter(entity_types=["dataset"]))

for dataset_urn in dataset_urns:
    # Ownership — check if owner is assigned
    # REST: GET /aspects/{urn}?aspect=ownership
    ownership = graph.get_aspect(dataset_urn, OwnershipClass)

    # Description — check documentation coverage
    # REST: GET /aspects/{urn}?aspect=datasetProperties
    properties = graph.get_aspect(dataset_urn, DatasetPropertiesClass)
```

> **Key point**: DataHub stores per-dataset metadata aspects. DataSpoke aggregates them into cross-dataset health scores, department rankings, and trend analysis.

#### DataSpoke Custom Implementation

| Component | Responsibility | Why DataHub Can't Do This |
|-----------|---------------|--------------------------|
| **Health Score Aggregator** | Compute 0–100 score from description, ownership, tags, column docs, freshness | DataHub has no cross-aspect scoring system |
| **Department Mapper** | Map datasets to departments via ownership → HR API lookup | DataHub stores ownership URNs but has no org-structure awareness |
| **Issue Tracker** | Detect, prioritize, and track metadata gaps (critical/high/medium) in PostgreSQL | DataHub has no issue lifecycle management |
| **Notification Engine** | Email dataset owners with action items, estimated fix time, projected score impact | DataHub has no outbound notification system |
| **Trend Analysis** | Track health scores over time, compute decay rates, forecast improvement | DataHub stores point-in-time aspects, no time-series aggregation of metadata quality |

#### Outcome

| Metric | Quarterly Manual Audit | DataSpoke Metrics Dashboard |
|--------|----------------------|----------------------------|
| Audit cycle | 2 weeks, quarterly | Real-time, continuous |
| Issue response time | 12 days avg | 3 days avg |
| Health score improvement | Unmeasured | 59 → 77 in 3 months |
| Governance team effort | 100% manual | 80% reduction |

---

## Summary: Value Delivered

| Use Case | User Group | Feature | Traditional Approach | With DataSpoke | Improvement |
|----------|-----------|---------|---------------------|----------------|-------------|
| **Legacy Book Catalog Enrichment** | DE | Deep Ingestion | Manual metadata entry, no lineage | Automated multi-source enrichment | 89% enrichment, 210 lineage edges |
| **Recommendation Pipeline Verification** | DE / DA | Online Validator | ~30% failure rate from bad data | <5% failure with pre-verification | 83% reduction in incidents |
| **Fulfillment SLA Early Warning** | DE | Online Validator | Reactive alerts after breach | Predictive warnings 2+ hours early | Zero SLA breaches |
| **Post-Acquisition Ontology** | DE | Doc Suggestions | 3-month manual reconciliation | Automated proposal in hours | Orders-of-magnitude faster |
| **GDPR Compliance Audit** | DA | NL Search | 4–6 hours manual search | 2–5 minutes automated | 98% time savings |
| **Enterprise Metadata Health** | DG | Metrics Dashboard | Quarterly manual audits | Real-time continuous monitoring | 80% efficiency gain |

**Cross-cutting Benefits:**
- **AI-Ready:** Enables autonomous agents to work safely with Imazon's production data
- **Real-time Intelligence:** Shifts from reactive to proactive data management
- **Context-Aware:** Understands data relationships and business meaning across all departments
- **Measurable Impact:** Quantifiable improvements in quality, compliance, and efficiency
- **Ontology Health:** Catalog remains semantically consistent through acquisitions and organic growth
