# FreightHero Carrier Profile

This repository contains my implementation of the FreightHero Data Engineer Technical Assessment. It builds a local end-to-end pipeline that ingests the provided carrier, broker, and communication files, creates Bronze, Silver, and Gold datasets, loads the final Gold dataset into PostgreSQL, and exposes it to Metabase.

## Run the Project (Start Here)

The exact local execution order is:

```text
1. Prepare Python and .env
2. Start PostgreSQL and Metabase with Docker Compose
3. Run Bronze completely
4. Run Silver completely
5. Run Gold completely
6. Verify PostgreSQL
7. Open and configure Metabase
```

The three notebooks must be run **one at a time and in this order**. Do not run them in parallel because each layer reads the output created by the previous layer.

Docker Compose starts **PostgreSQL and Metabase**. The notebooks themselves run from the Python environment on the host machine.

### 1. Prerequisites

Install the following before running the project:

- Git
- Python 3.14 (tested with Python 3.14.2)
- Docker Desktop with Docker Compose
- VS Code with Python and Jupyter notebook support, or another compatible notebook environment

Verify the main tools:

```powershell
python --version
docker --version
docker compose version
```

The following host ports must be available:

| Port | Service |
|---:|---|
| `5432` | Docker PostgreSQL |
| `3000` | Docker Metabase |

If PostgreSQL or Metabase is already running locally on either port, stop that local service before starting Docker. On Windows, local PostgreSQL services can be listed with:

```powershell
Get-Service *postgres*
```

### 2. Open the Repository Root

Run every terminal command in this section from the repository root, where `docker-compose.yml` and `requirements.txt` are located.

```powershell
cd "path\to\data-engineering-test"
```

### 3. Create the Python Environment

Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the dependencies:

```powershell
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

On macOS or Linux, activate the environment with:

```bash
source .venv/bin/activate
```

When opening a notebook in VS Code, select this `.venv` as its Python kernel. If VS Code asks to install notebook kernel support in the environment, allow it to do so.

### 4. Create `.env`

Copy the example configuration:

```powershell
Copy-Item .env.example .env
```

On macOS or Linux:

```bash
cp .env.example .env
```

Review `.env` and set a local PostgreSQL password:

```dotenv
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=freighthero
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
```

Keep `POSTGRES_HOST=localhost`. The Gold notebook runs on the host machine and connects through Docker's published port. The real `.env` is ignored by Git and must not be committed.

### 5. Start PostgreSQL and Metabase

Validate the Compose file:

```powershell
docker compose config --quiet
```

Start both services in the background:

```powershell
docker compose up -d
```

The first start can take longer while Docker downloads the PostgreSQL and Metabase images.

Check their status:

```powershell
docker compose ps
```

Expected state:

```text
freighthero-postgres    running (healthy)
freighthero-metabase    running
```

If PostgreSQL is still starting, wait a few seconds and run `docker compose ps` again. If a container exits, inspect it with:

```powershell
docker compose logs postgres --tail=100
docker compose logs metabase --tail=100
```

### 6. Run the Three Notebooks, One at a Time

Open each notebook from its existing folder, select the `.venv` kernel, and use **Run All**. Wait for the current notebook to finish successfully before opening the next one.

#### A. Bronze

Run first:

```text
src/bronze/ingestion.ipynb
```

Bronze reads the three source files, validates their expected columns, adds ingestion metadata, and writes:

```text
data/bronze/communications/data.parquet
data/bronze/brokers/data.parquet
data/bronze/carriers/data.parquet
```

Wait until all three datasets report that they were saved successfully.

#### B. Silver

Run second:

```text
src/silver/transformation.ipynb
```

Silver reads Bronze, renames and casts columns, removes deterministic duplicates, runs the configured data-quality validations, and writes:

```text
data/silver/communications/data.parquet
data/silver/brokers/data.parquet
data/silver/carriers/data.parquet
```

Wait until all three datasets report that they were transformed, validated, and saved successfully.

#### C. Gold

Run last:

```text
src/gold/build.ipynb
```

Gold reads Silver, joins carrier and broker information, builds the carrier response dataset, and writes it to both:

```text
data/gold/carrier_risk/data.parquet
public.carrier_risk in PostgreSQL
```

The PostgreSQL table is written with `if_exists="replace"`, so rerunning Gold replaces the existing `public.carrier_risk` table with the newly calculated result.

The notebooks use paths relative to their own folders. Run the listed notebooks from their existing locations and do not change their working directories. `src/bronze/ingestion_backlog.ipynb` is not part of the normal three-step execution flow.

### 7. Verify the PostgreSQL Output

With the default database and user from `.env`, run:

```powershell
docker exec freighthero-postgres psql -U postgres -d freighthero -c "SELECT COUNT(*) FROM public.carrier_risk;"
```

The query should return a row count. You can also inspect the table with pgAdmin using:

```text
Host: localhost
Port: 5432
Database: freighthero
Username: postgres
Password: the value from .env
```

### 8. Open and Configure Metabase

Open:

```text
http://localhost:3000
```

On a new Docker volume, Metabase will show its first-time setup. When adding the FreightHero PostgreSQL database, use:

```text
Display name: FreightHero
Host: postgres
Port: 5432
Database: freighthero
Username: postgres
Password: the value from .env
SSL: off for this local environment
```

The hostname difference is important:

| Client | PostgreSQL address |
|---|---|
| Gold notebook on the host | `localhost:5432` |
| pgAdmin on the host | `localhost:5432` |
| Metabase inside Docker | `postgres:5432` |
| Browser opening Metabase | `http://localhost:3000` |

