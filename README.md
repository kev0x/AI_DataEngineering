# AI Data Engineering Lab

Design-first project for learning data engineering architecture with personal Chase
financial data. The approved v0.1 design is now being implemented with Docker, DuckDB,
FastAPI, and SQL-first ETL.

## Goal

Build a small, Dockerized, local-first data platform that ingests Chase checking and credit
card CSV exports, models them in DuckDB with medallion layers and a relational star schema,
serves safe analytics through FastAPI, and later adds a text-to-SQL AI interface over Gold
views only.

## Current Build Status

Approved sequence:

1. Use cases - approved
2. Acceptance criteria - approved
3. Schema design - approved
4. Warehouse deployment - in progress
5. API and AI query interface
6. Frontend design

## Agreed Decisions

- Keep the architecture simple: no Databricks, Spark, cloud warehouse, or heavyweight lakehouse.
- Use open-source/local tools: Python, Docker, DuckDB, FastAPI.
- Use Chase CSV exports as the v1 data source.
- Put private CSV files under `data/private/chase/`.
- Keep generated DuckDB files under `warehouse/`.
- Use Bronze, Silver, and Gold schemas in DuckDB.
- Use camel case table and column names.
- Use descriptive table names.
- Use a Silver star schema.
- Gold views are the safe AI/query contract.
- The future AI feature starts as text-to-SQL over Gold views only.

## Data Sources

Observed Chase CSV formats:

Checking export:

```text
Details, Posting Date, Description, Amount, Type, Balance, Check or Slip #
```

Credit card export:

```text
Transaction Date, Post Date, Description, Category, Type, Amount, Memo
```

Checking exports do not include categories. Credit card exports include Chase categories.

## Use Cases V0.1

1. Ingest Chase checking and credit card CSV files.
2. Preserve raw Chase data in Bronze for traceability.
3. Clean and normalize transactions into a Silver star schema.
4. Avoid double-counting spending across credit card purchases and checking payments.
5. Normalize Chase categories and rule-based checking categories into project categories.
6. Map raw transaction descriptions to normalized merchants using mapping rules.
7. Analyze monthly spending by category, parent category, merchant, and account type.
8. Identify uncategorized or poorly mapped transactions for future rule improvement.
9. Expose safe Gold analytics views for FastAPI and future AI text-to-SQL.
10. Keep sensitive raw fields out of Gold by default.

## Acceptance Criteria

To be drafted and approved next.

## Schema Design

Approved schema design:

- [Schema Design V0.1](docs/schema-design.md)

Core objects:

```text
Bronze.rawChaseCheckingTransaction
Bronze.rawChaseCreditTransaction

Silver.dimSourceFile
Silver.dimFinancialAccount
Silver.dimSpendingCategory
Silver.dimMerchant
Silver.dimCalendarDate
Silver.mapMerchantRule
Silver.mapCategoryRule
Silver.factTransaction

Gold.vw_MonthlySpendingByCategory
Gold.vw_MonthlyCashflow
Gold.vw_TopMerchantsBySpending
Gold.vw_UncategorizedTransactionSummary
Gold.vw_SpendingCategoryTrend
```

## Privacy Rules

- Do not commit files under `data/private/`.
- Do not commit local DuckDB files under `warehouse/`.
- Keep checking `Balance` in Bronze only.
- Keep raw transaction descriptions in Bronze and Silver only.
- Do not expose raw descriptions, account last four, memo, balance, check/slip number, or
  source file names in Gold views.
- Anonymization is a v2 feature, not v1.

## Docker Direction

Docker Compose uses separate services:

```text
warehouse-deploy
api
duckdb-ui
```

The warehouse deployment service reads private CSV files, deploys DuckDB objects, runs
chunked SQL ETL, then exits. The API opens DuckDB read-only and serves FastAPI endpoints.

Build the local image:

```bash
cd Docker
docker compose build
```

Start everything:

```bash
cd Docker
docker compose up -d
```

This starts a one-shot warehouse deployment and population service first, then starts the
API. Put private Chase CSV exports under:

```text
data/private/chase/
```

That folder is ignored by Git.

Check the services:

```bash
cd Docker
docker compose ps
```

Check the service:

```bash
curl http://127.0.0.1:4000/health
```

Open DuckDB UI:

```text
http://localhost:4213
```

The UI opens a separate catalog database and attaches `warehouse/finance.duckdb` as
read-only under the alias `finance`.

DuckDB UI uses its own lightweight Docker requirements file so it can run a UI-compatible
DuckDB version while the API and ETL keep the main DuckDB runtime.

The ETL is idempotent. Bronze transaction tables and `Silver.factTransaction` are loaded
with DuckDB `MERGE` statements, using source-file hashes and source row numbers as the
transaction grain.

See warehouse objects and row counts:

```bash
curl http://127.0.0.1:4000/api/warehouse/objects
curl http://127.0.0.1:4000/api/warehouse/row-counts
```

Docker-specific files live under:

```text
Docker/
  Dockerfile
  docker-compose.yml
  requirements.txt
```

## Data Warehouse Layout

SQL objects live under:

```text
DataWarehouse/
  Bronze/
    Tables/
    Views/
  Silver/
    Tables/
    Views/
    Seeds/
  Gold/
    Tables/
    Views/
  Deployment/
  DBA/
```

Deploy the current schema locally with:

```bash
.venv/bin/python DataWarehouse/Deployment/deployWarehouse.py --reset
```
