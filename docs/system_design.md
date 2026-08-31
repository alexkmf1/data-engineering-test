````markdown
# System Design — Carrier Profile & Risk Score Pipeline

## 1. Purpose

This document describes the technical design of the Carrier Profile & Risk Score Pipeline created for the FreightHero Data Engineer Technical Assessment.

The implementation is intentionally simple for the local assessment environment while keeping the same logical structure that could be extended for a production environment.

The pipeline follows a Medallion architecture:

```text
Sources
   ↓
Bronze
   ↓
Silver
   ↓
Gold
   ↓
PostgreSQL
   ↓
Metabase
```

The detailed instructions for installing and running the project are available in the main `README.md`.

---

## 2. Architecture

### Local Implementation

The current implementation uses:

```text
CSV / JSON / TXT
       ↓
     Pandas
       ↓
Bronze Parquet
       ↓
     Pandas
       ↓
Silver Parquet
       ↓
     Pandas
       ↓
Gold
       ↓
PostgreSQL
       ↓
Metabase
```

The local architecture was intentionally kept small because the assessment dataset can be processed efficiently on one machine.

A PySpark ingestion alternative is also included to demonstrate how the processing approach could evolve for larger workloads.

### Production Direction

The production design is intentionally cloud-agnostic because the target infrastructure was not specified.

The same architecture could be implemented on AWS or GCP:

```text
Source Systems
      ↓
Batch / CDC Ingestion
      ↓
Cloud Object Storage
S3 or GCS
      ↓
Bronze
      ↓
PySpark Processing
      ↓
Silver
      ↓
Gold
      ↓
PostgreSQL
      ↓
Metabase
```

The logical data architecture does not depend on a specific cloud provider.

---

## 3. Layer Responsibilities

### Bronze

The Bronze layer represents the data as received from the source.

Its main responsibility is to preserve source information while performing only the validation necessary to safely ingest the dataset.

The local implementation keeps the current version of each Bronze dataset.

A timestamp-based versioning approach was considered:

```text
bronze/<dataset>/ingestion_timestamp=<timestamp>/
```

but was intentionally not enabled to keep the assessment implementation simple.

In production, versioned or immutable Bronze data would be preferable when historical replay and auditing are required.

### Silver

The Silver layer establishes the canonical schema.

This is where:

- Column names are standardized
- Data types are established
- Timestamps are normalized
- Deterministic duplicates are removed
- Data-quality rules are enforced

The principle used is:

```text
Bronze
Preserve what arrived

Silver
Define what the dataset officially means
```

### Gold

Gold represents business-facing analytical data.

It combines the communication, carrier, and broker datasets and will contain the metrics required for the Carrier Risk Score and BI dashboard.

# 🚧 IN PROGRESS — UPDATE BEFORE SUBMISSION

The following still need to be finalized:

- Final Gold grain
- Carrier responsiveness calculation
- Carrier performance metrics
- Carrier Risk Score formula
- Risk classification
- Final Gold table or tables

The current Gold implementation is temporary and is being used to validate PostgreSQL and Metabase connectivity.

---

## 4. Tooling Decisions

### Pandas

Pandas was selected for the local implementation because the provided dataset can be processed on a single machine.

This avoids unnecessary distributed-processing complexity for the assessment.

### PySpark

PySpark is included as an alternative implementation.

For substantially larger datasets, PySpark could divide processing across multiple workers and improve scalability.

The decision between Pandas and PySpark should therefore depend on data volume and infrastructure requirements rather than using distributed processing by default.

### Parquet

Parquet is used between data layers because it provides:

- Columnar storage
- Efficient analytical reads
- Data-type preservation
- Better storage efficiency than CSV

### PostgreSQL

PostgreSQL is used as the SQL serving layer between Gold and Metabase.

The production design can continue using PostgreSQL unless scale or business requirements justify another analytical database.

### Metabase

Metabase is used as the BI layer and reads the analytical Gold data through PostgreSQL.

### Terraform

