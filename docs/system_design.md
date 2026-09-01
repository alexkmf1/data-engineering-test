# System Design — FreightHero Carrier Profile & Risk Analysis Pipeline

## 1. Purpose

This document describes the technical design of the FreightHero Data Engineer Technical Assessment.

The solution follows a Medallion-style architecture and separates:

- Raw ingestion
- Data standardization and quality
- Business logic
- SQL serving
- BI consumption

The local implementation is intentionally simple because the provided dataset can be processed efficiently on a single machine.

A production-oriented AWS architecture is also proposed to demonstrate how the same logical pipeline could evolve using cloud storage, managed processing, IAM, Infrastructure as Code, monitoring, and incremental ingestion.

Installation and execution instructions are documented in the main `README.md`.

---

## 2. Architecture

### Local Implementation

The implemented local flow is:

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
 Gold Parquet
        ↓
   PostgreSQL
        ↓
     Metabase
```

The current pipeline is executed through the notebooks in sequence:

```text
src/bronze/ingestion.ipynb
        ↓
src/silver/transformation.ipynb
        ↓
src/gold/build.ipynb
```

The generated Bronze, Silver, and Gold datasets are also committed to the repository so that the resulting data can be inspected even if the evaluator does not execute the complete environment locally.

PostgreSQL and Metabase run as Docker Compose services. The notebooks run in the host Python environment and connect to PostgreSQL through `localhost:5432`; Metabase connects from inside the Docker network through `postgres:5432`. Named volumes preserve the PostgreSQL data and Metabase configuration between container restarts.

### Proposed Production Architecture

The production reference architecture uses AWS:

```text
External Data Sources
        ↓
Landing - S3
        ↓
AWS Glue
        ↓
Bronze - S3
        ↓
AWS Glue
        ↓
Silver - S3
        ↓
AWS Glue
        ↓
Gold - S3
        ↓
PostgreSQL
        ↓
Metabase
```

Supporting components include:

```text
Terraform / IaC
→ infrastructure definition

AWS IAM
→ Glue execution permissions

Scripts storage
→ production pipeline code used by Glue

Monitoring
→ job and data-quality failures

CI
→ Ruff + Pytest
```

The production architecture is represented in:

```text
docs/carrier_risk.drawio
```

The AWS design is a representative production direction and is not deployed as part of the assessment.

---

## 3. Data Layer Responsibilities

### Landing

Landing represents the files exactly as received from the source.

Examples:

```text
CSV
JSON
TXT
```

The purpose of Landing is to preserve the original source before engineering transformations are applied.

The current local assessment reads directly from `samples/`, so Landing is represented conceptually rather than as a separate local processing layer.

In the proposed AWS architecture, Landing would be implemented using S3.

---

### Bronze

Bronze preserves the source structure as faithfully as possible while converting the data to Parquet.

Responsibilities include:

- Reading the original source format
- Validating expected source columns
- Preserving source column names
- Adding ingestion metadata
- Persisting the dataset as Parquet

Technical metadata includes:

```text
_source_file
_ingested_at
```

Example:

The source communication dataset contains:

```text
broker_comany_id
```

The typo is intentionally preserved in Bronze because Bronze represents what arrived from the source.

It is corrected later in Silver.

Local output:

```text
data/bronze/<dataset>/data.parquet
```

A production environment could use immutable or timestamp-versioned Bronze data to support replay, auditing, and historical recovery.

---

### Silver

Silver establishes the canonical engineering schema.

Responsibilities include:

- Standardizing column names
- Casting data types
- Parsing timestamps as UTC
- Removing deterministic duplicate business records
- Running data-quality validations
- Adding transformation metadata

Example canonical correction:

```text
broker_comany_id
        ↓
broker_company_id
```

Technical metadata includes:

```text
_transformed_at
```

Local output:

```text
data/silver/<dataset>/data.parquet
```

The design principle is:

```text
Bronze
→ preserve what arrived