Inside the Metabase container, `localhost` means the Metabase container itself. Docker Compose provides `postgres` as the network hostname of the PostgreSQL service.

If `public.carrier_risk` does not appear after Gold finishes:

1. Open Metabase Admin settings.
2. Open Databases and select `FreightHero`.
3. Run **Sync database schema now**.
4. Wait a few seconds and browse the `public` schema again.

### 9. Stop and Restart the Environment Safely

Stop the containers without deleting their data:

```powershell
docker compose down
```

Start them again later:

```powershell
docker compose up -d
```

Docker Compose uses two named volumes:

```text
postgres_data → PostgreSQL data, including public.carrier_risk
metabase_data → Metabase settings, questions, and dashboards
```

Do **not** run `docker compose down -v` during normal use. The `-v` option deletes both named volumes, including the database table and Metabase application state. Use it only when intentionally performing a complete local reset.

---

## Local Architecture

```text
samples/ CSV, JSON, TXT
          ↓
src/bronze/ingestion.ipynb
          ↓
data/bronze/*.parquet
          ↓
src/silver/transformation.ipynb
          ↓
data/silver/*.parquet
          ↓
src/gold/build.ipynb
          ├──────────────→ data/gold/carrier_risk/data.parquet
          │
          │ localhost:5432
          ↓
Docker PostgreSQL: public.carrier_risk
          ↑
          │ postgres:5432
Docker Metabase
          ↑
          │ http://localhost:3000
       Browser
```

Pandas and Parquet are used for local processing, PostgreSQL is the SQL serving layer, and Metabase is the BI layer. Docker Compose makes the serving and visualization services reproducible while named volumes preserve their local state.

A representative production architecture using S3, AWS Glue, IAM, and Terraform is documented in `docs/system_design.md`.

## Project Structure

```text
data-engineering-test/
├── .github/
│   └── workflows/
│       └── ci.yml
├── dashboard/
│   ├── README.md
│   ├── Metabase - Carrier Responsiveness Risk.pdf
│   └── carrier-responsiveness-risk-dashboard.png
├── data/
│   ├── bronze/
│   ├── silver/
│   └── gold/
│       └── carrier_risk/
├── docs/
│   ├── carrier_risk.drawio
│   ├── README_original.md
│   └── system_design.md
├── iac/
│   └── Terraform configuration
├── samples/
│   ├── broker-samples.txt
│   ├── carrier-samples.json
│   └── communication-samples.csv
├── src/
│   ├── bronze/
│   │   └── ingestion.ipynb
│   ├── silver/
│   │   ├── data_quality.py
│   │   └── transformation.ipynb
│   └── gold/
│       └── build.ipynb
├── tests/
│   └── test_data_quality.py
├── .env.example
├── .gitignore
├── docker-compose.yml
├── README.md
└── requirements.txt
```

Generated Bronze, Silver, and Gold Parquet datasets are intentionally included so that the result can be reviewed without rerunning the pipeline.

## Source Data

| Dataset | Format | Purpose |
|---|---|---|
| `communication-samples.csv` | CSV | Communication events and response behavior |
| `carrier-samples.json` | JSON | Carrier reference data |
| `broker-samples.txt` | Tab-separated TXT | Broker reference data |

## Pipeline Details

### Bronze

`src/bronze/ingestion.ipynb` preserves the source structure, validates required columns, adds `_source_file` and `_ingested_at`, and stores one Parquet dataset per source entity.

### Silver

`src/silver/transformation.ipynb` creates canonical datasets by:

