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