Silver
→ define the canonical representation
```

---

### Gold

Gold contains the business-oriented analytical model.

The current Gold model combines:

```text
communications
+
carriers
+
brokers
```

and transforms communication events into response cycles that can be used to analyze carrier responsiveness and risk.

Local output:

```text
data/gold/carrier_risk/data.parquet
```

The same Gold dataset is loaded into PostgreSQL:

```text
public.carrier_risk
```

---

## 4. Gold Business Logic

The Gold model focuses on communication between FreightHero/broker-side users and carrier contacts.

### Relevant Outbound Events

An outbound event is considered when:

```text
direction = outbound
status = delivered
to_contact_type = driver or dispatcher
```

The destination contact becomes the analytical `contact_type`.

### Relevant Inbound Events

An inbound event is considered when:

```text
direction = inbound
status = received
from_contact_type = driver or dispatcher
```

The source contact becomes the analytical `contact_type`.

### Response-Matching Group

The stakeholder clarification defines `external_id` as the load identifier shared by related communications. The current implementation creates a response-matching group using:

```text
external_id
carrier_name
broker_name
channel
contact_type
```

Events are sorted chronologically within these groups. The same `channel` and `contact_type` are required for the outbound attempt and inbound response.

`thread_id` is not currently included in the grouping key. Because a load can contain multiple threads, this is a known limitation: communications from separate threads could be combined when the other grouping fields are identical. A production version should confirm the desired thread behavior and either include `thread_id` or implement an explicit fallback for null thread identifiers.

### Response Cycles

A conversation may contain multiple outbound attempts and multiple responses.

The model therefore creates a `cycle_id`.

An inbound event closes the current outbound response cycle, and the next outbound communication starts the next response cycle.

For each cycle, Gold calculates:

```text
first_outbound_at
last_outbound_at
response_at
outbound_attempts
```

Only cycles containing at least one outbound attempt are retained.

### Response Identification

A cycle is considered answered when:

```text
response_at IS NOT NULL
```

This produces:

```text
responsed = True / False
```

### Response Time

Response time is measured in minutes from the first outbound attempt to the inbound response:

```text
response_time =
response_at - first_outbound_at
```

The result is converted to minutes.

### Final Gold Schema

The current Gold dataset contains:

| Column | Description |
|---|---|
| `external_id` | Load identifier shared by related communications |
| `carrier_name` | Carrier associated with the communication |
| `broker_name` | Broker associated with the communication |
| `channel` | Communication channel |
| `contact_type` | Carrier contact type, such as driver or dispatcher |
| `cycle_id` | Response cycle within the conversation |
| `first_outbound_at` | First outbound attempt in the cycle |
| `last_outbound_at` | Most recent outbound attempt in the cycle |
| `response_at` | First inbound response in the cycle |
| `outbound_attempts` | Number of outbound attempts before the response |
| `responsed` | Whether the cycle received a response |
| `response_time` | Minutes between the first outbound attempt and the response |

### Business Assumptions

Stakeholder clarification resolved some semantics, while other implementation choices remain analytical assumptions.

Therefore, the response logic is based on explicit assumptions documented in the implementation.

Confirmed for the current assessment:

- Each row is one communication event.
- `external_id` is the load identifier shared by the related communications.
- `direction = outbound` means FreightHero sent the communication.
- `direction = inbound` means FreightHero received the communication.
- Responses remain within the same `channel`; cross-channel response matching is not required today.
- `thread_id` represents a thread within the broader communication history.

The remaining rules that require business validation are:

- Whether `thread_id` must always participate in response matching and how null thread identifiers should behave.
- Whether a driver can answer a message sent to a dispatcher, or vice versa.
- Whether `created_at` or another event timestamp should be used for the response-time clock.
- Which outbound statuses count as valid attempts for SMS and chat.
- Whether equal score weights and the minimum of 10 records should become formal business rules.

The current Gold implementation produces response-cycle metrics used for carrier risk analysis. Because the implemented outbound rule requires `status = delivered`, the current Gold output is effectively email-only. SMS primarily uses `sent`, and chat requires additional status/contact rules before those channels can be treated as supported.

### Carrier Responsiveness Risk Score

The final Risk Score is calculated in the Metabase SQL layer from `public.carrier_risk`. The complete query is versioned in `README.md` and `dashboard/README.md`.

For every carrier with at least 10 response-cycle records within the selected channel:

```text
response_rate = responded records / total records

