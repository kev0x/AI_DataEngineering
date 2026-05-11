/*
Purpose:
    Returns top merchants by spending for dashboard merchant charts.
Dependencies:
    Gold.vw_TopMerchantsBySpending.
*/
select
    merchantDisplayName,
    sum(purchaseTransactionCount) as purchaseTransactionCount,
    sum(totalSpendingAmount) as totalSpendingAmount,
    avg(averagePurchaseAmount) as averagePurchaseAmount
from Gold.vw_TopMerchantsBySpending
group by merchantDisplayName
order by totalSpendingAmount desc
limit 8
