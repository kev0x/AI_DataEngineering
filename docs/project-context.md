# Project Context And Design Progress

This file captures the project context and decisions so the work can continue cleanly if the
conversation context is lost.

## Project Goal

Build a small, Dockerized, local-first data engineering project for personal Chase financial
data. The purpose is to learn architecture, schema design, ETL, DuckDB, FastAPI, React,
and later AI text-to-SQL over safe analytical views.

The project should stay simple:

- No Databricks.
- No Spark.
- No cloud warehouse in v1.
- No hosted AI over private data in v1.
- Use open-source/local tools.

## Current Repo State

The earlier mock implementation was removed after the user asked to return to design-first
mode. The repo now contains the approved warehouse layout, Docker services, a FastAPI app,
DuckDB UI wiring, SQL-first ETL, data trust DBA checks, rule-driven classification, and a
modular React dashboard.

Current intended tracked files:

```text
README.md
.gitignore
.dockerignore
Docker/
Frontend/
app/
docs/project-context.md
docs/schema-design.md
DataWarehouse/
```

Private and generated paths are ignored:

```text
data/private/
data/sample statements/
data/bronze/
data/silver/
data/gold/
data/anonymized/
warehouse/
.venv/
```

Python 3.12 was installed locally through Homebrew and a `.venv` was created earlier, but
Docker dependencies are tracked in `Docker/requirements.txt`.

Current implementation direction:

- `Docker/docker-compose.yml` starts the one-shot `warehouse-deploy` service first, then
  starts `api` and `duckdb-ui`.
- `Frontend/` contains the React + Vite dashboard with components and domain modules.
- `DataWarehouse/Deployment/deployWarehouse.py` deploys schemas, tables, seeds, and views.
- `DataWarehouse/Deployment/populateWarehouse.py` stages private Chase CSV files and runs
  ETL SQL scripts.
- ETL SQL files live under `DataWarehouse/ETL/`.
- Transaction ETL is chunked by temporary queue tables.
- Bronze and Silver transaction loads use DuckDB `MERGE` statements for idempotency.
- Silver transformations create temporary process tables, dedupe with `row_number()`, then
  `MERGE`.
- Generated key defaults live in the table DDL and are backed by DuckDB sequences.
- Business classification belongs in `Silver.mapCategoryRule`; ETL source parsing should
  not grow merchant-specific hardcoded category logic.

## Data Sources

Primary v1 data source: Chase CSV transaction exports.

Observed checking CSV shape:

```text
Details, Posting Date, Description, Amount, Type, Balance, Check or Slip #
```

Observed credit card CSV shape:

```text
Transaction Date, Post Date, Description, Category, Type, Amount, Memo
```

Important observations:

- Checking CSVs do not include categories.
- Credit card CSVs include Chase categories.
- Checking has a `Balance` column.
- Credit has both transaction date and post date.
- Checking has only posting date.
- Neither CSV has a source transaction ID.

## Approved Use Cases V0.1

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

## Approved Acceptance Criteria V0.1

1. Chase CSV files are read from `data/private/chase/`.
2. `data/private/` and `warehouse/` are ignored by git.
3. `docker compose run --rm etl` builds the DuckDB warehouse.
4. `docker compose up api` starts the FastAPI service.
5. ETL and API run as separate Docker Compose services.
6. DuckDB contains Bronze raw tables for checking and credit card exports.
7. Bronze preserves source-shaped fields, including checking `Balance`.
8. Bronze records include source file metadata and source row number.
9. Silver contains a constrained relational star schema.
10. Silver uses camel case columns.
11. Silver includes primary keys, foreign keys, unique constraints, not-null constraints,
    and check constraints where appropriate.
12. Credit card `Sale` transactions count as spending.
13. Credit card `Return` transactions reduce spending.
14. Credit card `Payment` transactions do not count as spending.
15. Checking transfers do not count as spending.
16. Checking credit card payments do not count as spending.
17. Checking debit transactions may count as spending when rules classify them that way.
18. Credit card Chase categories are mapped to normalized project categories.
19. Checking categories are assigned using conservative rules.
20. Transactions retain both source category and normalized category.
21. Transactions retain category rule lineage.
22. Merchant assignment uses a merchant rule table when a rule matches.
23. Transactions retain merchant rule lineage.
24. Gold views expose safe analytics only.
25. Gold views do not expose raw descriptions, account last four, balance, memo,
    check/slip number, or source file names.