Terraform is the selected Infrastructure as Code approach for describing infrastructure in a reproducible and version-controlled way.

---

## 5. Data Modeling

The communication dataset is the main event-oriented dataset.

Carrier and broker datasets provide reference information that can enrich those communication events.

Conceptually:

```text
communications
     │
     ├── carrier_company_id → carriers
     │
     └── broker_company_id  → brokers
```

The Gold layer will transform these source-oriented structures into a business-oriented model.

# 🚧 IN PROGRESS — UPDATE BEFORE SUBMISSION

The final Gold model will be documented here once the Carrier Risk Score logic is finalized.

The final design may contain one or multiple Gold tables depending on the metrics and dashboard requirements.

---

## 6. Schema Management

The pipeline uses an expected schema definition during ingestion.

The current local behavior is:

```text
Expected schema
      ↓
Missing expected column
→ Reject

Additional source column
→ Detect and report

Expected columns present
→ Continue
```

The local implementation currently reports additional columns but does not automatically add them to the canonical Silver schema.

### Production Approach

In production, the schema should remain controlled.

For a new source column:

```text
New column detected
       ↓
Generate alert
       ↓
Preserve source information
       ↓
Review the column
       ↓
Update the canonical schema only if approved
```

A new source field should not automatically become part of the official business schema without review.

Breaking changes such as:

```text
Missing required column
Unexpected datatype change
Required field removed
```

should stop processing for that dataset and the downstream datasets that depend on it.

Independent pipelines should continue running whenever possible.

---

## 7. Data Quality and Failure Handling

Data-quality validation runs during pipeline execution against the actual data.

Current checks include:

```text
Duplicate business records
Uniqueness rules
Required / non-null fields
Timestamp ordering
```

If the pipeline cannot safely determine how to correct invalid data, it raises an error instead of silently changing the values.

### Failure Isolation

A failure should affect:

```text
The invalid dataset
+
Its downstream dependencies
```

rather than automatically stopping unrelated datasets.

For example:

```text
Dataset A fails
   ↓
Gold model depending on A does not run

Dataset B is independent
   ↓
Dataset B can continue
```

---

## 8. Alerting

Production failures should generate actionable alerts.

The alert should include information such as:

```text
Dataset
Pipeline step
Validation that failed
Execution time
Affected records
Error message
```

Notifications could be delivered through:

```text
Email
and/or
Integration with an incident-management system
```

The incident-management integration could automatically create a ticket when intervention is required.

---

## 9. CDC and Incremental Processing

The assessment source data consists of static files, so CDC is not implemented in the local solution.

For production database sources, the preferred pattern would be incremental ingestion using CDC.

### SQL Example

```text
SQL Database
     ↓
CDC Service
     ↓
Bronze
     ↓
Scheduled Batch Processing
```

On AWS, AWS DMS is one possible implementation.

An equivalent managed CDC solution could be selected if the environment uses GCP.

### NoSQL

For NoSQL sources, the same logical pattern could use the database's change-stream mechanism:

```text
NoSQL Database
      ↓
Change Stream
      ↓
Bronze
      ↓
Scheduled Batch Processing
```

The intended design remains primarily batch-oriented while CDC provides only the changes since the previous ingestion.

---

## 10. Processing and Orchestration

The local implementation is manually executed through notebooks.

For production, processing could use PySpark.

The orchestration technology depends on the available platform.

For example:

```text
If Databricks is available
→ Databricks Jobs can orchestrate the workloads

If Databricks is not available
→ another scheduler/orchestrator can be used
```

The architecture therefore does not depend on one specific orchestration tool.

---

## 11. Environments

A production implementation should separate:

```text
dev
int
prod
```

The purpose is to allow code, schema, and infrastructure changes to be validated before reaching production.

Conceptually:

```text
DEV
↓
development and initial validation

INT
↓
integration testing

PROD
↓
production workloads
```

---

## 12. Infrastructure as Code

Terraform will be used to represent the infrastructure required by the production architecture.

