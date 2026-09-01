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