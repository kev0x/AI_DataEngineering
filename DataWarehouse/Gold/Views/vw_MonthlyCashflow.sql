create or replace view Gold.vw_MonthlyCashflow as
select
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    t.transactionEventType,
    count(*) as transactionCount,
    coalesce(sum(t.transactionAmount) filter (where t.transactionAmount > 0), 0) as inflowAmount,
    coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionAmount < 0), 0) as outflowAmount,
    coalesce(sum(t.transactionAmount), 0) as netCashflowAmount
from Silver.factTransaction as t
join Silver.dimCalendarDate as d
    on t.transactionDateKey = d.calendarDateKey
join Silver.dimFinancialAccount as a
    on t.financialAccountKey = a.financialAccountKey
group by
    d.yearMonth,
    d.monthStartDate,
    a.accountType,
    t.transactionEventType;

