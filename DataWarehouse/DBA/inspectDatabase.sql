-- Purpose: Shows attached DuckDB database/catalog information for troubleshooting.
-- Pipeline role: Helps verify which database file a container or local session is connected to before running manual SQL.
-- Dependencies: DuckDB system function duckdb_databases().

select
    database_name,
    path,
    type
from duckdb_databases();