- Renaming source columns, including `broker_comany_id` to `broker_company_id`
- Casting configured data types and timestamps
- Removing deterministic duplicates
- Validating uniqueness where applicable
- Validating required values
- Validating timestamp order
- Adding `_transformed_at`

Reusable validations are implemented in `src/silver/data_quality.py`.

### Gold

`src/gold/build.ipynb` joins communications with carrier and broker names and considers the following events:

```text
Outbound:
direction = outbound
status = delivered
to contact type = driver or dispatcher

Inbound:
direction = inbound
status = received
from contact type = driver or dispatcher
```

Events are grouped using:

```text
external_id
carrier_name
broker_name
channel
contact_type
```

Including `channel` means that a response is matched within the same channel. Cross-channel responses are not treated as the same response in the current implementation.

The stakeholder clarification defines `external_id` as the load identifier and `thread_id` as a thread within the communication history. The current Gold grouping does not include `thread_id`, so separate threads can be combined when all other grouping values are identical. This is a documented limitation that should be resolved before production use.

The current grouping also uses `carrier_name` and `broker_name` because those are the fields exposed in Gold. A production version should retain the company IDs in Gold and use the stable IDs for grouping and joins while keeping names for display.

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

`response_time` is measured in minutes from the first outbound communication in a group to its inbound response. Only groups with at least one outbound attempt are retained.

## Dashboard

Metabase reads `public.carrier_risk`. The dashboard provides one prioritization view and two diagnostic views:

1. Which carriers have the highest communication-responsiveness Risk Score?
2. Which carriers have the lowest response rate?
3. When carriers respond, which have the slowest average response time?

The dashboard setup, SQL, chart configuration, filter mapping, and screenshot are documented in `dashboard/README.md`.

The exported dashboard is available at:

```text
dashboard/Metabase - Carrier Responsiveness Risk.pdf
```

On a clean Metabase installation, the questions can be recreated with the following SQL.

### Carrier Responsiveness Risk Score

```sql
WITH carrier_metrics AS (
    SELECT
        carrier_name,
        COUNT(*) AS total_records,
        COUNT(*) FILTER (WHERE responsed = TRUE) AS responded_records,
        COUNT(*) FILTER (WHERE responsed = FALSE) AS unanswered_records,
        COUNT(*) FILTER (WHERE responsed = TRUE)::numeric
            / NULLIF(COUNT(*), 0) AS response_rate,
        AVG(response_time) FILTER (
            WHERE responsed = TRUE
                AND response_time IS NOT NULL
        ) / 60.0 AS avg_response_time_hours
    FROM public.carrier_risk
    WHERE carrier_name IS NOT NULL
        [[AND channel = {{channel}}]]
    GROUP BY carrier_name
    HAVING COUNT(*) >= 10
),
delay_ranking AS (
    SELECT
        carrier_name,
        PERCENT_RANK() OVER (
            ORDER BY avg_response_time_hours ASC
        ) AS delay_risk
    FROM carrier_metrics
    WHERE responded_records > 0
        AND avg_response_time_hours IS NOT NULL
),
score_components AS (
    SELECT
        metrics.carrier_name,
        metrics.total_records,
        metrics.responded_records,
        metrics.unanswered_records,
        metrics.response_rate,
        metrics.avg_response_time_hours,
        1.0 - metrics.response_rate AS non_response_risk,
        COALESCE(delay.delay_risk::numeric, 1.0) AS delay_risk,
        CASE
            WHEN metrics.responded_records = 0 THEN 1.0
            ELSE
                0.50 * (1.0 - metrics.response_rate)
                + 0.50 * COALESCE(delay.delay_risk::numeric, 1.0)
        END AS risk_score_ratio
    FROM carrier_metrics AS metrics
    LEFT JOIN delay_ranking AS delay
        ON metrics.carrier_name = delay.carrier_name
),
scored_carriers AS (
    SELECT
        carrier_name,
        total_records,
        responded_records,
        unanswered_records,
        ROUND(response_rate * 100.0, 2) AS response_rate_percent,
        ROUND(
            avg_response_time_hours::numeric,
            2
        ) AS avg_response_time_hours,
        ROUND(
            non_response_risk * 100.0,
            2
        ) AS non_response_risk_percent,
        ROUND(
            delay_risk * 100.0,
            2
        ) AS delay_risk_percent,
        ROUND(
            risk_score_ratio * 100.0,
            2
        ) AS risk_score
    FROM score_components
)
SELECT
    carrier_name,
    total_records,
    responded_records,
    unanswered_records,
    response_rate_percent,
    avg_response_time_hours,
    non_response_risk_percent,
    delay_risk_percent,
    risk_score,
    CASE
        WHEN risk_score >= 66.67 THEN 'High'
        WHEN risk_score >= 33.33 THEN 'Medium'
        ELSE 'Low'
    END AS risk_level
FROM scored_carriers
ORDER BY
    risk_score DESC,
    total_records DESC;
```

