-- Purpose: Creates the medallion schemas used by the local finance warehouse.
-- Pipeline role: Establishes Bronze for source-shaped data, Silver for modeled star-schema data, and Gold for safe API/AI views.
-- Dependencies: DuckDB connection; this must run before table, seed, ETL, and view scripts.

create schema if not exists Bronze;
create schema if not exists Silver;
create schema if not exists Gold;
