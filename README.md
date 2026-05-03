# AI Data Engineering Lab

Design-first project for learning data engineering architecture with personal Chase
financial data. No implementation will be added until the architecture is reviewed and
approved.

## Goal

Build a small, Dockerized, local-first data platform that ingests Chase checking and credit
card CSV exports, models them in DuckDB with medallion layers and a relational star schema,
serves safe analytics through FastAPI, and later adds a text-to-SQL AI interface over Gold
views only.

## Current Design Status

The project is in planning mode.

Approval sequence:

1. Use cases - approved
2. Acceptance criteria - approved
3. Schema design - approved
4. API and AI query interface
5. Frontend design
6. Implementation plan

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

Docker Compose will use separate services:

```text
etl
api
```

The ETL service reads private CSV files and builds DuckDB, then exits. The API service opens
DuckDB read-only and serves FastAPI endpoints.

## Data Warehouse Layout

SQL objects live under:

```text
DataWarehouse/
  Bronze/
    Tables/
    Views/
    Sequences/
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
