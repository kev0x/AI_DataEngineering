-- Purpose: Lists warehouse tables and views by schema.
-- Pipeline role: Gives a quick inventory of Bronze, Silver, and Gold objects for debugging or learning the model.
-- Dependencies: DuckDB information_schema.tables.

select
    table_schema as schemaName,
    table_name as objectName,
    table_type as objectType
from information_schema.tables
where table_schema in ('Bronze', 'Silver', 'Gold')
order by
    table_schema,
    table_type,
    table_name;