non_response_risk = 1 - response_rate

delay_risk = PERCENT_RANK of average response time
             relative to the other eligible carriers

Risk Score = 100 × (
    0.50 × non_response_risk
    + 0.50 × delay_risk
)
```

Average response time uses answered cycles only and is displayed in hours. If a carrier has no responses, its Risk Score is set to `100`, representing maximum communication-responsiveness risk.

The score is explainable but relative: `PERCENT_RANK()` depends on the eligible carrier population and selected channel. The 50/50 weighting, the minimum sample of 10 records, and the risk-level thresholds are analytical assumptions pending stakeholder approval. The result measures communication responsiveness only; it does not represent carrier safety, financial, fraud, or delivery risk.

---

## 5. Data Modeling

The source-oriented model contains one main event dataset and two reference datasets.

Conceptually:

```text
communications
     │
     ├── carrier_company_id → carriers
     │
     └── broker_company_id  → brokers
```

The communication dataset is event-oriented.

Carrier and broker datasets enrich those events with descriptive information.

Gold changes the grain from individual raw communication events to communication response cycles.

Conceptually:

```text
Raw Communication Events
          ↓
Relevant Inbound / Outbound Events
          ↓
Conversation
          ↓
Response Cycle
          ↓
Gold Analytical Record
```

This makes the final dataset easier to consume for responsiveness and risk analysis.

---

## 6. Data Quality and Failure Handling

Runtime data-quality logic is implemented in:

```text
src/silver/data_quality.py
```

Current checks include:

```text
Duplicate removal
Uniqueness validation
Not-null validation
Timestamp-order validation
```

### Duplicate Handling

Duplicate removal uses business columns and excludes technical metadata fields.

This prevents fields such as ingestion timestamps from making otherwise identical business records appear different.

### Validation Strategy

If the pipeline cannot safely infer how invalid data should be corrected, it raises an error rather than silently modifying the data.

The Silver datasets are persisted only after transformation and validation succeed.

This reduces the possibility of creating partially valid Silver output.

### Failure Isolation

In a production environment, failures should stop:

```text
The affected dataset
+
Dependent downstream processing
```

Independent pipelines should continue whenever possible.

For example:

```text
Dataset A fails
      ↓
Gold model depending on A does not run

Dataset B is independent
      ↓
Dataset B continues
```

---

## 7. Schema Management and Evolution

The Bronze ingestion defines an expected source schema.

Current behavior is:

```text
Expected columns present
        ↓
Continue

Missing expected column
        ↓
Raise error

Additional source column
        ↓
Detect and report
```

New source columns are not automatically promoted into the canonical Silver schema.

This is intentional.

A production schema-evolution process should be:

```text
New source column detected
        ↓
Preserve source information
        ↓
Generate notification
        ↓
Review business meaning
        ↓
Update canonical schema if approved
```

Breaking changes such as missing required fields or incompatible datatype changes should stop the affected dataset and its downstream dependencies.

This prevents uncontrolled source changes from silently modifying the business model.

---

## 8. Tooling Decisions

### Pandas

Pandas is used for the local implementation because the provided dataset can be processed efficiently on a single machine.

Distributed processing would add unnecessary complexity for the current volume.

### Parquet

Parquet is used between data layers because it provides:

- Columnar storage
- Efficient analytical reads
- Data-type preservation
- Better storage efficiency than CSV
- Good interoperability with analytical processing engines

### PostgreSQL

PostgreSQL stores the final Gold dataset (public.carrier_risk) and serves it to Metabase for dashboard queries.

It provides a standard SQL interface for the BI layer and separates analytical consumption from transformation processing.

### Metabase

Metabase is used as the visualization layer and connects to:

```text
public.carrier_risk
```

The final dashboard contains three cards: Carrier Responsiveness Risk Score, Response Rate by Carrier, and Average Response Time by Carrier. It includes a shared `channel` filter and is exported under `dashboard/` together with its SQL and configuration documentation.

### PySpark / AWS Glue

The local implementation does not require distributed processing.

For significantly larger production workloads, the transformation logic could be packaged as Python/PySpark scripts and executed using AWS Glue.

The choice between Pandas and PySpark should depend on data volume and infrastructure requirements rather than using distributed processing by default.

---

## 9. Continuous Integration

CI is implemented using GitHub Actions:

```text
.github/workflows/ci.yml
```

The workflow performs:

```text
Push / Pull Request
        ↓
