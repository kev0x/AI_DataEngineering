/*
Purpose:
    Returns top spending categories for dashboard category charts.
Dependencies:
    Gold.vw_MonthlySpendingByCategory.
*/
select
    parentSpendingCategoryName,
    spendingCategoryName,
    sum(purchaseTransactionCount) as purchaseTransactionCount,
    sum(netSpendingAmount) as netSpendingAmount
from Gold.vw_MonthlySpendingByCategory
group by parentSpendingCategoryName, spendingCategoryName
order by netSpendingAmount desc
limit 8
