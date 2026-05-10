-- Purpose: Creates a dashboard-ready monthly cashflow view.
-- Pipeline role: Summarizes income, spending, refunds, fees, payments, debt payments, and transfers from the transaction fact without exposing raw source fields.
-- Dependencies: Silver.factTransaction and Silver.dimCalendarDate.

create or replace view Gold.vw_MonthlyCashflow as
with monthlyCashflow as (
    select
        d.yearMonth,
        d.monthStartDate,
        a.accountType,
        count(*) as transactionCount,
        count(*) filter (where t.transactionEventType = 'income') as incomeTransactionCount,
        count(*) filter (where t.transactionEventType = 'purchase') as purchaseTransactionCount,
        count(*) filter (where t.transactionEventType = 'refund') as refundTransactionCount,
        count(*) filter (where t.transactionEventType = 'fee') as feeTransactionCount,
        count(*) filter (where t.transactionEventType = 'payment') as internalPaymentTransactionCount,
        count(*) filter (where t.transactionEventType = 'debtPayment') as debtPaymentTransactionCount,
        count(*) filter (where t.transactionEventType = 'transfer') as transferTransactionCount,
        coalesce(sum(t.transactionAmount) filter (where t.transactionEventType = 'income'), 0) as incomeAmount,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'purchase'), 0) as grossPurchaseAmount,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'refund'), 0) as refundAmount,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'fee'), 0) as feeAmount,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'payment'), 0) as internalPaymentAmount,
        coalesce(sum(abs(t.transactionAmount)) filter (where t.transactionEventType = 'debtPayment'), 0) as debtPaymentAmount,
        coalesce(sum(t.transactionAmount) filter (where t.transactionEventType = 'transfer'), 0) as netTransferAmount
    from Silver.factTransaction as t
    join Silver.dimCalendarDate as d
        on t.transactionDateKey = d.calendarDateKey
    join Silver.dimFinancialAccount as a
        on t.financialAccountKey = a.financialAccountKey
    group by
        d.yearMonth,
        d.monthStartDate,
        a.accountType
)
select
    yearMonth,
    monthStartDate,
    accountType,
    transactionCount,
    incomeTransactionCount,
    purchaseTransactionCount,
    refundTransactionCount,
    feeTransactionCount,
    internalPaymentTransactionCount,
    debtPaymentTransactionCount,
    transferTransactionCount,
    incomeAmount,
    grossPurchaseAmount,
    refundAmount,
    feeAmount,
    internalPaymentAmount,
    debtPaymentAmount,
    netTransferAmount,
    incomeAmount as inflowAmount,
    grossPurchaseAmount - refundAmount + feeAmount as outflowAmount,
    incomeAmount - (grossPurchaseAmount - refundAmount + feeAmount) as netCashflowAmount
from monthlyCashflow;
