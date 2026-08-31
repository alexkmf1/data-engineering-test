````markdown
# FreightHero Carrier Profile & Risk Score Pipeline

This repository contains my implementation of the FreightHero Data Engineer Technical Assessment.

The solution follows a Medallion-style architecture:

```text
Sample Files (or Landing)
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

The local implementation uses Pandas and Parquet for data processing, PostgreSQL as the SQL serving layer, and Metabase for BI visualization.

A PySpark ingestion implementation is also included as an alternative approach for larger-scale distributed processing.

For detailed architecture decisions, schema evolution, CDC, governance, IaC, scaling, and production considerations, see:

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
│   ├── silver/
│   └── gold/
│
├── docs/
│   └── system_design.md
│   └── carrier_risk.drawio
│
├── iac/
│   └── glue_job.tf
│   └── iam-policy.tf
│   └── iam-role.tf
│   └── locals.tf
│   └── outputs.tf
│   └── provider.tf
│   └── scripts.tf
│   └── variables.tf
│
├── samples/
│   ├── broker-samples.txt
│   ├── carrier-samples.json
│   └── communication-samples.csv
│
├── src/
│   ├── bronze/
│   │   ├── ingestion.ipynb
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
├── .env
├── .env.example
├── .gitignore
├── README.md
└── requirements.txt
```

> `.env` contains local credentials and must not be committed.

---

## Source Data

The assessment provides three input datasets:

| Dataset | Format |
|---|---|
| `communication-samples.csv` | CSV |
| `carrier-samples.json` | JSON |
| `broker-samples.txt` | Tab-separated text |

---

## Pipeline

### Bronze

Notebook:

```text
src/bronze/ingestion.ipynb
```

The Bronze pipeline:

- Reads CSV, JSON, and TXT sources
- Validates expected source columns
- Preserves source column names
- Adds `_source_file`
- Adds `_ingested_at`
- Writes Parquet files to `data/bronze/`

Current output pattern:

```text
data/bronze/<dataset>/data.parquet
```

An example of timestamp-based ingestion versioning is kept in the notebook as a production consideration but is intentionally not enabled in the local implementation.

---

### Silver

Notebook:

```text
src/silver/transformation.ipynb
```

Reusable data-quality functions:

```text
src/silver/data_quality.py
```

The Silver pipeline:

- Standardizes column names
- Casts data types
- Parses timestamps as UTC
- Removes deterministic duplicate business records
- Runs data-quality validations
- Adds `_transformed_at`
- Writes Parquet files to `data/silver/`

Example source correction:

```text
broker_comany_id
→
broker_company_id
```

---

### Gold

Notebook:

```text
src/gold/build.ipynb
```

The current Gold implementation joins:

```text
communications
+ carriers
+ brokers
```

and removes technical metadata from the business-facing output.

# 🚧 GOLD MODEL IN PROGRESS

The final Gold model still needs to define:

- Final analytical grain
- Carrier performance metrics
- Responsiveness metrics
- Carrier Risk Score
- Risk classification
- Final Gold table or tables

The current Gold output is temporary and is being used to validate the PostgreSQL and Metabase integration.

---

## Data Quality

Runtime data-quality functions are located in:

```text
src/silver/data_quality.py
```

Current checks include:

- Duplicate removal
- Uniqueness validation
- Not-null validation
- Timestamp-order validation

Runtime validation checks the actual pipeline data.

Pytest is used separately to verify that the validation functions behave correctly.

---

## Automated Tests

Tests:

```text
tests/test_data_quality.py
```

Current tests:

```text
test_remove_duplicates
test_validate_unique
test_validate_not_null
test_validate_timestamp_order
```

Run:

```bash
python -m pytest tests/test_data_quality.py -v
```

Current result:

```text
4 passed
```

---

## Requirements

Current Python version:

```text
Python 3.14.2
```

Python dependencies:

```text
pyspark==4.2.0
pandas==3.0.5
pyarrow==25.0.1
pytest==9.1.1
SQLAlchemy==2.0.52
psycopg==3.3.4
python-dotenv==1.2.3
```

Install them with:

```bash
python -m pip install -r requirements.txt
```

A Python virtual environment is recommended:

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

Then:

```bash
python -m pip install -r requirements.txt
```

---

## Local Software Versions

The implementation was developed and tested with:

```text
Python: 3.14.2
Java: Temurin OpenJDK 25.0.4.1 LTS
PostgreSQL: 18.6
Metabase: v0.63.15.5
```

Metabase build:

```text
Version: v0.63.15.5
Built: 2026-08-28
Hash: a1b5b62
```

---

## Environment Variables