Checkout repository
        ↓
Set up Python
        ↓
Install dependencies
        ↓
Ruff
        ↓
Pytest
        ↓
Pass / Fail
```

Ruff is used to validate Python code quality.

The intended linting scope is:

```bash
python -m ruff check src tests
```

Pytest validates the reusable data-quality functions:

```bash
python -m pytest tests/test_data_quality.py -v
```

The current test suite contains four automated tests.

CI validates the code and the behavior of the validation functions.

It does not replace runtime data-quality validation against incoming pipeline data.

---

## 10. Infrastructure as Code

Representative Terraform configuration is stored in:

```text
iac/
```

Current organization includes:

```text
provider.tf
variables.tf
locals.tf
iam-role.tf
iam-policy.tf
scripts.tf
glue-job.tf
outputs.tf

dev.tfvars
int.tfvars
prd.tfvars
```

The Terraform structure demonstrates separation of infrastructure responsibilities.

Conceptually:

```text
provider.tf
→ AWS provider configuration

variables.tf
→ configurable infrastructure values

locals.tf
→ reusable naming and configuration

iam-role.tf
→ Glue execution identity

iam-policy.tf
→ permissions associated with the execution role

scripts.tf
→ representation of pipeline scripts stored for Glue

glue-job.tf
→ Glue processing jobs

outputs.tf
→ infrastructure outputs

*.tfvars
→ environment-specific configuration
```

The environment `.tfvars` files are currently examples/placeholders.

### IaC Scope

The Terraform is included to demonstrate:

- Infrastructure organization
- Version-controlled configuration
- Separation of responsibilities
- Reusable configuration
- Environment-specific deployment patterns
- IAM-based access management

The Terraform configuration has not been applied to an AWS account as part of the assessment.

It should therefore be treated as a representative infrastructure design rather than evidence of deployed cloud resources.

The current executable pipeline remains notebook-based.

A real Glue deployment would require packaging the relevant notebook logic into executable Python/PySpark scripts before deployment.

---

## 11. Security and Governance

### Naming

Engineering datasets and fields use:

```text
lowercase
snake_case
clear business-oriented names
```

Layer organization follows:

```text
bronze/<dataset>
silver/<dataset>
gold/<business_model>
```

### Technical Metadata

Technical metadata is maintained in the engineering layers to support traceability.

Examples:

```text
_source_file
_ingested_at
_transformed_at
```

Gold removes unnecessary engineering metadata and exposes fields useful to analytical consumers.

### Access

A production environment should follow least privilege.

Conceptually:

```text
Glue execution identity
→ permissions required for pipeline processing

BI identity
→ read-only access to analytical serving data

Administrative identity
→ elevated permissions only when required
```

The Terraform design separates the Glue IAM role from its permissions to make this relationship explicit.

### Secrets

Credentials should not be stored in source code.

The local PostgreSQL configuration is supplied through:

```text
.env
```

The repository contains only:

```text
.env.example
```

A production implementation should use a managed secret store.

---

## 12. CDC and Incremental Processing

The provided assessment data consists of static files.

CDC is therefore not implemented.

For production database sources, a possible architecture would be:

```text
Operational Database
        ↓
CDC
        ↓
Landing / Bronze
        ↓
Scheduled Processing
```

For AWS relational sources, AWS DMS is one possible CDC technology.

For NoSQL systems, native database change streams could provide equivalent incremental events.

The important design principle is that CDC captures only new changes while downstream transformations can continue to execute in controlled batches.

This avoids repeatedly processing the complete operational source when only incremental changes are required.

---

## 13. Orchestration

The current implementation uses notebooks executed manually in order:

```text
Bronze
  ↓
Silver
  ↓
Gold
```

This keeps the local assessment simple.

A future improvement is to provide a single orchestration entry point so the entire local pipeline can be executed with one command.

For the proposed AWS architecture, orchestration could coordinate the Glue jobs and their dependencies.

Conceptually:

```text
LandingToBronze
      ↓