26. Gold views may expose account type.
27. FastAPI exposes health, predefined analytics endpoints, and guarded read-only SQL
    against Gold only.
28. Text-to-SQL is designed as an interface in v1 but does not require a working LLM.
29. Smoke tests verify warehouse build, row counts, spending semantics, and Gold privacy.
30. Add a synthetic transaction generator utility for safe fake Chase-like CSV data.
31. ETL must be idempotent: rerunning ingestion with the same source files must not create
    duplicates.

## Naming Conventions

Schemas:

```text
Bronze
Silver
Gold
```

Tables:

```text
SchemaName.factTableName
SchemaName.dimTableName
SchemaName.mapTableName
SchemaName.rawTableName
```

Views:

```text
SchemaName.vw_AnalyticsMetricAggregation
```

Use camel case for table names and column names.

Examples:

```text
Silver.factTransaction
Silver.dimMerchant
Gold.vw_MonthlySpendingByCategory
```

Surrogate primary keys use the `Key` suffix:

```text
transactionKey
merchantKey
financialAccountKey
spendingCategoryKey
sourceFileKey
calendarDateKey
merchantRuleKey
categoryRuleKey
```

## Approved Layer Design

Bronze:

```text
Bronze.rawChaseCheckingTransaction
Bronze.rawChaseCreditTransaction
```

Silver:

```text
Silver.dimSourceFile
Silver.dimFinancialAccount
Silver.dimSpendingCategory
Silver.dimMerchant
Silver.dimCalendarDate
Silver.mapMerchantRule
Silver.mapCategoryRule
Silver.factTransaction
```

Gold:

```text
Gold.vw_MonthlySpendingByCategory
Gold.vw_MonthlyCashflow
Gold.vw_TopMerchantsBySpending
Gold.vw_UncategorizedTransactionSummary
Gold.vw_SpendingCategoryTrend
```

## Approved Data Semantics

Double counting rule:

- Credit card purchases count as spending.
- Credit card returns reduce spending.
- Credit card payments do not count as spending.
- Checking transfers do not count as spending.
- Checking payments to clear the credit card do not count as spending.

Checking category strategy:

- Use conservative rule-based categorization.
- Leave uncertain rows uncategorized.
- Add more rules later as more data is reviewed.

Category strategy:

- Store the source Chase category when available.
- Store the normalized project category separately.
- Store category assignment lineage.

Merchant strategy:

- Use merchant mapping rules.
- Store raw descriptions in Bronze and Silver.
- Do not expose raw descriptions in Gold.

Balance strategy:

- Keep checking balance in Bronze only.
- Do not promote balance to Silver or Gold in v1.

Gold privacy strategy:

- Gold is the AI/query contract.
- Future text-to-SQL should query only Gold views by default.
- Gold may expose account type but not account last four or account display name.

## Approved Schema Decisions

1. Use a Silver star schema.
2. Use integer surrogate primary keys.
3. Also define unique natural keys where useful.
4. Generate integer IDs deterministically during ETL with `row_number()` over sorted
   natural keys where practical.
5. Use `Key` suffix for surrogate keys.
6. Use `YYYYMMDD` integer keys for `Silver.dimCalendarDate.calendarDateKey`.
7. For checking, use `Posting Date` as both transaction date and posted date.
8. For credit, use `Transaction Date` as transaction date and `Post Date` as posted date.
9. Do not add `transactionDirection`.
10. Do not split amount into signed and absolute fields in Silver.
11. Use:

```text
transactionAmount
transactionType
transactionEventType
```

12. `transactionAmount` preserves Chase's signed amount.
13. `transactionType` stores the raw Chase type.
14. `transactionEventType` stores the normalized event type.
15. `transactionEventType` is a constrained text field on `Silver.factTransaction`, not a
    separate dimension in v1.
