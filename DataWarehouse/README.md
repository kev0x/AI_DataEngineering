# DataWarehouse

SQL Server-inspired, DuckDB-friendly warehouse object layout.

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

DuckDB does not use SQLCMD `:r` includes or stored procedures for deployment through the
Python API. `Deployment/deployWarehouse.py` reads `Deployment/deploymentOrder.txt` and
executes the listed SQL files in order.