Create a `.env` file at the repository root using `.env.example` as a template:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=freighthero
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
```

Never commit the real `.env` file.

---

## Running the Pipeline

### Current Method

The pipeline is currently executed through VS Code / Jupyter.

Run the notebooks in this order:

```text
1. src/bronze/ingestion.ipynb
2. src/silver/transformation.ipynb
3. src/gold/build.ipynb
```

Use **Run All** for each notebook before moving to the next layer.

Then run:

```bash
python -m pytest tests/test_data_quality.py -v
```

# 🚧 PLANNED

Before submission, a single orchestration entry point will be added so the entire pipeline can be executed with one command.

---

## PostgreSQL

Local PostgreSQL configuration:

```text
Host: localhost
Port: 5432
Database: freighthero
Schema: public
Version: 18.6
```

The Gold notebook connects using SQLAlchemy and Psycopg.

# 🚧 TEMPORARY TABLE

The current implementation writes a temporary table:

```text
public.carrier_risk
```

using a limited example dataset.

This table will be replaced once the final Carrier Risk Score model is complete.

---

## Metabase

Current Metabase version:

```text
v0.63.15.5
```

Metabase connects to:

```text
PostgreSQL
Host: localhost
Port: 5432
Database: freighthero
Schema: public
```

A temporary dashboard has already been created to validate the connection.

# 🚧 FINAL DASHBOARD IN PROGRESS

The final dashboard will be created after the Gold model and Carrier Risk Score are finalized.

The final submission will include dashboard screenshots and configuration notes under:

```text
dashboard/
```

---

## CI/CD

# 🚧 NOT IMPLEMENTED YET

The planned GitHub Actions workflow is:

```text
.github/workflows/ci.yml
```

It will execute tasks such as:

```text
Install dependencies
Run linting
Run Pytest
```

CI will validate the code and automated tests.

Runtime validation of incoming data remains part of the pipeline.

---

## Infrastructure as Code

# 🚧 NOT IMPLEMENTED YET

Terraform will be added under:

```text
iac/
```

The detailed IaC approach is documented in:

```text
docs/system_design.md
```

---

## Docker

# 🚧 PLANNED — NOT IMPLEMENTED YET

Docker Compose is planned for the final submission to make the environment easier to reproduce.

The intended containerized environment will include:

```text
Python pipeline
PostgreSQL
Metabase
```

Target versions:

```text
Python: 3.14.2
PostgreSQL: 18.6
Metabase: v0.63.15.5
```

The repository will contain Docker configuration rather than installers or application binaries.

Files such as the following should not be committed:

```text
Java installer
PostgreSQL installer
metabase.jar
PostgreSQL data directory
Metabase internal application database
```

---

## Generated Data

Current generated datasets are stored under:

```text
data/
├── bronze/
├── silver/
└── gold/
```

# 🚧 FINAL SUBMISSION DECISION REQUIRED

A final decision will be made on whether the generated Bronze, Silver, and Gold outputs should remain committed to make evaluation easier, or whether they should be regenerated by running the pipeline.

---

## System Design

Detailed technical design is documented separately:

```text
docs/system_design.md
```

That document covers:

- Architecture decisions
- Data modeling
- Schema evolution
- CDC considerations
- Governance
- Failure handling
- Infrastructure as Code
- Production considerations
- Scaling
- Observability
- System diagram

This README intentionally keeps those topics brief to avoid duplicating the system design document.

---


# Original FreightHero Assessment

The original FreightHero assessment README should remain below this line unchanged.

# Data Engineer – Technical Assessment

## Candidate Instructions

This assessment evaluates your ability to design, document, and implement a small end‑to‑end data pipeline while demonstrating strong communication skills and ownership. The role requires hands-on infrastructure work, clear stakeholder interaction, and adherence to best practices such as Infrastructure as Code (IaC), documentation, and data quality standards.

## 1. Assessment Case: Carrier Profile & Risk Score Pipeline

You will design and implement a pipeline that produces a Carrier Risk Score using anonymized internal datasets. Inputs may include multiple formats:

- CSV
- JSON
- Parquet
- Semi‑structured logs

These datasets contain metrics such as responsiveness. Your goal is to unify these sources, model the data, compute the score, and expose it for BI consumption.

## 2. Deliverables

### 2.1 System Design Document

Provide a concise technical document including:

- End‑to‑end pipeline architecture (extraction → transformation → loading)
- Tooling decisions with justification
- Infrastructure provisioning approach using IaC principles
- Data modeling strategy, including schema design and handling of schema evolution
- CDC (Change Data Capture) considerations for SQL and NoSQL
- Governance elements: naming conventions, data quality tests, metadata lifecycle
- A system diagram (Mermaid, Draw.io, or equivalent)

### 2.2 Pipeline Implementation (Local or Docker)

Implement a minimal working pipeline that:

- Extracts data from the provided files
- Transforms and unifies the data
- Loads results into a local SQL database (SQLite or Postgres)
- Computes the Carrier Risk Score
- Makes the final dataset available for BI tools

#### Requirements

- Git‑based version control
- CI/CD workflow (linting + tests)
- Documentation on how to run the pipeline locally
- At least three data quality tests

#### Optional (but valued)

- Docker Compose
- IaC snippet for provisioning local infra
- CDC simulation (incremental updates)

### 2.3 BI / Dashboard

Create a simple dashboard using Metabase/Similar (or outline the configuration if not installing):

- 2–3 charts showing carrier performance
- Explanation of permissions and metadata management
- Notes on plugin or connection setup if applicable

### 2.4 Stakeholder Presentation

Prepare a 5–7 minute explanation targeted at non‑technical stakeholders covering:

- What the pipeline does
- Why the chosen tools matter
- How the Risk Score supports operations
- Limitations and future improvements

## 3. Submission Package

Submit the following:

- `/docs/system_design.md`
- `/src/` pipeline code
- `/iac/` IaC snippet or outline
- `/tests/` data quality tests
- `dashboard` screenshots, public URLs or configuration notes
- `README.md` with setup instructions

## 4. Interview Deep Dive

During the interview, you will walk through:

- Architecture decisions
- Scaling considerations
- Handling schema drift
- Cataloging and metadata strategy
- Governance improvements

````