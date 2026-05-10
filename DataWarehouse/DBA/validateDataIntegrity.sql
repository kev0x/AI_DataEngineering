-- Purpose: Returns failed data integrity checks for row counts, keys, duplicates, and sign semantics.
-- Pipeline role: Acts as the repeatable trust gate after ETL changes so mathematical correctness and privacy rules can be tested quickly.
-- Dependencies: Bronze raw tables, Silver dimensions/facts/map tables, and Gold dashboard views.

with checkResults as (
    select
        'Bronze total equals Silver.factTransaction' as checkName,
        case
            when (
                (select count(*) from Bronze.rawChaseCheckingTransaction)
                + (select count(*) from Bronze.rawChaseCreditTransaction)
            ) = (select count(*) from Silver.factTransaction)
                then 0
            else 1
        end as failedRowCount,
        'Bronze checking + Bronze credit must equal Silver.factTransaction.' as detail

    union all

    select
        'Silver.factTransaction equals Gold.vw_TransactionLedger' as checkName,
        case
            when (select count(*) from Silver.factTransaction)
               = (select count(*) from Gold.vw_TransactionLedger)
                then 0
            else 1
        end as failedRowCount,
        'Gold transaction ledger must preserve the Silver fact grain.' as detail

    union all

    select
        'Bronze checking source grain has no duplicates' as checkName,
        count(*) as failedRowCount,
        'Duplicate sourceFileHash + sourceRowNumber rows in Bronze.rawChaseCheckingTransaction.' as detail
    from (
        select sourceFileHash, sourceRowNumber
        from Bronze.rawChaseCheckingTransaction
        group by sourceFileHash, sourceRowNumber
        having count(*) > 1
    )

    union all

    select
        'Bronze credit source grain has no duplicates' as checkName,
        count(*) as failedRowCount,
        'Duplicate sourceFileHash + sourceRowNumber rows in Bronze.rawChaseCreditTransaction.' as detail
    from (
        select sourceFileHash, sourceRowNumber
        from Bronze.rawChaseCreditTransaction
        group by sourceFileHash, sourceRowNumber
        having count(*) > 1
    )

    union all

    select
        'Silver fact sourceRowIdentifier has no duplicates' as checkName,
        count(*) as failedRowCount,
        'Duplicate sourceRowIdentifier rows in Silver.factTransaction.' as detail
    from (
        select sourceRowIdentifier
        from Silver.factTransaction
        group by sourceRowIdentifier
        having count(*) > 1
    )

    union all

    select
        'Silver fact sourceFileKey/sourceRowNumber has no duplicates' as checkName,
        count(*) as failedRowCount,
        'Duplicate sourceFileKey + sourceRowNumber rows in Silver.factTransaction.' as detail
    from (
        select sourceFileKey, sourceRowNumber
        from Silver.factTransaction
        group by sourceFileKey, sourceRowNumber
        having count(*) > 1
    )

    union all

    select
        'Silver fact required columns have no nulls' as checkName,
        count(*) as failedRowCount,
        'Required fact columns should never be null.' as detail
    from Silver.factTransaction
    where sourceFileKey is null
       or financialAccountKey is null
       or transactionDateKey is null
       or postedDateKey is null
       or merchantKey is null
       or spendingCategoryKey is null
       or sourceRowIdentifier is null
       or transactionType is null
       or transactionEventType is null
       or transactionAmount is null

    union all

    select
        'Silver fact has no unknown core dimension keys' as checkName,
        count(*) as failedRowCount,
        'Core dimensions should resolve beyond the Unknown member for the current source data.' as detail
    from Silver.factTransaction
    where sourceFileKey = -1
       or financialAccountKey = -1
       or transactionDateKey = 19000101
       or postedDateKey = 19000101
       or merchantKey = -1
       or spendingCategoryKey = -1

    union all

    select
        'Silver fact foreign-key joins are complete' as checkName,
        sum(failedJoinCount) as failedRowCount,
        'Every fact foreign key should join to its referenced table.' as detail
    from (
        select count(*) as failedJoinCount
        from Silver.factTransaction f left join Silver.dimSourceFile d on f.sourceFileKey = d.sourceFileKey
        where d.sourceFileKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.dimFinancialAccount d on f.financialAccountKey = d.financialAccountKey
        where d.financialAccountKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.dimCalendarDate d on f.transactionDateKey = d.calendarDateKey
        where d.calendarDateKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.dimCalendarDate d on f.postedDateKey = d.calendarDateKey
        where d.calendarDateKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.dimMerchant d on f.merchantKey = d.merchantKey
        where d.merchantKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.dimSpendingCategory d on f.spendingCategoryKey = d.spendingCategoryKey
        where d.spendingCategoryKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.mapMerchantRule d on f.merchantRuleKey = d.merchantRuleKey
        where d.merchantRuleKey is null

        union all

        select count(*)
        from Silver.factTransaction f left join Silver.mapCategoryRule d on f.categoryRuleKey = d.categoryRuleKey
        where d.categoryRuleKey is null
    )

    union all

    select
        'Transaction event sign rules hold' as checkName,
        count(*) as failedRowCount,
        'Purchases, fees, and debt payments should be negative; income, payments, and refunds should be positive.' as detail
    from Silver.factTransaction
    where (transactionEventType in ('purchase', 'fee', 'debtPayment') and transactionAmount >= 0)
       or (transactionEventType in ('income', 'payment', 'refund') and transactionAmount <= 0)

    union all

    select
        'Transaction event types are valid' as checkName,
        count(*) as failedRowCount,
        'Unexpected transactionEventType values found.' as detail
    from Silver.factTransaction
    where transactionEventType not in ('purchase', 'refund', 'payment', 'income', 'transfer', 'fee', 'debtPayment', 'other')

    union all

    select
        'Gold spending reconciles to Silver purchase minus refund' as checkName,
        case
            when (select coalesce(sum(netSpendingAmount), 0) from Gold.vw_MonthlySpendingByCategory)
               = (
                    select
                        coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'purchase'), 0)
                        - coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'refund'), 0)
                    from Silver.factTransaction
                 )
                then 0
            else 1
        end as failedRowCount,
        'Gold spending should equal Silver purchase amount minus refund amount.' as detail

    union all

    select
        'Gold cashflow reconciles to Silver event totals' as checkName,
        case
            when goldTotals.incomeAmount = silverTotals.incomeAmount
             and goldTotals.outflowAmount = silverTotals.outflowAmount
             and goldTotals.netCashflowAmount = silverTotals.netCashflowAmount
                then 0
            else 1
        end as failedRowCount,
        'Gold cashflow should reconcile to Silver income, purchase, refund, and fee events.' as detail
    from (
        select
            coalesce(sum(incomeAmount), 0) as incomeAmount,
            coalesce(sum(outflowAmount), 0) as outflowAmount,
            coalesce(sum(netCashflowAmount), 0) as netCashflowAmount
        from Gold.vw_MonthlyCashflow
    ) as goldTotals
    cross join (
        select
            coalesce(sum(transactionAmount) filter (where transactionEventType = 'income'), 0) as incomeAmount,
            coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'purchase'), 0)
                - coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'refund'), 0)
                + coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'fee'), 0)
                as outflowAmount,
            coalesce(sum(transactionAmount) filter (where transactionEventType = 'income'), 0)
                - (
                    coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'purchase'), 0)
                    - coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'refund'), 0)
                    + coalesce(sum(abs(transactionAmount)) filter (where transactionEventType = 'fee'), 0)
                )
                as netCashflowAmount
        from Silver.factTransaction
    ) as silverTotals

    union all

    select
        'Gold views do not expose blocked private/raw columns' as checkName,
        count(*) as failedRowCount,
        'Gold views should not expose raw/private column names.' as detail
    from (
        with goldColumns as (
            select
                table_name as viewName,
                column_name as columnName
            from information_schema.columns
            where table_schema = 'Gold'
        ),
        blockedPatterns as (
            select 'description' as pattern
            union all select 'sourceFile'
            union all select 'accountLastFour'
            union all select 'accountDisplayName'
            union all select 'memo'
            union all select 'balance'
            union all select 'checkOrSlip'
        )
        select
            goldColumns.viewName,
            goldColumns.columnName
        from goldColumns
        join blockedPatterns
            on lower(goldColumns.columnName) like '%' || lower(blockedPatterns.pattern) || '%'
    )
)
select
    checkName,
    failedRowCount,
    detail
from checkResults
where failedRowCount <> 0
order by checkName;
