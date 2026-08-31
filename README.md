# FreightHero Carrier Profile

This repository contains my implementation of the FreightHero Data Engineer Technical Assessment.

The project builds an end-to-end data pipeline that transforms the provided carrier, broker, and communication datasets into a business-ready Gold dataset for carrier responsiveness and risk analysis.

The local pipeline follows a Medallion-style architecture:

```text
CSV / JSON / TXT
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

The local implementation uses Pandas and Parquet for data processing, PostgreSQL as the SQL serving layer, and Metabase for visualization.

A representative AWS production architecture using S3, AWS Glue, IAM, and Terraform is documented separately in:

```text
docs/system_design.md
```

---

## Project Structure

```text
data-engineering-test/
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── dashboard/
│
├── data/
│   ├── bronze/
│   │   ├── brokers/
│   │   ├── carriers/
│   │   └── communications/
│   │
│   ├── silver/
│   │   ├── brokers/
│   │   ├── carriers/
│   │   └── communications/
│   │
│   └── gold/
│       └── carrier_risk/
│
├── docs/
│   ├── carrier_risk.drawio
│   └── system_design.md
│
├── iac/
│   ├── dev.tfvars
│   ├── int.tfvars
│   ├── prd.tfvars
│   ├── glue-job.tf
│   ├── iam-policy.tf
│   ├── iam-role.tf
│   ├── locals.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── scripts.tf
│   └── variables.tf
│
├── samples/
│   ├── broker-samples.txt
│   ├── carrier-samples.json
│   └── communication-samples.csv
│
├── src/
│   ├── bronze/
│   │   └── ingestion.ipynb
│   │
│   ├── silver/
│   │   ├── data_quality.py
│   │   └── transformation.ipynb
│   │
│   └── gold/
│       └── build.ipynb
│
├── tests/
│   └── test_data_quality.py
│
├── .env.example
├── .gitignore
├── README.md
└── requirements.txt
```

Generated Bronze, Silver, and Gold Parquet datasets are intentionally included in the repository so that the resulting data can also be reviewed without executing the pipeline.

---

## Source Data

The assessment provides three source datasets:

| Dataset | Format |
|---|---|
| `communication-samples.csv` | CSV |
| `carrier-samples.json` | JSON |
| `broker-samples.txt` | Tab-separated TXT |

---

## Pipeline

### Bronze

Notebook:

```text
src/bronze/ingestion.ipynb
```

Bronze ingests the source files, validates the expected source structure, adds ingestion metadata, and writes the datasets as Parquet.

Output:

```text
data/bronze/<dataset>/data.parquet
```

---

### Silver

Notebook:

```text
src/silver/transformation.ipynb
```

Silver creates the canonical datasets by standardizing columns, casting data types, normalizing timestamps, removing deterministic duplicates, and executing data-quality checks.

Reusable validation functions are located in:

```text
src/silver/data_quality.py
```

Output:

```text
data/silver/<dataset>/data.parquet
```

---

### Gold

Notebook:

```text
src/gold/build.ipynb
```

The Gold layer combines communications with carrier and broker information and creates response cycles used to analyze carrier responsiveness.

The model considers:

```text
Outbound:
direction = outbound
status = delivered
contact type = driver or dispatcher

Inbound:
direction = inbound
status = received
contact type = driver or dispatcher
```

Communication events are organized into conversation cycles using:

```text
external_id
carrier_name
broker_name
channel
contact_type
```

The final Gold dataset contains:

```text
external_id
carrier_name
broker_name
channel
contact_type
cycle_id
first_outbound_at
last_outbound_at
response_at
outbound_attempts
responsed
response_time
```

`response_time` is calculated in minutes between the first outbound communication in the cycle and the corresponding inbound response.

Gold is persisted both as Parquet and in PostgreSQL.

Parquet output:

```text
data/gold/carrier_risk/data.parquet
```

PostgreSQL output:

```text
public.carrier_risk
```

---

## Setup

### Python

The project was developed using:

```text
Python 3.14.2
```

Create a virtual environment:

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install the dependencies:

```bash
python -m pip install -r requirements.txt
```

Current dependencies are defined in:

```text
requirements.txt
```

---

## PostgreSQL Configuration

The local implementation uses PostgreSQL as the serving database.

Tested configuration:

```text
PostgreSQL: 18.6

Host: localhost
Port: 5432
Database: freighthero
Schema: public
```

Create a `.env` file in the repository root using `.env.example`:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=freighthero
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
```

The real `.env` file must not be committed.

---

## Running the Pipeline

The notebooks should currently be executed in the following order:

```text
1. src/bronze/ingestion.ipynb
2. src/silver/transformation.ipynb
3. src/gold/build.ipynb
```

Run each notebook completely before executing the next layer.

The resulting flow is:

```text
Samples
   ↓
Bronze Parquet
   ↓
Silver Parquet
   ↓
Gold Parquet
   ↓
PostgreSQL
```

A future improvement would be to add a single orchestration entry point so the complete pipeline can be executed with one command.

---

## Data Quality and Tests

Runtime data-quality checks are implemented in:

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

Automated tests are implemented in:

```text
tests/test_data_quality.py
```

Run them with:

```bash
python -m pytest tests/test_data_quality.py -v
```

Current test suite:

```text
test_remove_duplicates
test_validate_unique
test_validate_not_null
test_validate_timestamp_order
```

Current result:

```text
4 passed
```

---

## Linting

Ruff is used for Python linting.

Run:

```bash
python -m ruff check src tests
```

---

## Continuous Integration

GitHub Actions configuration:

```text
.github/workflows/ci.yml
```

The CI workflow runs on pushes and pull requests and performs:

```text
Install dependencies
        ↓
Ruff linting
        ↓
Pytest
        ↓
Pass / Fail
```

The workflow validates the code and automated tests before changes are integrated.

Runtime data-quality validation remains part of the pipeline itself.

---

## Infrastructure as Code

Representative Terraform configuration is available under:

```text
iac/
```

The Terraform files demonstrate how the production infrastructure could be organized using AWS services such as Glue and IAM, together with environment-specific configuration.

The IaC is included as a design and organization example for the assessment.

It has not been applied to an AWS account as part of the local implementation.

Detailed infrastructure decisions are documented in:

```text
docs/system_design.md
```

---

## Architecture Diagram

The production-oriented architecture diagram is available in Draw.io format:

```text
docs/carrier_risk.drawio
```

The diagram represents the proposed flow from external data sources through Landing, Bronze, Silver, Gold, PostgreSQL, and Metabase, together with the AWS processing and infrastructure components.

---

## Dashboard

Metabase is used as the BI layer and connects to the final PostgreSQL Gold table:

```text
public.carrier_risk
```

Tested local version:

```text
Metabase v0.63.15.5
```

The final dashboard and screenshots are still being completed and will be stored under:

```text
dashboard/
```

---

## System Design

Detailed architecture and engineering decisions are intentionally kept outside this README.

See:

```text
docs/system_design.md
```

The system design document covers topics such as:

- Local and production architecture
- Data modeling
- Schema management and schema evolution
- Data quality and failure handling
- CDC and incremental processing
- Governance and metadata
- Infrastructure as Code
- Security and access
- Scaling
- Production monitoring
- Environment strategy

This README focuses primarily on how to understand, install, run, and validate the project.

---

## Future Improvements

The following improvements can be added beyond the current implementation:

- Docker Compose for the pipeline, PostgreSQL, and Metabase
- Single-command pipeline orchestration
- Production deployment and validation of the Terraform infrastructure

---