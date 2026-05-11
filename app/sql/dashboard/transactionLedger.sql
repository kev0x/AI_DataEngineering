/*
Purpose:
    Returns safe transaction-level rows for browser filtering and drill-down.
Dependencies:
    Gold.vw_TransactionLedger.
*/
select
    transactionKey,
    transactionDate,
    postedDate,
    yearMonth,
    monthStartDate,
    accountType,
    merchantDisplayName,
    parentSpendingCategoryName,
    spendingCategoryName,
    transactionType,
    transactionEventType,
    transactionAmount
from Gold.vw_TransactionLedger
order by transactionDate desc, transactionKey desc
