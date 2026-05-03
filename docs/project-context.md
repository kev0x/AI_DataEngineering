# Project Context And Design Progress

This file captures the project context and decisions so the work can continue cleanly if the
conversation context is lost.

## Project Goal

Build a small, Dockerized, local-first data engineering project for personal Chase financial
data. The purpose is to learn architecture, schema design, ETL, DuckDB, FastAPI, and later
AI text-to-SQL over safe analytical views.

The project should stay simple:

- No Databricks.
- No Spark.
- No cloud warehouse in v1.
- No hosted AI over private data in v1.
- Use open-source/local tools.

## Current Repo State

The earlier mock implementation was removed after the user asked to return to design-first
mode. The repo now intentionally contains planning files only.

Current intended tracked files:

```text
README.md
.gitignore
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
implementation dependencies are not part of the approved design yet.

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
```