16. Allowed event types:

```text
purchase
refund
payment
income
transfer
fee
debtPayment
other
```

17. `Silver.mapCategoryRule` assigns both `spendingCategoryKey` and
    `transactionEventType`.
18. `Silver.dimSpendingCategory` uses simple parent category text, not a self-reference.
19. `Silver.dimSourceFile` stores file name and hash, not full local file path.
20. Do not create artificial `NaturalKey` columns when the natural key can be represented
    as a unique constraint over real business columns.
21. `Silver.dimFinancialAccount` should not have `accountNaturalKey`.
22. `Silver.dimFinancialAccount` natural key should be a unique constraint over:

```text
institutionName
accountType
accountLastFour
```

23. To keep that unique constraint practical, use `accountLastFour = 'unknown'` when
    the last four is unavailable.
24. `Silver.dimMerchant` should not have `merchantNaturalKey`.
25. `Silver.dimMerchant.merchantNormalizedName` is the unique natural key.
26. `Silver.mapMerchantRule` should reference `Silver.dimMerchant` with `merchantKey`.
27. `Silver.mapMerchantRule` uses `descriptionMatchType` and `descriptionMatchText`.
28. Merchant and category description matching supports:

```text
exact
startsWith
contains
```

29. Rule matching is case-insensitive after ETL normalization.
30. Rule priority convention is: higher number wins.
31. `Silver.mapCategoryRule` uses the same description matching style as merchant rules.
32. `categoryAssignmentSource` allowed values:

```text
chaseMapped
rule
fallback
manual
ai
```

33. In v1, only `chaseMapped`, `rule`, and `fallback` are implemented.
34. Fallback classification should mostly live in seeded low-priority
    `Silver.mapCategoryRule` rows.
35. `Silver.mapCategoryRule` should not include amount sign conditions.
36. Do not add `Silver.dimTransactionType` in v1; keep `transactionType` as text on
    `Silver.factTransaction`.

## Proposed Table Sketches

These are not final DDL yet.

```text
Silver.dimSourceFile
  sourceFileKey
  sourceFileName
  sourceFileHash
  sourceFileType
  sourceSystemName
  loadedAt
  rowCount
```

```text
Silver.dimFinancialAccount
  financialAccountKey
  institutionName
  accountType
  accountLastFour
  accountDisplayName
  isActive
```

```text
Silver.dimSpendingCategory
  spendingCategoryKey
  spendingCategoryName
  parentSpendingCategoryName
  spendingCategoryDescription
  isActive
```

```text
Silver.dimMerchant
  merchantKey
  merchantNormalizedName
  merchantDisplayName
  isActive
```

```text
Silver.dimCalendarDate
  calendarDateKey
  calendarDate
  calendarYear
  calendarQuarter
  calendarMonth
  calendarMonthName
  calendarMonthNumber
  calendarDayOfMonth
  calendarDayOfWeek
  calendarDayName
  isWeekend
  yearMonth
  monthStartDate
  monthEndDate
```

```text
Silver.mapMerchantRule
  merchantRuleKey
  ruleName
  descriptionMatchType
  descriptionMatchText
  merchantKey
  rulePriority
  isActive
```

```text
Silver.mapCategoryRule
  categoryRuleKey
  ruleName
  sourceAccountType
  sourceCategoryName
  transactionType
  descriptionMatchType
  descriptionMatchText
  spendingCategoryKey
  transactionEventType
  categoryAssignmentSource
  rulePriority
  isActive
```

Older draft fields that should not be used:

```text
Silver.mapMerchantRule
  descriptionPattern

Silver.mapCategoryRule
  descriptionPattern
  amountSign
```

```text
Silver.factTransaction
  transactionKey
  sourceFileKey
  financialAccountKey
  transactionDateKey
  postedDateKey
  merchantKey
  merchantRuleKey
  spendingCategoryKey
  categoryRuleKey
  sourceRowNumber
  sourceRowIdentifier
  transactionNaturalKey
  transactionDescriptionRaw
  transactionDescriptionClean
  sourceCategoryName
  transactionType
  transactionEventType
  transactionAmount
```

