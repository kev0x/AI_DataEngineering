/*
Purpose:
    Returns monthly inflow, outflow, and net cashflow for dashboard trend charts.
Dependencies:
    Gold.vw_MonthlyCashflow.
*/
select
    yearMonth,
    min(monthStartDate) as monthStartDate,
    sum(inflowAmount) as inflowAmount,
    sum(outflowAmount) as outflowAmount,
    sum(netCashflowAmount) as netCashflowAmount
from Gold.vw_MonthlyCashflow
group by yearMonth
order by monthStartDate
