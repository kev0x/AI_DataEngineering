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