## Docker Direction

Docker Compose should define separate services:

```text
etl
api
```

The ETL service:

- Reads `data/private/chase/`.
- Builds DuckDB under `warehouse/`.
- Exits.

The API service:

- Opens DuckDB read-only.
- Serves FastAPI.
- Exposes predefined analytics endpoints.
- Exposes guarded read-only SQL against Gold only.

## Frontend Direction

Frontend has not been designed yet.

Approved process:

1. Finish use cases.
2. Finish acceptance criteria.
3. Finish schema design.
4. Design API and AI query interface.
5. Design frontend.
6. Build after approval.

## Current Conversation Position

Latest approved statement:

```text
User said "just approve the rest" to conserve tokens. Remaining schema defaults were
completed in docs/schema-design.md.
```

Current gate:

Next step is API and AI query interface design. Do not implement yet unless the user asks
to move from design to build.

Latest clarification:

```text
Do not require rebuilding the entire DuckDB database from source files every run.
Support idempotent Bronze ingestion by sourceFileHash, Silver refresh from Bronze, and
explicit full-refresh for development/tests.
Do not add explicit DuckDB indexes in v1; rely on constraints and DuckDB defaults unless
query plans later prove indexes are needed.
Schema design now includes a Silver ER diagram and example fact-to-dimension joins in
docs/schema-design.md.
Warehouse SQL is organized in DataWarehouse/ by schema and object type. Deployment uses
DataWarehouse/Deployment/deployWarehouse.py and deploymentOrder.txt.
Docker foundation exists with a one-shot warehouse-deploy service and an api service.
`cd Docker && docker compose up -d` deploys the DuckDB schema and starts the API. API
currently exposes health and warehouse object listing only; full API/query interface is
still a future design gate.
```

Latest implementation update:

```text
Warehouse population is now wired into Docker startup.

Private Chase CSVs were copied into data/private/chase/, which is ignored by Git.
Docker/warehouse-deploy runs deployWarehouse.py with --populate and --data-root
/app/data/private/chase. The service deploys SQL, loads Bronze, derives Silver, then
exits successfully. The API starts after that service completes.

Added DataWarehouse/Deployment/populateWarehouse.py:
- Detects Chase checking and credit CSV shapes.
- Loads Bronze idempotently by sourceFileHash + sourceRowNumber.
- Upserts Silver.dimSourceFile and Silver.dimFinancialAccount.
- Inserts calendar rows for actual transaction/post dates.
- Creates merchant dimension/rule rows from cleaned descriptions.
- Classifies credit card Sale/Return/Payment and checking transaction types into
  transactionEventType and spending categories.
- Inserts Silver.factTransaction idempotently by sourceRowIdentifier.

Added API endpoint:
- GET /api/warehouse/row-counts

Verified row counts after load:
- Bronze.rawChaseCheckingTransaction: 270
- Bronze.rawChaseCreditTransaction: 296
- Silver.factTransaction: 566
- Gold.vw_MonthlySpendingByCategory: 118

Rerunning the warehouse-deploy service inserted 0 new fact rows, confirming idempotency.
```

Latest code organization update:

```text
Python code has been refactored into classes with docstrings on every class and method.

DataWarehouse/Deployment/populateWarehouse.py:
- ChaseValueParser handles text cleanup, hashes, money parsing, date parsing, calendar
  keys, and file-name account last-four extraction.
- ChaseCsvReader discovers private CSV files, reads CSV rows, and detects supported Chase
  source shapes.
- TransactionClassifier maps Chase checking and credit-card rows into category/event
  assignments.
- WarehouseRepository owns all DuckDB writes and idempotent lookup/insert behavior.
- WarehousePopulator orchestrates reader + repository and prints load summaries.

DataWarehouse/Deployment/deployWarehouse.py:
- WarehouseDeployer deploys SQL files and optional reset behavior.
- DeploymentCommand owns CLI parsing and calls deploy/populate workflows.

app/api.py:
- WarehouseCatalog owns read-only DuckDB catalog queries.
- ApiApplicationFactory creates FastAPI and registers routes.

Verification after refactor:
- Local syntax compile passed for all Python files.
- Docker compose rebuild/recreate completed.
- warehouse-deploy completed successfully.
- API health endpoint returned ok.
- row-count endpoint still returns populated warehouse counts.
```

