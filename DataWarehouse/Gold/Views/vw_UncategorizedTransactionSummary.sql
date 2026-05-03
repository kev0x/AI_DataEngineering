create or replace view Gold.vw_UncategorizedTransactionSummary as
select
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    t.transactionType,
    t.transactionEventType,
    count(*) as transactionCount,
    coalesce(sum(t.transactionAmount), 0) as netTransactionAmount
from Silver.factTransaction as t
join Silver.dimCalendarDate as d
    on t.transactionDateKey = d.calendarDateKey
join Silver.dimFinancialAccount as a
    on t.financialAccountKey = a.financialAccountKey
join Silver.dimSpendingCategory as c
    on t.spendingCategoryKey = c.spendingCategoryKey
where c.spendingCategoryName in ('Uncategorized', 'Unknown')
group by
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    t.transactionType,
    t.transactionEventType;

