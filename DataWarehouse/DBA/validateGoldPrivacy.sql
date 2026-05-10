-- Purpose: Checks Gold views for blocked private/raw column names.
-- Pipeline role: Protects the API and future AI query surface by ensuring Gold stays safe for browser and text-to-SQL access.
-- Dependencies: DuckDB information_schema.columns and the Gold schema.

with gold_columns as (
    select
        table_name as viewName,
        column_name as columnName
    from information_schema.columns
    where table_schema = 'Gold'
),
blocked_patterns as (
    select 'description' as pattern
    union all select 'sourceFile'
    union all select 'accountLastFour'
    union all select 'accountDisplayName'
    union all select 'memo'
    union all select 'balance'
    union all select 'checkOrSlip'
)
select
    g.viewName,
    g.columnName,
    b.pattern as blockedPattern
from gold_columns as g
join blocked_patterns as b
    on lower(g.columnName) like '%' || lower(b.pattern) || '%'
order by
    g.viewName,
    g.columnName;