Latest Docker/UI update:

```text
Added a DuckDB UI service to Docker Compose.

Files:
- app/duckdb_ui.py
- Docker/docker-compose.yml
- README.md

DuckDB UI details:
- Service name: duckdb-ui
- Browser URL: http://localhost:4213
- DuckDB's embedded UI server runs internally on localhost:4214.
- The DuckDB UI service uses Docker/requirements-ui.txt with duckdb==1.4.1 because the
  remote UI app's desired extension map currently aligns with DuckDB v1.4.1.
- The ETL/API image continues to use Docker/requirements.txt with duckdb==1.5.2.
- A small Python TCP proxy exposes the UI on 0.0.0.0:4213 so Docker port publishing
  works without requiring Docker host networking.
- The UI opens /tmp/duckdb_ui_catalog.duckdb as its writable UI catalog.
- The finance warehouse is attached read-only as alias finance:
  ATTACH IF NOT EXISTS '/app/warehouse/finance.duckdb' AS finance (READ_ONLY)

Verification:
- docker compose up -d --build --force-recreate succeeded.
- docker-duckdb-ui-1 is Up and maps 0.0.0.0:4213->4213/tcp.
- DuckDB UI logs show internal server on localhost:4214 and proxy on 0.0.0.0:4213.
- HTTP GET to http://duckdb-ui:4213 from the api container returned 200.
- Querying finance.Silver.factTransaction from the UI catalog returned 566 rows.
- API health endpoint still returned ok.
```

Latest DuckDB SQL ETL simplification update:

```text
The custom Python ETL package was removed. DataWarehouse/ETL is now SQL-first.

Deleted:
- DataWarehouse/ETL/Common/*.py
- DataWarehouse/ETL/Bronze/*.py
- DataWarehouse/ETL/Silver/*.py
- DataWarehouse/ETL/sourceFileEtl.py
- DataWarehouse/ETL/warehousePopulator.py
- DataWarehouse/ETL/**/__init__.py
- app/__init__.py

Kept Python:
- DataWarehouse/Deployment/deployWarehouse.py
- DataWarehouse/Deployment/populateWarehouse.py
- app/api.py
- app/duckdb_ui.py

New ETL layout:
- DataWarehouse/ETL/etlOrder.txt
- DataWarehouse/ETL/Bronze/LoadRawChaseCheckingTransaction.sql
- DataWarehouse/ETL/Bronze/LoadRawChaseCreditTransaction.sql
- DataWarehouse/ETL/Silver/ProcessDimSourceFile.sql
- DataWarehouse/ETL/Silver/ProcessDimFinancialAccount.sql
- DataWarehouse/ETL/Silver/ProcessDimCalendarDate.sql
- DataWarehouse/ETL/Silver/ProcessDimMerchant.sql
- DataWarehouse/ETL/Silver/ProcessMapMerchantRule.sql
- DataWarehouse/ETL/Silver/ProcessMapCategoryRule.sql
- DataWarehouse/ETL/Silver/ProcessFactTransaction.sql

Naming rule implemented:
- Silver dimension transformations use ProcessDim<TableName>.sql.
- Silver fact transformations use ProcessFact<TableName>.sql.
- Mapping transformations use ProcessMap<TableName>.sql.

populateWarehouse.py now:
- Discovers private Chase CSV files case-insensitively (.csv or .CSV).
- Computes sourceFileHash and file metadata.
- Creates temporary DuckDB stage queue tables.
- Loads CSV rows into queue tables with DuckDB read_csv.
- Processes transaction rows in configurable chunks.
- Executes SQL scripts from ETL/etlOrder.txt.

Verification:
- Python syntax compile passed.
- docker compose up -d --build --force-recreate succeeded.
- warehouse-deploy completed successfully.
- Rerunning warehouse-deploy preserved row counts/idempotency.
- API health returned ok.
- Silver.factTransaction still has 566 rows.
- DuckDB UI returned HTTP 200.
```

