-- Purpose: Creates ranked merchant spending metrics for the dashboard.
-- Pipeline role: Aggregates purchase/refund activity by merchant while keeping private raw descriptions out of Gold.
-- Dependencies: Silver.factTransaction and Silver.dimMerchant.

create or replace view Gold.vw_TopMerchantsBySpending as
select
    m.merchantDisplayName,
    a.accountType,
    c.parentSpendingCategoryName,
    c.spendingCategoryName,
    count(*) filter (where t.transactionEventType = 'purchase') as purchaseTransactionCount,
    coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0) as totalSpendingAmount,
    coalesce(avg(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0) as averagePurchaseAmount,
    min(d.calendarDate) as firstTransactionDate,
    max(d.calendarDate) as lastTransactionDate
from Silver.factTransaction as t
join Silver.dimMerchant as m
    on t.merchantKey = m.merchantKey
join Silver.dimFinancialAccount as a
    on t.financialAccountKey = a.financialAccountKey
join Silver.dimSpendingCategory as c
    on t.spendingCategoryKey = c.spendingCategoryKey
join Silver.dimCalendarDate as d
    on t.transactionDateKey = d.calendarDateKey
group by
    m.merchantDisplayName,
    a.accountType,
    c.parentSpendingCategoryName,
    c.spendingCategoryName;
