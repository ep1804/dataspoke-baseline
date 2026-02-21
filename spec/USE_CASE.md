# DataSpoke: Detailed Use Case Scenarios

> **Note on Document Purpose**
> This document presents conceptual scenarios for ideation and vision alignment. These use cases illustrate the intended capabilities and value propositions of DataSpoke, but are not implementation specifications or technical requirements. The scenarios demonstrate aspirational workflows to guide product development and stakeholder discussions. Actual implementation details, technical architecture, and feature prioritization will be defined in separate technical specification documents.

This document provides detailed, real-world scenarios demonstrating how DataSpoke enhances DataHub capabilities across its three user groups: **Data Engineering (DE)**, **Data Analysis (DA)**, and **Data Governance (DG)**.

---

## Feature Mapping

| Use Case | User Group | Feature |
|----------|-----------|---------|
| [Use Case 1: Deep Ingestion — Legacy System Metadata Integration](#use-case-1-deep-ingestion--legacy-system-metadata-integration) | DE | Deep Technical Spec Ingestion |
| [Use Case 2: Online Validator — AI Pipeline Context Verification](#use-case-2-online-validator--ai-pipeline-context-verification) | DE / DA | Online Data Validator |
| [Use Case 3: Online Validator — Predictive SLA Management](#use-case-3-online-validator--predictive-sla-management) | DE | Online Data Validator |
| [Use Case 4: Doc Suggestions — AI-Driven Ontology Design](#use-case-4-doc-suggestions--ai-driven-ontology-design) | DE | Automated Documentation Suggestions |
| [Use Case 5: NL Search — Semantic Data Discovery](#use-case-5-nl-search--semantic-data-discovery) | DA | Natural Language Search |
| [Use Case 6: Metrics Dashboard — Metadata Health Monitoring](#use-case-6-metrics-dashboard--metadata-health-monitoring) | DG | Enterprise Metrics Time-Series Monitoring |

---

## Data Engineering (DE) Group

### Use Case 1: Deep Ingestion — Legacy System Metadata Integration

**Feature**: Deep Technical Spec Ingestion

#### Scenario: Ingesting Metadata from a Legacy Oracle Data Warehouse

**Background:**
A financial services company has a 15-year-old Oracle data warehouse containing 200+ critical tables and stored procedures that power regulatory reporting. This legacy system predates DataHub adoption and uses custom documentation stored in Confluence pages, Excel spreadsheets, and tribal knowledge. Standard DataHub connectors can extract basic schema information but miss critical business context, data lineage from stored procedures, and custom data quality rules embedded in application logic.

#### Traditional DataHub Connector Limitations

```
Standard Oracle Connector Output:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Schema extracted: 200 tables
✓ Column types: Captured
✓ Primary keys: Detected

✗ Business descriptions: Missing (stored in Confluence)
✗ Data quality rules: Missing (embedded in PL/SQL)
✗ Stored procedure lineage: Not supported
✗ Regulatory tags: Missing (tracked in Excel)
✗ Update schedules: Missing (managed by legacy scheduler)
✗ Data owners: Missing (HR system)

Result: 200 tables in DataHub with technical metadata only
Impact: Data consumers cannot determine which tables are safe to use
```

#### DataSpoke Custom Ingestion Solution

**Step 1: Register Ingestion Configuration**

```python
# Data engineer registers a custom ingestion config via DataSpoke UI
# or API: POST /api/v1/spoke/de/ingestion/configs

dataspoke.ingestion.register_config({
  "name": "oracle_legacy_warehouse_enriched",
  "source_type": "oracle",
  "schedule": "0 2 * * *",  # Daily at 2 AM

  "connection": {
    "host": "legacy-oracle-prod.company.internal",
    "port": 1521,
    "service": "DWPROD",
    "credential_ref": "vault://oracle/dwprod"
  },

  "enrichment_sources": [
    {
      "type": "confluence",
      "space": "DATA_DICTIONARY",
      "page_prefix": "Table: ",
      "fields_mapping": {
        "description": "confluence.content.body",
        "business_owner": "confluence.labels.owner",
        "pii_classification": "confluence.labels.pii"
      }
    },
    {
      "type": "excel",
      "path": "s3://company-docs/data-catalog/regulatory-tags.xlsx",
      "sheet": "Table Classifications",
      "key_column": "table_name",
      "fields_mapping": {
        "regulatory_domain": "Domain",
        "retention_years": "Retention",
        "sox_compliant": "SOX_Flag"
      }
    },
    {
      "type": "custom_api",
      "endpoint": "https://hr-api.company.internal/data-owners",
      "auth": "bearer_token",
      "fields_mapping": {
        "owner_email": "$.owner.email",
        "owner_team": "$.owner.department"
      }
    }
  ],

  "custom_extractors": [
    {
      "name": "plsql_lineage_parser",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_lineage",
      "function": "extract_stored_proc_lineage",
      "params": {
        "parse_insert_select": true,
        "parse_merge_statements": true
      }
    },
    {
      "name": "quality_rule_extractor",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_quality",
      "function": "extract_check_constraints_as_rules"
    }
  ],

  "orchestration": {
    "retry_policy": {
      "max_attempts": 3,
      "backoff_seconds": 300
    },
    "notification": {
      "on_failure": ["data-platform@company.com"],
      "on_success_after_failure": ["data-platform@company.com"]
    },
    "monitoring": {
      "track_row_counts": true,
      "alert_on_schema_change": true
    }
  }
})
```

**Response:**
```json
{
  "config_id": "ing_oracle_001",
  "status": "registered",
  "next_run": "2024-02-10T02:00:00Z",
  "validation": {
    "connection_test": "passed",
    "confluence_access": "passed",
    "excel_file_readable": "passed",
    "hr_api_accessible": "passed",
    "custom_extractors_loaded": "passed"
  }
}
```

**Step 2: Python-Based Custom Extractor Implementation**

```python
# dataspoke/custom/oracle_lineage.py
# Custom extractor for parsing stored procedure lineage

from typing import List, Dict
import sqlparse
from dataspoke.ingestion import CustomExtractor, LineageEdge

class OraclePLSQLLineageExtractor(CustomExtractor):
    """
    Extracts data lineage from Oracle PL/SQL stored procedures.
    Standard DataHub Oracle connector doesn't parse procedural code.
    """

    def extract_stored_proc_lineage(
        self,
        procedure_name: str,
        procedure_body: str,
        params: Dict
    ) -> List[LineageEdge]:
        """
        Parse PL/SQL to extract INSERT...SELECT and MERGE lineage
        """
        lineage_edges = []

        # Parse SQL statements from procedure body
        statements = sqlparse.parse(procedure_body)

        for stmt in statements:
            # Detect INSERT...SELECT patterns
            if self._is_insert_select(stmt):
                source_tables = self._extract_source_tables(stmt)
                target_table = self._extract_target_table(stmt)

                for source in source_tables:
                    lineage_edges.append(LineageEdge(
                        source_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{source},PROD)",
                        target_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{target_table},PROD)",
                        transformation_type="stored_procedure",
                        transformation_logic=procedure_name,
                        confidence_score=0.95
                    ))

            # Detect MERGE statements
            if self._is_merge(stmt):
                # Similar parsing logic for MERGE...
                pass

        return lineage_edges

    def _extract_source_tables(self, stmt) -> List[str]:
        """Extract source table references from FROM and JOIN clauses"""
        # Implementation using sqlparse AST traversal
        # Handles aliases, subqueries, CTEs
        ...

    def _extract_target_table(self, stmt) -> str:
        """Extract target table from INSERT or MERGE"""
        ...
```

**Step 3: First Ingestion Run — Enriched Metadata**

```
DataSpoke Ingestion Run: oracle_legacy_warehouse_enriched
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run ID: run_20240210_020015
Start: 2024-02-10 02:00:15
Status: IN_PROGRESS

Phase 1: Base Schema Extraction
  ✓ Connected to Oracle DWPROD
  ✓ Extracted 200 tables
  ✓ Extracted 1,847 columns
  ✓ Extracted 45 stored procedures
  Duration: 3m 22s

Phase 2: Enrichment — Confluence Documentation
  ✓ Connected to Confluence space DATA_DICTIONARY
  ✓ Found 182/200 matching documentation pages
  ✓ Extracted business descriptions: 182 tables
  ✓ Extracted PII tags: 67 tables
  ✓ Extracted owner labels: 154 tables
  Warnings: 18 tables missing Confluence docs
  Duration: 1m 45s

Phase 3: Enrichment — Regulatory Excel Mapping
  ✓ Downloaded s3://company-docs/data-catalog/regulatory-tags.xlsx
  ✓ Matched 200/200 tables by name
  ✓ Applied regulatory domains: 200 tables
  ✓ Applied retention policies: 200 tables
  ✓ Applied SOX compliance flags: 89 tables
  Duration: 24s

Phase 4: Enrichment — HR API Ownership
  ✓ Connected to HR API
  ✓ Resolved owners for 154 tables (from Confluence tags)
  ✓ Mapped to email addresses: 154/154
  ✓ Mapped to teams/departments: 154/154
  Warnings: 46 tables have no owner assigned
  Duration: 42s

Phase 5: Custom Extraction — PL/SQL Lineage
  ✓ Loaded custom extractor: plsql_lineage_parser
  ✓ Parsed 45 stored procedures
  ✓ Detected INSERT...SELECT patterns: 38 procedures
  ✓ Detected MERGE statements: 12 procedures
  ✓ Generated lineage edges: 127 edges
  ✓ Average confidence score: 0.93
  Duration: 2m 18s

Phase 6: Custom Extraction — Quality Rules
  ✓ Loaded custom extractor: quality_rule_extractor
  ✓ Extracted CHECK constraints: 234 rules
  ✓ Converted to DataSpoke quality rules: 234/234
  ✓ Applied to DataHub as quality aspects
  Duration: 1m 05s

Phase 7: DataHub Ingestion
  ✓ Generated DataHub MCE events: 200 datasets
  ✓ Emitted to DataHub GMS
  ✓ Updated vector index for semantic search
  ✓ Triggered health score recalculation
  Duration: 1m 12s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INGESTION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Duration: 10m 48s
Tables Ingested: 200
Enrichment Coverage: 91%
Lineage Edges Added: 127
Quality Rules Added: 234

Warnings: 18 tables missing Confluence docs, 46 tables missing owners
[View Detailed Report] [Schedule Next Run] [Configure Alerts]
```

**Step 4: Resulting DataHub Metadata — Enriched Entry Example**

```yaml
Dataset: regulatory_reports.monthly_capital_requirements
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Base Schema (Standard Oracle Connector)
Platform: Oracle
Database: DWPROD
Schema: regulatory_reports
Table: monthly_capital_requirements
Columns: 47
Primary Key: report_month, entity_id

# Enriched — Business Context (from Confluence)
Description: |
  Monthly regulatory capital calculation for all banking entities.
  Used for Basel III reporting to federal regulators.
  Data aggregated from daily risk positions and validated against
  general ledger.

# Enriched — Ownership (from Confluence + HR API)
Owner: sarah.chen@company.com
Team: Risk & Compliance Analytics
Contact: Slack: #team-risk-analytics

# Enriched — Regulatory Classification (from Excel)
Regulatory Domain: Basel III Capital Adequacy
Retention Period: 7 years
SOX Compliant: Yes
Audit Frequency: Quarterly
Regulatory Body: Federal Reserve / OCC

# Enriched — Lineage (from PL/SQL Parser)
Upstream (Generated by Stored Procedure):
  ├─ risk_positions.daily_var_calculations
  ├─ general_ledger.tier1_capital_summary
  ├─ exposures.counterparty_risk_weighted_assets
  └─ reference.basel_risk_weights

  Generated By: PROC_CALCULATE_MONTHLY_CAPITAL (stored procedure)
  Transformation: Aggregates daily risk positions, applies Basel III
                  formulas, cross-validates with GL

Downstream:
  ├─ reports.regulatory_filing_fed_reserve
  └─ dashboards.capital_adequacy_executive

# Enriched — Quality Rules (from CHECK Constraints)
Quality Rules (Auto-extracted):
  1. total_capital_ratio >= 0.08  (Basel minimum)
  2. report_month = LAST_DAY(report_month)  (month-end dates only)
  3. tier1_capital IS NOT NULL
  4. entity_id IN (SELECT entity_id FROM entities.active_banks)

# Operational Metadata
Last Updated: 2024-02-09 23:45:12
Update Schedule: Monthly (5th business day)
Freshness SLA: T+5 business days
Data Volume: ~50 rows/month (one per entity)
```

**Step 5: Continuous Orchestration & Monitoring**

```
DataSpoke Ingestion Dashboard:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configuration: oracle_legacy_warehouse_enriched
Status: Active
Schedule: Daily 02:00 AM UTC

Last 7 Runs:
┌────────────┬──────────┬──────────┬─────────────┬──────────┐
│ Date       │ Status   │ Duration │ Tables      │ Warnings │
├────────────┼──────────┼──────────┼─────────────┼──────────┤
│ 2024-02-10 │ ✓ Success│ 10m 48s  │ 200/200     │ 18       │
│ 2024-02-09 │ ✓ Success│ 10m 52s  │ 200/200     │ 18       │
│ 2024-02-08 │ ✓ Success│ 10m 41s  │ 200/200     │ 19       │
│ 2024-02-07 │ ⚠ Warning│ 11m 15s  │ 200/200     │ 22       │
│ 2024-02-06 │ ✓ Success│ 10m 38s  │ 200/200     │ 18       │
│ 2024-02-05 │ ✓ Success│ 10m 44s  │ 200/200     │ 17       │
│ 2024-02-04 │ ✗ Failed │ 3m 12s   │ 0/200       │ N/A      │
└────────────┴──────────┴──────────┴─────────────┴──────────┘

Failure Detail (2024-02-04):
  Phase: Enrichment — Confluence Documentation
  Error: Connection timeout to confluence.company.internal
  Action Taken: Auto-retry succeeded on attempt 2
  Resolution: Transient network issue

Health Metrics:
  Enrichment Coverage Trend: 91% (stable)
  Avg Run Duration: 10m 45s
  Success Rate (30d): 96.7%
  Tables Missing Docs: 18 (tracked)
  Tables Missing Owners: 46 (decreasing from 52 last month)
```

**Outcome:**

| Aspect | Standard DataHub Connector | DataSpoke Deep Ingestion |
|--------|---------------------------|---------------------------|
| Schema Coverage | 200 tables | 200 tables |
| Business Descriptions | 0% | 91% (182/200) |
| Ownership Information | 0% | 77% (154/200) |
| Regulatory Tags | 0% | 100% (200/200) |
| Stored Proc Lineage | Not supported | 127 edges extracted |
| Quality Rules | Manual entry only | 234 auto-extracted |
| Update Frequency | Manual re-run | Automated daily |

---

### Use Case 2: Online Validator — AI Pipeline Context Verification

**Feature**: Online Data Validator (shared with DA group)

#### Scenario: Building a Customer Churn Prediction Pipeline

**Background:**
A data scientist requests an AI Agent to create a new pipeline: "Build a daily customer churn prediction pipeline using user activity and payment data."

#### Without DataSpoke
The AI Agent would:
1. Search DataHub for "user" and "payment" tables
2. Select tables based on naming conventions alone
3. Generate code without understanding data quality or usage patterns
4. Deploy a pipeline that might use deprecated or unreliable data sources

#### With DataSpoke

**Step 1: Semantic Discovery**
```
AI Agent Query: "Find user activity and payment tables suitable for ML training"

DataSpoke Response (via /api/v1/spoke/de/validator):
- users.activity_events (✓ High Quality Score: 95)
  - Last refreshed: 2 hours ago
  - Data completeness: 99.8%
  - Usage: 45 downstream consumers

- users.activity_logs (⚠ Quality Issues Detected)
  - Anomaly: 30% drop in row count since yesterday
  - Missing field rate increased to 15%
  - Recommendation: Avoid until investigation complete

- payments.transactions (✓ Recommended)
  - SLA: 99.9% on-time delivery
  - Documentation coverage: 100%
  - Certified for ML use
```

**Step 2: Context Verification**
```python
# AI Agent calls the Online Validator API
# POST /api/v1/spoke/de/validator/context
dataspoke.validator.verify_context("users.activity_logs")

Response:
{
  "status": "degraded",
  "quality_issues": [
    {
      "type": "volume_anomaly",
      "detected_at": "2024-02-09T08:30:00Z",
      "severity": "high",
      "message": "Daily row count dropped from 5M to 3.5M",
      "recommendation": "Use users.activity_events instead"
    }
  ],
  "alternative_entities": ["users.activity_events"],
  "blocking_issues": ["ongoing_investigation"]
}
```

**Step 3: Autonomous Validation**
Before deployment, DataSpoke validates the generated pipeline:

```yaml
Pipeline: customer_churn_prediction_v1
Author: AI Agent (claude-sonnet-4.5)

Validation Results:
✓ Documentation:
  - Description: Present and comprehensive
  - Owner: Assigned to data-science-team
  - Business context: Explained

✓ Naming Convention:
  - Table name: customer_churn_features (follows standard)
  - Column names: snake_case (compliant)

✓ Quality Checks:
  - NULL handling: Implemented
  - Schema evolution: Backward compatible

✓ Lineage Impact:
  - Upstream dependencies: 2 tables (both healthy)
  - Downstream impact: None (new pipeline)
  - Circular dependency: None detected

⚠ Recommendations:
  - Consider adding data freshness check
  - Suggest implementing monitoring alert
```

**Step 4: Deployment with Confidence**
The AI Agent deploys the pipeline with verified data sources, compliant code structure, automated quality checks, and complete documentation.

**Outcome:**
- Zero production incidents from data quality issues
- 80% reduction in human review time
- Immediate integration with existing monitoring

---

### Use Case 3: Online Validator — Predictive SLA Management

**Feature**: Online Data Validator (time-series monitoring)

#### Scenario: E-commerce Order Processing Pipeline

**Background:**
A critical `orders.daily_summary` table powers real-time dashboards for business operations. The pipeline typically processes 2-3M rows daily by 9 AM.

#### Traditional Monitoring Approach
```
Alert: orders.daily_summary is empty at 9:00 AM
Status: SLA BREACH - Business dashboard down
Response: Manual investigation required
```

#### DataSpoke Predictive Approach

**Day 1 - Monday 7:00 AM: Early Warning**
```
DataSpoke Alert (Predictive):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ Anomaly Detection: orders.daily_summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Model: Prophet Time Series Analysis
Confidence: 89%

Observation:
  Current volume at 7:00 AM: 450K rows
  Expected volume (Mon 7AM): 1.2M rows ±5%
  Deviation: -62% (outside 3σ threshold)

Historical Pattern:
  Mon 7AM avg (last 8 weeks): 1.18M rows
  Mon 9AM completion rate: 98.5%

Prediction:
  Likely to miss 9AM SLA by 1.5 hours
  Expected completion: 10:30 AM

Upstream Analysis:
  orders.raw_events:
    ✓ Normal volume (2.8M rows at 6:30 AM)
  orders.payment_status:
    ⚠ Delayed by 30 minutes (unusual)
    └─ Dependency: payment_gateway_api.transactions
       └─ Issue: API rate limit exceeded

Root Cause (Likely):
  Payment gateway API throttling affecting upstream join

Recommended Actions:
  1. Check payment_gateway_api rate limits
  2. Contact payment team about API quota
  3. Consider temporary bypass using cached data

Impact:
  Affected Dashboards: 3
  - Executive Sales Dashboard (15 viewers)
  - Operations Real-time Monitor (8 viewers)
  - Finance Daily Report (auto-scheduled)
```

**7:15 AM - Proactive Response**
Engineering team receives alert and takes action:
1. Confirms payment API throttling
2. Implements temporary increased rate limit
3. Pipeline recovers by 8:00 AM
4. SLA met with 1 hour buffer

**Result Comparison:**

| Metric | Traditional Monitoring | DataSpoke Predictive |
|--------|----------------------|----------------------|
| Detection Time | 9:00 AM (breach) | 7:00 AM (pre-breach) |
| Response Window | 0 min (already late) | 120 min (proactive) |
| Business Impact | 2hr dashboard downtime | Zero downtime |
| MTTR | 90 minutes | 45 minutes |
| Root Cause ID | 60 minutes investigation | 2 minutes (auto-analyzed) |

**Week 2 - Pattern Learning**
```
DataSpoke Insight:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Weekly Pattern Analysis: orders.daily_summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Anomaly Detected (Low Severity):
  Pattern: Monday 7AM volume consistently -10% vs other weekdays
  Duration: Last 4 weeks
  Status: Not blocking SLA, but diverging from baseline

Hypothesis:
  Weekend payment processing batch delay?

Suggestion:
  Adjust Monday morning baseline expectation
  OR investigate weekend batch schedule

Auto-adjusted Threshold:
  Monday 7AM: 1.08M ±5% (updated from 1.18M)
```

---

### Use Case 4: Doc Suggestions — AI-Driven Ontology Design

**Feature**: Automated Documentation Suggestions (taxonomy/ontology proposals)

#### Scenario: Resolving Semantic Drift After a Company Acquisition

**Background:**
A fintech company acquires a smaller payments startup. Post-acquisition, the combined DataHub catalog contains 800+ datasets — 300 from the acquired company — with overlapping concepts, conflicting naming conventions, and duplicated entities. The data governance team cannot manually audit and reconcile 800 datasets.

#### The Problem: Semantic Drift at Scale
```
Before DataSpoke:

Concept: "Customer"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Legacy system (core company):
  - users.customers           → id, email, signup_date
  - crm.client_master         → client_id, contact_email, created_at
  - analytics.user_profiles   → user_uuid, email_address, registration_ts

Acquired company:
  - payments.payer_registry   → payer_ref, payer_email, onboarded_at
  - risk.account_holders      → acct_id, email, account_opened
  - kyc.verified_identities   → identity_id, email_addr, verified_date

Problems:
  ✗ 6 tables all represent "Customer" with different schemas
  ✗ No documented relationship between them
  ✗ Downstream pipelines join across them inconsistently
  ✗ AI agents cannot reliably identify the "right" customer table
  ✗ Compliance reports double-count customers
```

#### DataSpoke Documentation Suggestions: Ontology Analysis

**Phase 1: Semantic Clustering**
```
DataSpoke Doc Suggestions Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Semantic Clustering Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Analyzed: 800 datasets
Semantic clusters detected: 47
Clusters with conflicts: 12
Critical conflicts (AI agents affected): 4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cluster: CUSTOMER IDENTITY (Critical)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

6 tables detected representing the same concept:

Similarity Matrix (embedding cosine distance):
  users.customers           ←→ crm.client_master         0.94
  users.customers           ←→ analytics.user_profiles   0.91
  users.customers           ←→ payments.payer_registry   0.88
  payments.payer_registry   ←→ risk.account_holders      0.92
  risk.account_holders      ←→ kyc.verified_identities   0.89

Conflict Type: ENTITY DUPLICATION
Evidence:
  - All 6 contain email-like fields (semantic match: 100%)
  - All 6 contain a creation timestamp (semantic match: 95%)
  - Overlapping downstream lineage: 23 shared consumers
  - Sample record overlap (estimated): 78%

AI Agent Impact:
  - 12 AI-generated pipelines query ≥2 of these tables
  - 3 pipelines produce inconsistent customer counts
  - Online Validator returning warnings on 8 pipelines
```

**Phase 2: Ontology Proposal**
```
DataSpoke Doc Suggestions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proposed Ontology — CUSTOMER IDENTITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Recommendation: Define a canonical "Customer" entity

Canonical Entity (proposed):
  Name: enterprise.customer_master
  Concept: The single unified record of a customer across all systems
  Fields (merged schema):
    - customer_id          (surrogate key, new)
    - email                (normalized from 6 variants)
    - source_system        (origin: "core" | "acquired")
    - legacy_id_core       (maps to users.customers.id)
    - legacy_id_acquired   (maps to payments.payer_registry.payer_ref)
    - created_at           (earliest of all source timestamps)
    - kyc_verified         (from kyc.verified_identities)
    - risk_score           (from risk.account_holders)

Proposed Table Roles:
  ┌──────────────────────────────┬─────────────────────────────┐
  │ Table                        │ Proposed Role               │
  ├──────────────────────────────┼─────────────────────────────┤
  │ enterprise.customer_master   │ NEW — canonical SSOT        │
  │ users.customers              │ Deprecated → migrate to new │
  │ crm.client_master            │ CRM view (keep, alias only) │
  │ analytics.user_profiles      │ Analytics view (keep)       │
  │ payments.payer_registry      │ Payments system view (keep) │
  │ risk.account_holders         │ Risk view (keep)            │
  │ kyc.verified_identities      │ KYC view (keep)             │
  └──────────────────────────────┴─────────────────────────────┘

Consistency Rules (proposed):
  R1. All new pipelines MUST join on enterprise.customer_master
  R2. email field must be normalized to lowercase + stripped
  R3. customer_id is immutable once assigned
  R4. source_system tag required on all customer-originating events

Impact Assessment:
  Pipelines requiring update: 23
  Estimated migration effort: Medium (schema additive, not breaking)
  Downstream dashboard impact: 5 dashboards need customer_id added

[Approve Proposal] [Modify] [Request Human Review]
```

**Phase 3: Autonomous Consistency Check**
```
DataSpoke Doc Suggestions — Consistency Scan (Weekly):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ontology Rules Checked: 4
Violations Found: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Violation 1 — Rule R1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pipeline: ml.churn_risk_model_v3
Owner: data-science@company.com

Issue:
  This pipeline joins directly on payments.payer_registry
  instead of enterprise.customer_master

Risk:
  - Excludes ~22% of customers from the legacy core system
  - Model trained on biased population

Auto-correction Available:
  Replace: JOIN payments.payer_registry pr ON pr.payer_ref = t.id
  With:    JOIN enterprise.customer_master cm ON cm.legacy_id_acquired = t.id

Confidence: 91%
[Auto-apply Fix] [Notify Owner] [Dismiss]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Violation 2 — Rule R2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Table: analytics.email_campaign_results
Owner: marketing@company.com

Issue:
  email column contains mixed-case values ("John@ACME.com")
  Normalization rule R2 not applied at ingestion time

Risk:
  - Customer matching failures (~3% of records)
  - GDPR deletion requests may miss non-normalized records

Auto-correction Available:
  Apply: LOWER(TRIM(email)) transformation at ingestion
  Estimated affected rows: ~45,000

Confidence: 99%
[Auto-apply Fix] [Notify Owner] [Dismiss]
```

**Phase 4: Ontology Health Over Time**
```
DataSpoke Doc Suggestions — Monthly Ontology Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ontology Consistency Score: 94/100 (↑ from 61/100 at acquisition)

Active Ontology Rules: 47
Violations this month: 3 (↓ from 38 last month)
Auto-corrected: 2 (confidence > 90%)
Human review required: 1

New Semantic Drift Detected:
  Cluster: TRANSACTION
  Tables in conflict: 3 (new post-acquisition)
  Recommendation: Define canonical Transaction entity
  [Start Ontology Design]

Catalog AI-Readiness Score: 89/100
  (% of entities AI agents can safely query without validation warnings)
```

**Outcome:**
- Semantic conflicts surfaced automatically at acquisition scale
- Canonical entity definitions proposed with evidence
- Catalog AI-readiness score raised from 61% to 89%
- Continuous rule enforcement — 3 violations/month vs. 38 pre-purification
- Manual ontology audit (estimated 3 months) replaced with automated proposal in hours

---

## Data Analysis (DA) Group

### Use Case 5: NL Search — Semantic Data Discovery

**Feature**: Natural Language Search

#### Scenario: Privacy Compliance Audit

**Background:**
Legal team needs to prepare for GDPR audit and requests: "Identify all tables containing European user PII that are accessed by marketing analytics pipelines."

#### Traditional DataHub Search
```sql
-- Manual search process:
1. Search for "user" tables
2. Check each table description for "EU" or "Europe"
3. Grep column names for "email", "name", "address"
4. Check lineage manually for marketing connections
5. Review 50+ tables manually

Time Required: 4-6 hours
Accuracy: 70% (depends on documentation quality)
```

#### DataSpoke Natural Language Search

**Query:**
```
Natural Language Input (via /api/v1/spoke/da/search):
"Find tables with European user PII used by marketing analytics"
```

**DataSpoke Processing:**
```python
# Step 1: Semantic Understanding
parsed_query = {
  "intent": "data_discovery",
  "filters": {
    "data_category": ["PII", "personal_data"],
    "geographic_scope": ["EU", "Europe", "GDPR"],
    "domain": ["user_data", "customer_data"],
    "consuming_team": ["marketing", "analytics"]
  },
  "compliance_context": "GDPR"
}

# Step 2: Vector Search + Graph Traversal
results = dataspoke.search.semantic_search(
  query=parsed_query,
  search_method="hybrid",  # Vector similarity + Graph lineage
  compliance_mode=True
)
```

**Results:**
```
DataSpoke Response (Retrieved in 2.3 seconds):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Found 8 Tables Matching Criteria
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HIGH PRIORITY (Direct PII + Marketing Usage)

1. users.eu_customers_master
   Relevance Score: 98%

   PII Fields: email, full_name, phone, address, date_of_birth
   Geographic Tag: EU/GDPR
   Classification: Tier 1 - Direct Identifiers

   Marketing Lineage:
   └─ campaigns.eu_email_targeting (active)
      └─ dashboards.marketing_eu_performance

   Compliance Status:
   ✓ Retention policy: 2 years
   ✓ Encryption: At-rest + In-transit
   ⚠ Access logging: Enabled (review needed)
   ✓ Consent tracking: Linked to consent.user_preferences

2. events.eu_user_activity_log
   Relevance Score: 94%

   PII Fields: user_id (linkable), ip_address, device_id
   Classification: Tier 2 - Indirect Identifiers

   Marketing Lineage:
   └─ analytics.eu_user_segmentation
      └─ marketing.campaign_audience_builder

   Compliance Status:
   ✓ Anonymization: After 90 days
   ✓ GDPR retention: Compliant
   ⚠ Right-to-deletion: Manual process (not automated)

MEDIUM PRIORITY (Derived/Aggregated)

3. marketing.eu_customer_segments_derived
   Relevance Score: 87%

   PII Fields: hashed_email, aggregate_behavior_score
   Classification: Tier 3 - Pseudonymized

   Upstream PII Sources:
   └─ users.eu_customers_master (1 hop)
   └─ events.eu_user_activity_log (1 hop)

   Marketing Usage:
   └─ Active campaigns: 12
   └─ Dashboard dependencies: 5

   Note: Aggregated weekly, individual records not retained

[... 5 more tables ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Audit Report Generated
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary:
- Total tables: 8
- Direct PII tables: 2
- Derived PII tables: 6
- Active marketing pipelines: 15
- GDPR compliance gaps: 2 (right-to-deletion automation)

Export Options:
[Download Full Report] [Generate Lineage Diagram] [Schedule Monitoring]
```

**Follow-up Query:**
```
"Which tables don't have automated right-to-deletion?"

DataSpoke Response:
Found 2 tables requiring manual intervention:
1. events.eu_user_activity_log
   Issue: Deletion requires manual SQL script
   Recommendation: Implement automated deletion job

2. sessions.eu_web_clickstream_archive
   Issue: Cold storage (S3 Glacier) requires 48hr restore
   Recommendation: Add deletion tracking table
```

**Outcome:**
- Time saved: 4 hours to 5 minutes
- Accuracy: 70% to 98%
- Audit preparation: Automated report generation
- Continuous compliance: Scheduled monitoring enabled

---

## Data Governance (DG) Group

### Use Case 6: Metrics Dashboard — Metadata Health Monitoring

**Feature**: Enterprise Metrics Time-Series Monitoring

#### Scenario: Enterprise-wide Data Quality Initiative

**Background:**
The Chief Data Officer launches a company-wide initiative to improve data documentation and ownership accountability across 8 departments managing 500+ datasets.

#### Traditional Approach
```
Manual Audit Process:
1. Data governance team manually reviews tables
2. Creates spreadsheet tracking documentation status
3. Emails department leads with findings
4. Follows up manually after 2 weeks
5. Repeat quarterly

Problems:
- Labor intensive (2 weeks per audit)
- Point-in-time snapshot (stale immediately)
- No automated tracking
- Hard to measure improvement
```

#### DataSpoke Metrics Dashboard

**Week 1: Initial Assessment**
```
DataSpoke Metrics Dashboard:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Enterprise Metadata Health Score: 62/100
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Department Breakdown:

┌─────────────────┬────────┬────────┬────────┬──────────┐
│ Department      │ Score  │ Tables │ Issues │ Trend    │
├─────────────────┼────────┼────────┼────────┼──────────┤
│ Engineering     │ 78/100 │ 120    │ 26     │ ↑ +3%    │
│ Data Science    │ 71/100 │ 85     │ 25     │ → 0%     │
│ Marketing       │ 58/100 │ 95     │ 40     │ ↓ -2%    │
│ Finance         │ 82/100 │ 45     │ 8      │ ↑ +5%    │
│ Product         │ 55/100 │ 110    │ 50     │ ↓ -4%    │
│ Operations      │ 48/100 │ 68     │ 35     │ → 0%     │
│ Sales           │ 43/100 │ 52     │ 30     │ ↓ -1%    │
│ Support         │ 61/100 │ 35     │ 14     │ ↑ +2%    │
└─────────────────┴────────┴────────┴────────┴──────────┘

Critical Issues (Require Immediate Action): 47
High Priority Issues: 89
Medium Priority Issues: 142
```

**Detailed Department View: Marketing**
```
Marketing Department - Metadata Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Overall Score: 58/100 (Below Target: 70)

Issue Breakdown:

Critical (15 tables):
- Missing owner information
- No description for high-usage tables
- Undefined schema breaking lineage

Missing Descriptions (25 tables):
Top offenders:
1. campaigns.email_metrics_daily (45 downstream users!)
   Last modified: 3 months ago
   Usage: 450 queries/day
   Owner: Unassigned

2. marketing.attribution_model_v2
   Last modified: 1 month ago
   Usage: 12 dashboards dependent
   Owner: john.doe@company.com

3. ads.conversion_tracking_raw
   [...]

Incomplete Documentation (18 tables):
- Has description but missing:
  - Business context
  - Update frequency
  - Data quality expectations
  - PII classification

Ownership Issues (22 tables):
- Unassigned: 8 tables
- Owner left company: 6 tables
- Team ownership (no individual): 8 tables

Schema Documentation (12 tables):
- Missing column descriptions
- Undefined column purposes
- No data type justification

Auto-generated Action Items:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Assigned to: marketing-data-lead@company.com

Priority 1 (Due: 1 week):
[ ] Assign owner to campaigns.email_metrics_daily
[ ] Add description to top 5 high-usage undocumented tables
[ ] Update ownership for departed employees' tables

Priority 2 (Due: 2 weeks):
[ ] Complete schema documentation for attribution models
[ ] Add PII classification tags to customer data tables
[ ] Document update frequency for all metrics tables

Priority 3 (Due: 1 month):
[ ] Add business context to all production tables
[ ] Implement data quality expectations documentation
[ ] Review and update stale descriptions (>6 months old)
```

**Week 2: Automated Notifications**
```
Email to: john.doe@company.com
Subject: [Action Required] 3 Tables Need Documentation Update
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hi John,

DataSpoke has identified tables under your ownership that need
documentation updates:

1. marketing.attribution_model_v2
   Issue: Missing business context and update frequency
   Impact: 12 dashboards depend on this table
   Time to fix: ~10 minutes
   [Fix Now] [Delegate] [Snooze 3 days]

2. campaigns.segment_rules_active
   Issue: Schema changed but description not updated
   Impact: Potential confusion for 8 data consumers
   Time to fix: ~5 minutes
   [Fix Now] [Delegate] [Snooze 3 days]

3. marketing.customer_lifetime_value_calc
   Issue: No PII classification despite containing email field
   Impact: Compliance risk (GDPR audit)
   Time to fix: ~2 minutes
   [Fix Now] [Delegate] [Snooze 3 days]

Your current department score: 58/100
Target: 70/100
With these fixes: 64/100 (↑ 6 points)

[View Full Report] [Bulk Edit] [Request Help]
```

**Month 1: Progress Tracking**
```
DataSpoke Monthly Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enterprise Health Score: 62 → 71 (+9 points)

Top Performers:
  Finance: 82 → 88 (+6) - All critical issues resolved
  Engineering: 78 → 85 (+7) - Excellent response time
  Data Science: 71 → 79 (+8) - Proactive improvements

Most Improved:
  Marketing: 58 → 72 (+14) - Department of the Month
   - Resolved 38/40 critical issues
   - Reduced avg response time from 12 days to 3 days
   - Implemented weekly review process

Needs Attention:
  Operations: 48 → 51 (+3) - Below target pace
  Current issues: 32 open (3 critical)
  Trend: Slow response to automated notifications
  Recommendation: Schedule 1:1 with team lead

Metrics:
- Issues resolved: 156 (68% of total)
- Avg resolution time: 4.2 days (target: 5 days) ✓
- Documentation coverage: 68% → 79% (+11%)
- Owner assignment rate: 82% → 94% (+12%)
- Tables with quality expectations: 45% → 61% (+16%)

Compliance Impact:
✓ GDPR audit-ready tables: 78% (↑ 15%)
✓ Production-grade documentation: 81% (↑ 19%)
✓ Risk assessment: Reduced from Medium to Low
```

**Month 3: Continuous Monitoring**
```
DataSpoke Insight (Auto-generated):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Milestone Achieved!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enterprise Health Score: 78/100 (Target: 70)

All departments now above minimum threshold!

New Issues Detected This Week: 8
Auto-resolved: 3 (AI-suggested descriptions accepted)
Pending owner action: 5 (avg age: 1.2 days)

Trend Analysis:
- Documentation decay rate: -2.3% per month
  (New tables created faster than documented)

Recommendation:
  Implement mandatory documentation checklist for new tables
  Est. time impact: +5 minutes per table creation
  Est. improvement: +15 points health score over 6 months

[Implement Recommendation] [Customize Rules] [Schedule Review]
```

**Outcome:**
- Visibility: Real-time dashboard replacing quarterly manual audits
- Response time: 12 days to 3 days average resolution
- Accountability: Automated assignment and tracking
- Improvement: 62 to 78 health score in 3 months
- Efficiency: 80% reduction in governance team manual work
- Compliance: Audit-ready state maintained continuously

---

## Summary: Value Delivered

| Use Case | User Group | Feature | Traditional Approach | With DataSpoke | Improvement |
|----------|-----------|---------|---------------------|----------------|-------------|
| **Legacy Metadata Integration** | DE | Deep Ingestion | Manual metadata entry, no lineage | Automated enrichment from multiple sources | 91% enrichment, 127 hidden lineage edges |
| **AI Pipeline Verification** | DE / DA | Online Validator | 30% failure rate from bad data | <5% failure with real-time verification | 83% reduction in incidents |
| **Predictive SLA Management** | DE | Online Validator | Reactive alerts after breach | Proactive warnings 2+ hours early | 100% SLA achievement |
| **AI-Driven Ontology Design** | DE | Doc Suggestions | 3-month manual reconciliation | Automated proposal in hours | Orders-of-magnitude faster |
| **Semantic Data Discovery** | DA | NL Search | 4-6 hours manual search | 2-5 minutes automated search | 98% time savings |
| **Metadata Health Monitoring** | DG | Metrics Dashboard | Quarterly manual audits (2 weeks) | Real-time continuous monitoring | 95% efficiency gain |

**Cross-cutting Benefits:**
- **AI-Ready:** Enables autonomous agents to work safely with production data
- **Real-time Intelligence:** Shifts from reactive to proactive data management
- **Context-Aware:** Understands data relationships and business meaning
- **Measurable Impact:** Quantifiable improvements in quality, compliance, and efficiency
- **Ontology Health:** Catalog remains semantically consistent as the organization grows
