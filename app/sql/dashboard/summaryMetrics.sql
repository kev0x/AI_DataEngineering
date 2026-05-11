/*
Purpose:
    Returns the unfiltered dashboard metric-card totals from Gold views.
Dependencies:
    Gold.vw_MonthlySpendingByCategory, Gold.vw_MonthlyCashflow,
    and Gold.vw_UncategorizedTransactionSummary.
*/
select
    (
        select coalesce(sum(netSpendingAmount), 0)
        from Gold.vw_MonthlySpendingByCategory
    ) as totalSpendingAmount,
    (
        select coalesce(sum(incomeAmount), 0)
        from Gold.vw_MonthlyCashflow
    ) as totalIncomeAmount,
    (
        select coalesce(sum(netCashflowAmount), 0)
        from Gold.vw_MonthlyCashflow
    ) as netCashflowAmount,
    (
        select coalesce(sum(transactionCount), 0)
        from Gold.vw_UncategorizedTransactionSummary
    ) as uncategorizedTransactionCount
