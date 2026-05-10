-- Purpose: Lists table constraints defined in the warehouse.
-- Pipeline role: Helps learners inspect primary keys, foreign keys, unique constraints, and default rules after deployment.
-- Dependencies: DuckDB information_schema.table_constraints and key_column_usage views.

select
    constraint_schema as schemaName,
    table_name as tableName,
    constraint_name as constraintName,
    constraint_type as constraintType
from information_schema.table_constraints
where constraint_schema in ('Bronze', 'Silver', 'Gold')
order by
    constraint_schema,
    table_name,
    constraint_type,
    constraint_name;
