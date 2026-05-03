create or replace view Gold.vw_SpendingCategoryTrend as
with monthly as (
    select
        d.yearMonth,
        d.monthStartDate,
        c.parentSpendingCategoryName,
        c.spendingCategoryName,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0)
            - coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'refund'), 0)
            as netSpendingAmount
    from Silver.factTransaction as t
    join Silver.dimCalendarDate as d
        on t.transactionDateKey = d.calendarDateKey
    join Silver.dimSpendingCategory as c
        on t.spendingCategoryKey = c.spendingCategoryKey
    group by
        d.yearMonth,
        d.monthStartDate,
        c.parentSpendingCategoryName,
        c.spendingCategoryName
)
select
    yearMonth,
    monthStartDate,
    parentSpendingCategoryName,
    spendingCategoryName,
    netSpendingAmount,
    lag(netSpendingAmount) over (
        partition by parentSpendingCategoryName, spendingCategoryName
        order by monthStartDate
    ) as previousMonthNetSpendingAmount,
    netSpendingAmount - coalesce(
        lag(netSpendingAmount) over (
            partition by parentSpendingCategoryName, spendingCategoryName
            order by monthStartDate
        ),
        0
    ) as monthOverMonthChangeAmount
from monthly;

