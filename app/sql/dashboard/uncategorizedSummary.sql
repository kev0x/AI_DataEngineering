/*
Purpose:
    Returns summarized uncategorized activity so the UI can suggest category rules.
Dependencies:
    Gold.vw_UncategorizedTransactionSummary.
*/
select
    yearMonth,
    accountType,
    transactionEventType,
    sum(transactionCount) as transactionCount,
    sum(netTransactionAmount) as netTransactionAmount
from Gold.vw_UncategorizedTransactionSummary
group by yearMonth, accountType, transactionEventType
order by yearMonth desc, transactionCount desc
limit 8