BronzeToSilver
      ↓
SilverToGold
```

Possible production orchestration technologies include:

- AWS Step Functions
- AWS Glue Workflows
- Airflow
- Databricks Jobs when using Databricks

The orchestration technology should depend on the target platform rather than being hardcoded into the logical data architecture.

---

## 14. Environments

A production implementation should separate:

```text
DEV
INT
PROD
```

The Terraform structure already represents this concept through:

```text
dev.tfvars
int.tfvars
prd.tfvars
```

The same infrastructure definitions can therefore be reused with environment-specific configuration.

Conceptually:

```text
DEV
↓
Development and initial validation

INT
↓
Integration validation

PROD
↓
Production workloads
```

The current `.tfvars` files are placeholders and are not used to deploy real environments in this assessment.

---

## 15. Monitoring and Alerting

The local implementation primarily exposes failures through execution errors.

A production pipeline should provide centralized monitoring for:

- Glue job failures
- Data-quality failures
- Schema changes
- Processing duration
- Failed datasets
- Downstream dependency failures

An actionable failure notification should include information such as:

```text
Dataset
Pipeline step
Execution time
Validation or error
Affected records
Error message
```

Notifications could be delivered through:

```text
Email
and/or
Incident-management integration
```

An incident integration could automatically create a ticket when intervention is required.

Monitoring is represented as a production design consideration and is not implemented locally.

---

## 16. Scaling Strategy

The current workload uses Pandas because it fits comfortably on one machine.

The processing technology should evolve only when scale requires it.

Conceptually:

```text
Small / medium workload
        ↓
Pandas

Large distributed workload
        ↓
PySpark / AWS Glue
```

PySpark allows processing to be distributed across multiple workers.

No assumptions are made about FreightHero production row volumes because those volumes were not provided in the assessment.

Storage and compute should therefore be scaled based on measured workload rather than hypothetical volume.

---

## 17. Architecture Diagram

The architecture diagram was created using Draw.io:

```text
docs/carrier_risk.drawio
```

The diagram shows:

```text
External Data Sources
        ↓
Landing
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

It also represents the proposed AWS Glue processing and Terraform provisioning relationship.

The diagram distinguishes the data flow from the supporting infrastructure so that the main pipeline remains easy to understand.

---

## 18. Local vs Production Design

| Area | Local Assessment | Production Direction |
|---|---|---|
| Source | Static CSV / JSON / TXT | Operational systems / files |
| Landing | `samples/` | S3 Landing |
| Processing | Pandas | PySpark / AWS Glue when scale requires |
| Storage | Local Parquet | S3 |
| Bronze history | Current output | Versioned / immutable where required |
| Silver | Canonical Parquet | Canonical S3 dataset |
| Gold | Response-cycle Parquet | Business analytical dataset |
| Serving | PostgreSQL | PostgreSQL unless requirements change |
| BI | Metabase | Metabase |
| Data Quality | Runtime Python validations | Automated pipeline validations + monitoring |
| CI | GitHub Actions | GitHub Actions |
| IaC | Representative Terraform | Terraform-applied infrastructure |
| Orchestration | Manual notebooks | Managed orchestrator |
| Incremental ingestion | Not required | Batch + CDC |
| Monitoring | Execution errors | Centralized monitoring + alerts |
| Environments | Local | DEV / INT / PROD |

The objective is not to reproduce production complexity inside a small technical assessment.

Instead, the local implementation demonstrates the transformation logic while the production design shows how the same responsibilities could be separated and scaled in a real environment.

---

## 19. Current Limitations and Future Improvements

The main remaining improvements are:

- Add a single-command local pipeline runner
- Package notebook logic as production Python/PySpark scripts if deploying through AWS Glue
- Apply and validate Terraform against a real AWS environment if production deployment is required
- Add production monitoring and alert integrations
- Add CDC when operational database sources become available
- Resolve `thread_id`, cross-contact response, SMS, and chat business rules with stakeholders
- Validate the score weights, minimum sample size, and risk-level thresholds with stakeholders

The current solution intentionally distinguishes between what has actually been implemented locally and what is proposed as a production design.