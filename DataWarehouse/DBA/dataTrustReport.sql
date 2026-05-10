-- Purpose: Reports row reconciliation, hard integrity checks, and business-trust risk metrics.
-- Pipeline role: Explains not only whether the warehouse is valid, but also where category quality still needs review.
-- Dependencies: Gold.vw_TransactionLedger, Bronze raw tables, Silver.factTransaction, and Silver dimensions.

with transactionLedger as (
    select
        ledger.*,
        fact.transactionDescriptionClean
    from Gold.vw_TransactionLedger as ledger
    join Silver.factTransaction as fact
        on ledger.transactionKey = fact.transactionKey
),
rowTotals as (
    select
        (select count(*) from Bronze.rawChaseCheckingTransaction) as bronzeCheckingRowCount,
        (select count(*) from Bronze.rawChaseCreditTransaction) as bronzeCreditRowCount,
        (select count(*) from Silver.factTransaction) as silverFactRowCount,
        (select count(*) from Gold.vw_TransactionLedger) as goldLedgerRowCount
),
amountTotals as (
    select
        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'purchase'), 0)
            - coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'refund'), 0)
            as totalSpendingAmount,
        coalesce(sum(transactionAmount) filter (where transactionEventType = 'income'), 0)
            as totalIncomeAmount,
        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'fee'), 0)
            as totalFeeAmount,
        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'payment'), 0)
            as excludedPaymentAmount,
        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'debtPayment'), 0)
            as excludedDebtPaymentAmount,
        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'transfer'), 0)
            as excludedTransferActivityAmount,
        coalesce(sum(abs(transactionAmount)) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
        ), 0) as uncategorizedPurchaseAmount,
        count(*) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
        ) as uncategorizedPurchaseCount
    from transactionLedger
),
reviewPatterns as (
    select
        count(*) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
              and transactionDescriptionClean like '%ROBINHOOD%'
        ) as possibleInvestmentTransferCount,
        coalesce(sum(abs(transactionAmount)) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
              and transactionDescriptionClean like '%ROBINHOOD%'
        ), 0) as possibleInvestmentTransferAmount,
        count(*) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
              and (
                    transactionDescriptionClean like '%CAPITAL ONE%'
                 or transactionDescriptionClean like '%CREDIT CARD%'
                 or transactionDescriptionClean like '%PAYMNT%'
                 or transactionDescriptionClean like '% PMT %'
              )
        ) as possibleDebtPaymentCount,
        coalesce(sum(abs(transactionAmount)) filter (
            where transactionEventType = 'purchase'
              and spendingCategoryName in ('Uncategorized', 'Unknown')
              and (
                    transactionDescriptionClean like '%CAPITAL ONE%'
                 or transactionDescriptionClean like '%CREDIT CARD%'
                 or transactionDescriptionClean like '%PAYMNT%'
                 or transactionDescriptionClean like '% PMT %'
              )
        ), 0) as possibleDebtPaymentAmount
    from transactionLedger
),
hardCheckTotals as (
    select
        (
            select count(*)
            from (
                select sourceRowIdentifier
                from Silver.factTransaction
                group by sourceRowIdentifier
                having count(*) > 1
            )
        ) as duplicateFactGrainCount,
        (
            select count(*)
            from Silver.factTransaction
            where sourceFileKey = -1
               or financialAccountKey = -1
               or transactionDateKey = 19000101
               or postedDateKey = 19000101
               or merchantKey = -1
               or spendingCategoryKey = -1
        ) as unknownCoreKeyCount,
        (
            select count(*)
            from Silver.factTransaction
            where (transactionEventType in ('purchase', 'fee', 'debtPayment') and transactionAmount >= 0)
               or (transactionEventType in ('income', 'payment', 'refund') and transactionAmount <= 0)
        ) as eventSignIssueCount
),
reportRows as (
    select
        10 as sectionOrder,
        10 as metricOrder,
        'Row reconciliation' as sectionName,
        'Bronze checking rows' as metricName,
        bronzeCheckingRowCount::varchar as metricValue,
        'Rows loaded from checking CSVs.' as detail
    from rowTotals

    union all

    select 10, 20, 'Row reconciliation', 'Bronze credit rows', bronzeCreditRowCount::varchar,
        'Rows loaded from credit CSVs.'
    from rowTotals

    union all

    select 10, 30, 'Row reconciliation', 'Silver fact rows', silverFactRowCount::varchar,
        'Rows loaded into the transaction fact.'
    from rowTotals

    union all

    select 10, 40, 'Row reconciliation', 'Gold ledger rows', goldLedgerRowCount::varchar,
        'Rows exposed to the dashboard transaction ledger.'
    from rowTotals

    union all

    select 10, 50, 'Row reconciliation', 'Bronze to Silver row difference',
        ((bronzeCheckingRowCount + bronzeCreditRowCount) - silverFactRowCount)::varchar,
        'Should be 0 unless source rows are intentionally rejected.'
    from rowTotals

    union all

    select 20, 10, 'Hard integrity checks', 'Duplicate fact grain rows', duplicateFactGrainCount::varchar,
        'Duplicate sourceRowIdentifier rows in Silver.factTransaction.'
    from hardCheckTotals

    union all

    select 20, 20, 'Hard integrity checks', 'Unknown core dimension keys', unknownCoreKeyCount::varchar,
        'Rows where required dimension keys still use the default Unknown member.'
    from hardCheckTotals

    union all

    select 20, 30, 'Hard integrity checks', 'Event sign issues', eventSignIssueCount::varchar,
        'Purchases/fees/debt payments should be negative; income/payments/refunds should be positive.'
    from hardCheckTotals

    union all

    select 30, 10, 'Dashboard amount definitions', 'Total spending',
        '$' || round(totalSpendingAmount, 2)::varchar,
        'Purchases minus refunds. Payments, debt payments, and transfers are excluded.'
    from amountTotals

    union all

    select 30, 20, 'Dashboard amount definitions', 'Total income',
        '$' || round(totalIncomeAmount, 2)::varchar,
        'Income events only.'
    from amountTotals

    union all

    select 30, 30, 'Dashboard amount definitions', 'Total fees',
        '$' || round(totalFeeAmount, 2)::varchar,
        'Fees are included in cashflow outflow.'
    from amountTotals

    union all

    select 30, 40, 'Dashboard amount definitions', 'Excluded payment activity',
        '$' || round(excludedPaymentAmount + excludedDebtPaymentAmount + excludedTransferActivityAmount, 2)::varchar,
        'Internal payments, debt payments, and transfers excluded from spending.'
    from amountTotals

    union all

    select 40, 10, 'Review risk', 'Uncategorized purchase count',
        uncategorizedPurchaseCount::varchar,
        'These are counted as spending until rules classify them.'
    from amountTotals

    union all

    select 40, 20, 'Review risk', 'Uncategorized purchase amount',
        '$' || round(uncategorizedPurchaseAmount, 2)::varchar,
        'This is the biggest business-trust risk in the dashboard.'
    from amountTotals

    union all

    select 40, 30, 'Review risk', 'Uncategorized share of spending',
        round(100 * uncategorizedPurchaseAmount / nullif(totalSpendingAmount, 0), 1)::varchar || '%',
        'High values mean the dashboard is mathematically valid but not business-trusted yet.'
    from amountTotals

    union all

    select 40, 40, 'Review risk', 'Possible investment transfers counted as spending',
        possibleInvestmentTransferCount::varchar || ' rows / $' || round(possibleInvestmentTransferAmount, 2)::varchar,
        'Pattern: ROBINHOOD. Likely a rule candidate.'
    from reviewPatterns

    union all

    select 40, 50, 'Review risk', 'Possible debt payments counted as spending',
        possibleDebtPaymentCount::varchar || ' rows / $' || round(possibleDebtPaymentAmount, 2)::varchar,
        'Patterns: CAPITAL ONE, CREDIT CARD, PAYMNT, PMT. Likely rule candidates.'
    from reviewPatterns
)
select
    sectionName,
    metricName,
    metricValue,
    detail
from reportRows
order by sectionOrder, metricOrder;