Latest chunked MERGE update:

```text
User asked for SQL transformations to look more like chunked upsert processing instead of
plain insert transformations.

Implemented:
- populateWarehouse.py now processes transactions from staging queue tables into temporary
  chunk tables.
- deployWarehouse.py and populateWarehouse.py expose --stage-chunk-size.
- Bronze transaction scripts use MERGE on sourceFileHash + sourceRowNumber.
- Silver scripts now follow: create temp process table, dedupe, MERGE.
- Cross-join key math was removed from the ETL SQL.
- Generated key defaults live in table DDL and are backed by DuckDB sequences declared in
  the owning table files.
- Silver.factTransaction uses MERGE on sourceRowIdentifier and updates/inserts the
  descriptive and foreign-key columns for the transaction grain.

DuckDB note:
- Updating dimension rows that are already referenced by facts can hit DuckDB foreign-key
  limitations.
- Silver `MERGE` statements include `WHEN MATCHED AND ...` predicates so idempotent reruns
  do not perform unnecessary no-op updates.
- Dimension correction workflows should be designed deliberately later instead of hidden in
  the first-pass ingestion scripts.

Verification:
- PYTHONPYCACHEPREFIX=/private/tmp/codex-pycache python3 -m py_compile passed for the
  deployment and app Python files.
- docker compose up -d --build --force-recreate succeeded.
- warehouse-deploy processed 566 source rows.
- Silver.factTransaction row count is 566.
- Duplicate sourceRowIdentifier count is 0.
- transactionKey range is 100 to 56600.
- API health returned ok at http://127.0.0.1:4000/health.
- DuckDB UI returned HTTP 200 at http://localhost:4213.
```

Latest cleanup update:

```text
Unused cleanup:
- Deleted stale standalone sequence SQL files from Bronze/Sequences and Silver/Sequences.
- Deleted Deployment/fullRefresh.sql because deployWarehouse.py --reset owns full refresh.
- Deleted docs/etl-tooling-research.md because it was a temporary research note.
- Removed empty DataWarehouse/ETL/Common and scripts directories.
- Removed local .DS_Store.

Kept intentionally:
- DBA scripts, because the user asked for a DBA utilities area.
- .gitkeep files, because they preserve approved DataWarehouse folder structure.
```

Latest frontend architecture update:

```text
Decision:
- Use React + Vite for the frontend.
- Keep FastAPI as the backend API.
- Do not add Django or Flask.

Implemented:
- Added Frontend/ as the owner folder for all browser UI files.
- Added a small one-page dashboard scaffold:
  - top action bar
  - account/date/category/search filters
  - metric cards
  - cashflow trend panel
  - ask-your-data panel
  - category and merchant panels
  - transactions table shell
- Added Frontend/src/api/warehouseApi.js for calls to FastAPI.
- Added Frontend/src/controllers/dashboardController.js.
- Added Frontend/src/mockData/dashboardMockData.js.
- Added CORS middleware to app/api.py for local Vite origins.
- Added a Docker `web` service using node:22-alpine on localhost:5173.
- Added `/api/dashboard` to FastAPI so the UI can read safe Gold-view data.
- Updated README.md with the architecture diagram showing React, FastAPI, DuckDB UI,
  warehouse deployment, medallion layers, and future AI/MCP.

Deferred:
- Real chart library.
- AI text-to-SQL execution.
```

Latest dashboard metric correction:

```text
User noticed dashboard numbers looked wrong.

Root cause:
- Gold.vw_MonthlyCashflow previously treated every positive transaction amount as inflow.
- That counted credit card payment postings, refunds, and transfers as income.

Correction:
- incomeAmount now only uses transactionEventType = 'income'.
- grossPurchaseAmount only uses transactionEventType = 'purchase'.
- refundAmount only uses transactionEventType = 'refund'.
- feeAmount only uses transactionEventType = 'fee'.
- internalPaymentAmount, debtPaymentAmount, and netTransferAmount are exposed separately.
- inflowAmount is now an alias for incomeAmount.
- outflowAmount is purchase minus refund plus fee.
- netCashflowAmount is incomeAmount - outflowAmount.

Verified current dashboard API summary:
- Spending: $14,544.63
- Income: $10,492.97
- Net Cashflow: -$4,066.66
- Uncategorized: 211
```

