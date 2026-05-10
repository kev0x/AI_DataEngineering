# DataWarehouse

SQL Server-inspired, DuckDB-friendly warehouse object layout.

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
  ETL/
    Bronze/
    Silver/
  Deployment/
  DBA/
```

DuckDB does not use SQLCMD `:r` includes or stored procedures for deployment through the
Python API. `Deployment/deployWarehouse.py` reads `Deployment/deploymentOrder.txt` and
executes the listed SQL files in order.

Every executable SQL and Python file in this folder starts with a short purpose/dependency
header so future changes are easier to orient around.

Populate the warehouse from private Chase CSV files:

```bash
python DataWarehouse/Deployment/deployWarehouse.py --populate
```

Control transaction chunk size during population:

```bash
python DataWarehouse/Deployment/deployWarehouse.py --populate --stage-chunk-size 500
```

The default private input folder is:

```text
data/private/chase/
```

The loader is idempotent:

- Source CSV rows are staged into temporary queue tables.
- Transaction ETL runs in chunks against temporary chunk tables.
- Bronze transaction loads use `MERGE` by `sourceFileHash` and `sourceRowNumber`.
- Silver transformations create small temporary process tables, dedupe them, then `MERGE`.
- Generated keys use table defaults backed by DuckDB sequences declared in the table DDL.
- `Silver.factTransaction` uses `MERGE` by `sourceRowIdentifier`.
- Rerunning the population step does not duplicate transactions.

## Classification Rules

Business classification is data-driven. Merchant-specific decisions should live in
`Silver.mapCategoryRule`, not in `ProcessFactTransaction.sql`.

Current rule sources:

```text
system  Seeded rules in Silver/Seeds/defaultCategoryRules.sql
manual  User-approved rules created through POST /api/category-rules
ai      Reserved for future AI-suggested rules
```

`Silver.factTransaction` stores both the resolved `spendingCategoryKey` and the
`categoryRuleKey` that assigned it. That gives us traceability when a category needs to be
corrected later.

The fact ETL applies the highest-priority active matching rule by:

```text
sourceAccountType
sourceCategoryName
transactionType
descriptionMatchType
descriptionMatchText
rulePriority
```

Parsing Chase source columns is still ETL logic. Classifying business meaning is rule data.

ETL SQL scripts live under:

```text
DataWarehouse/ETL/
  etlOrder.txt
  Bronze/
    LoadRawChaseCheckingTransaction.sql
    LoadRawChaseCreditTransaction.sql
  Silver/
    ProcessDimSourceFile.sql
    ProcessDimFinancialAccount.sql
    ProcessDimCalendarDate.sql
    ProcessDimMerchant.sql
    ProcessMapMerchantRule.sql
    ProcessMapCategoryRule.sql
    ProcessFactTransaction.sql
```

`Deployment/populateWarehouse.py` is intentionally small. It discovers private CSV files,
creates temporary DuckDB stage queues, processes staged transactions in chunks, and executes
the SQL scripts listed in `ETL/etlOrder.txt`.

DBA utilities live under:

```text
DataWarehouse/DBA/
  dataTrustReport.sql
  inspectDatabase.sql
  listConstraints.sql
  listTables.sql
  rowCounts.sql
  validateDataIntegrity.sql
  validateGoldPrivacy.sql
```

Run validation through the API container:

```bash
cd Docker
docker compose exec -T api python - <<'PY'
from pathlib import Path
import duckdb

con = duckdb.connect('/app/warehouse/finance.duckdb', read_only=True)
result = con.execute(Path('/app/DataWarehouse/DBA/validateDataIntegrity.sql').read_text())
for row in result.fetchall():
    print(row)
con.close()
PY
```