# 🚧 IN PROGRESS — UPDATE BEFORE SUBMISSION

The `/iac/` directory will contain the IaC implementation or representative Terraform configuration required by the assessment.

The exact resources depend on whether the environment uses AWS or GCP.

The intent is to demonstrate that infrastructure should be:

```text
Version controlled
Repeatable
Environment specific
Reviewable
```

rather than manually configured.

---

## 13. Governance

The governance design is intentionally lightweight for this assessment.

### Naming

Use:

```text
lowercase
snake_case
clear business names
```

Layer naming:

```text
bronze/<dataset>
silver/<dataset>
gold/<business_model>
```

### Metadata

Technical metadata is maintained in the engineering layers for traceability.

Examples include:

```text
_source_file
_ingested_at
_transformed_at
```

Gold should contain the information required by business consumers without exposing unnecessary technical metadata.

### Access

Production access should follow least privilege.

Conceptually:

```text
Pipeline identity
→ write permissions required for processing

BI identity
→ read-only access to analytical data

Administrative identities
→ elevated permissions only when required
```

Secrets should not be stored directly in source code.

---

## 14. Metadata Lifecycle

Metadata should support understanding where data originated and when it was processed.

The current pipeline adds metadata during Bronze and Silver processing.

Conceptually:

```text
Source
   ↓
_source_file
_ingested_at
   ↓
Bronze
   ↓
_transformed_at
   ↓
Silver
   ↓
Gold
```

Production environments could extend this with a centralized data catalog and lineage solution.

A specific catalog technology is intentionally not prescribed because the target cloud/platform has not been defined.

---

## 15. Scaling Strategy

The current local pipeline uses Pandas.

The processing technology should evolve only when scale requires it.

Conceptually:

```text
Small / medium workload
→ Pandas

Larger distributed workload
→ PySpark
```

PySpark would allow the processing workload to be distributed across multiple workers rather than relying on a single machine.

No production row-volume assumptions are made because production volumes were not provided.

---

## 16. System Diagram

# 🚧 DRAW.IO DIAGRAM TO ADD BEFORE SUBMISSION

The final diagram will be created using Draw.io.

It should show the main flow:

```text
             SOURCE SYSTEMS
        CSV / JSON / TXT / Databases
                    │
                    ▼
            Batch / CDC Ingestion
                    │
                    ▼
                 BRONZE
                    │
                    ▼
                 SILVER
                    │
                    ▼
                  GOLD
                    │
                    ▼
               PostgreSQL
                    │
                    ▼
                Metabase
```

The production version of the diagram can also show:

```text
Cloud Object Storage
PySpark Processing
Alerting
Terraform
dev / int / prod
```

without tying the architecture to AWS or GCP.

---

## 17. Local vs Production Design

The assessment implementation and production design intentionally differ in complexity.

| Area | Local Assessment | Production Consideration |
|---|---|---|
| Processing | Pandas | PySpark when scale requires |
| Storage | Local Parquet | S3 or GCS |
| Bronze history | Current file | Versioned / immutable |
| Ingestion | Static files | Batch + CDC |
| Orchestration | Manual notebooks | Platform-dependent scheduler |
| Database | PostgreSQL | PostgreSQL unless requirements change |
| BI | Metabase | Metabase |
| IaC | 🚧 Planned | Terraform |
| Alerting | Not implemented locally | Email / incident-management integration |
| Environments | Local | dev / int / prod |

This separation keeps the assessment implementation simple while showing how the architecture could evolve without pretending that production infrastructure has already been implemented.

---

## 18. Current Limitations

The following items are intentionally not complete yet:

- 🚧 Final Gold model
- 🚧 Carrier Risk Score formula
- 🚧 Final dashboard
- 🚧 Gold persistence under `data/gold/`
- 🚧 CI/CD
- 🚧 Terraform implementation
- 🚧 Docker Compose
- 🚧 Draw.io architecture diagram
- 🚧 Production CDC implementation
- 🚧 Production alerting integration

These items will be updated before final submission where required by the assessment.
````