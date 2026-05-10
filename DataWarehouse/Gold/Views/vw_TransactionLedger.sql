-- Purpose: Creates the safe transaction-level ledger used by the React dashboard.
-- Pipeline role: Exposes enough row-level detail for filtering, charts, and category-rule suggestions without leaking raw Chase descriptions or account identifiers.
-- Dependencies: Silver.factTransaction and joined Silver dimensions for dates, accounts, merchants, and spending categories.

create or replace view Gold.vw_TransactionLedger as
select
    t.transactionKey,
    d.calendarDate as transactionDate,
    p.calendarDate as postedDate,
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    m.merchantDisplayName,
    c.parentSpendingCategoryName,
    c.spendingCategoryName,
    t.transactionType,
    t.transactionEventType,
    t.transactionAmount
from Silver.factTransaction as t
join Silver.dimCalendarDate as d
    on t.transactionDateKey = d.calendarDateKey
join Silver.dimCalendarDate as p
    on t.postedDateKey = p.calendarDateKey
join Silver.dimFinancialAccount as a
    on t.financialAccountKey = a.financialAccountKey
join Silver.dimMerchant as m
    on t.merchantKey = m.merchantKey
join Silver.dimSpendingCategory as c
    on t.spendingCategoryKey = c.spendingCategoryKey;
