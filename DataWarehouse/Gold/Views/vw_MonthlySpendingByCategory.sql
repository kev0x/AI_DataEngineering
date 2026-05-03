create or replace view Gold.vw_MonthlySpendingByCategory as
select
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    c.parentSpendingCategoryName,
    c.spendingCategoryName,
    count(*) filter (where t.transactionEventType = 'purchase') as purchaseTransactionCount,
    count(*) filter (where t.transactionEventType = 'refund') as refundTransactionCount,
    coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0) as grossSpendingAmount,
    coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'refund'), 0) as refundAmount,
    coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0)
        - coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'refund'), 0)
        as netSpendingAmount
from Silver.factTransaction as t
join Silver.dimCalendarDate as d
    on t.transactionDateKey = d.calendarDateKey
join Silver.dimFinancialAccount as a
    on t.financialAccountKey = a.financialAccountKey
join Silver.dimSpendingCategory as c
    on t.spendingCategoryKey = c.spendingCategoryKey
group by
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    c.parentSpendingCategoryName,
    c.spendingCategoryName;