Latest dashboard filter update:

```text
User noticed the dashboard buttons did not filter anything.

Implemented:
- Added Gold.vw_TransactionLedger as a safe transaction-level view for the React UI.
- Added transactionRows to /api/dashboard.
- React dashboard now uses transactionRows for client-side filtering.
- Account, date range, category, and search filters now update:
  - metric cards
  - monthly cashflow list
  - spending by category list
  - top merchants list
  - transaction table
- Transactions Filter button toggles the filter bar.
- Columns button toggles table column checkboxes.
- Export button downloads the currently filtered and visible transaction table as CSV.

Privacy:
- Gold.vw_TransactionLedger does not expose raw Chase descriptions, memo, balance,
  account last four, check/slip number, or source file names.

Verification:
- Frontend production build passed.
- Warehouse deployment added Gold.vw_TransactionLedger.
- /api/dashboard returns 566 transactionRows.
- Gold.vw_TransactionLedger count is 566.
```

Latest data integrity verification:

```text
Ran live integrity checks against warehouse/finance.duckdb through the app container.

Passed checks:
- Bronze checking + credit row count reconciles to Silver.factTransaction.
- Silver.factTransaction reconciles to Gold.vw_TransactionLedger.
- Bronze source grains have no duplicates.
- Silver fact source grains have no duplicates.
- Silver fact required columns have no nulls.
- Silver fact core dimension keys are resolved.
- Silver fact foreign-key joins are complete.
- Transaction event sign rules hold.
- Transaction event types are valid.
- Debt/payment events are excluded from Gold spending.
- Gold spending reconciles to Silver purchase minus refund.
- Gold cashflow reconciles to Silver income, purchase, refund, and fee events.
- Gold views do not expose blocked private/raw columns.
- Dashboard API returns live warehouse data.
- Dashboard API returns 566 transaction rows.
- Dashboard API summary matches corrected totals.

Added repeatable DBA script:
- DataWarehouse/DBA/validateDataIntegrity.sql

Running the DBA script returned 0 failure rows.
```

Latest rule-driven classification and frontend cleanup update:

```text
User flagged that merchant-specific category logic should be rules, not hardcoded ETL.

Implemented:
- Moved Robinhood, Capital One, Amazon Synchrony, outgoing Zelle, and Chase card-payment
  decisions into Silver/Seeds/defaultCategoryRules.sql.
- ProcessFactTransaction.sql now applies the highest-priority active matching
  Silver.mapCategoryRule row.
- ProcessMapCategoryRule.sql now creates generic source/type rules only.
- Old auto-generated description rules are deactivated by the default category rule seed.

Current trusted classification examples:
- Robinhood -> Investments / transfer
- Capital One mobile payment -> DebtPayment / debtPayment
- Amazon Corp SYF payment -> DebtPayment / debtPayment
- Zelle payment to... -> Personal / purchase

User then asked to simplify App.jsx.

Implemented:
- App.jsx reduced from 1157 lines to about 254 lines.
- Frontend/src/components owns JSX presentation components.
- Frontend/src/domain owns object-oriented service/helper classes:
  - TransactionAnalytics
  - TransactionFilter
  - CategoryRuleSuggestionService
  - CsvExporter
  - DateRange
- Frontend production build passed after the split.

User then asked for source headers and documentation updates.

Implemented:
- Added purpose/dependency headers to Python, SQL, JS/JSX, CSS, HTML, Docker, Compose,
  requirements, and deployment manifest files that support comments.
- JSON files were not given comments because JSON does not support comments.
- Updated README.md, DataWarehouse/README.md, Frontend/README.md, docs/schema-design.md,
  and this context file with the current architecture.
```