The score is intentionally explainable:

```text
Risk Score = 100 × (
    0.50 × non-response risk
    + 0.50 × response-delay risk
)
```

- `non-response risk = 1 - response rate`
- `response-delay risk` is the relative `PERCENT_RANK()` of average response time among eligible carriers
- A carrier with no responses receives `100`, the maximum communication-responsiveness risk
- A carrier must have at least 10 response-cycle records within the selected channel
- The equal weights, minimum sample, and Low/Medium/High thresholds are analytical assumptions that require stakeholder validation
- This is a communication-responsiveness score, not a safety, financial, fraud, or delivery-risk score

### Lowest Response Rate by Carrier

```sql
SELECT
    carrier_name,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE responsed = TRUE) AS responded_records,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE responsed = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS response_rate_percent
FROM public.carrier_risk
WHERE carrier_name IS NOT NULL
    [[AND channel = {{channel}}]]
GROUP BY carrier_name
HAVING COUNT(*) >= 10
ORDER BY response_rate_percent ASC;
```

Recommended visualization: horizontal bar chart, `carrier_name` as the category, `response_rate_percent` as the value, and `%` as the suffix.

### Slowest Average Response Time by Carrier

```sql
SELECT
    carrier_name,
    COUNT(*) FILTER (WHERE responsed = TRUE) AS responded_records,
    ROUND(
        (
            AVG(response_time) FILTER (
                WHERE responsed = TRUE
                    AND response_time IS NOT NULL
            )
        )::numeric / 60.0,
        2
    ) AS avg_response_time_hours
FROM public.carrier_risk
WHERE carrier_name IS NOT NULL
    [[AND channel = {{channel}}]]
GROUP BY carrier_name
HAVING COUNT(*) >= 10
    AND COUNT(*) FILTER (WHERE responsed = TRUE) > 0
ORDER BY avg_response_time_hours DESC;
```

Recommended visualization: bar chart, `carrier_name` as the category, `avg_response_time_hours` as the value, and `hours` as the unit.

The optional `channel` parameter is configured as a Metabase Text variable and mapped to one dashboard-level channel filter. The minimum of 10 records reduces unstable conclusions based on very small samples; it is an analytical threshold, not a confirmed business rule.

The current Gold result is effectively email-only because the implemented outbound rule requires `status = delivered`. SMS primarily uses `sent`, and chat requires additional contact/status rules. Those channels should not be presented as fully supported until their business rules are implemented and validated.

Metabase v0.63.15.5 is pinned in `docker-compose.yml`.

## Data Quality and Tests

Runtime data-quality checks are implemented in `src/silver/data_quality.py`. Automated tests are in `tests/test_data_quality.py`.

Run the tests from the repository root:

```powershell
python -m pytest tests/test_data_quality.py -v
```

The test suite covers:

- Duplicate removal
- Uniqueness validation
- Not-null validation
- Timestamp-order validation

## Linting

Ruff is used for Python linting:

```powershell
python -m ruff check src/silver/data_quality.py tests
```

## Continuous Integration

`.github/workflows/ci.yml` runs the same targeted lint command and the data-quality tests on pushes and pull requests. Runtime data-quality validation remains part of the Silver pipeline.

## Infrastructure as Code

Representative Terraform configuration is available under `iac/`. It demonstrates how AWS Glue and IAM resources could be organized with environment-specific configuration.

The Terraform configuration is a design example for the assessment and has not been applied to an AWS account. Detailed decisions are documented in `docs/system_design.md`.

## Architecture Diagram and System Design

The production-oriented Draw.io diagram is available at `docs/carrier_risk.drawio`.

`docs/system_design.md` covers:

- Local and proposed production architecture
- Data modeling and schema evolution
- Data quality and failure handling
- CDC and incremental processing
- Governance and metadata
- Infrastructure as Code
- Security and access
- Scaling, monitoring, and environment strategy

## Current Limitations and Future Improvements

- The pipeline notebooks are executed manually; add a single orchestration entry point.
- Package notebook logic as executable Python or PySpark jobs for production deployment.
- Automate Metabase question and dashboard provisioning for a completely clean environment.
- Apply and validate the Terraform configuration in a real AWS environment.
- Add incremental ingestion or CDC when operational database sources are available.
- Confirm communication and response-matching assumptions with business stakeholders.
