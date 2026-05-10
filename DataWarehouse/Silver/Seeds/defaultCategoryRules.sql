-- Purpose: Seeds starter system category rules for known transfers, debt payments, and common personal-finance patterns.
-- Pipeline role: Keeps business classification data-driven by storing reusable rules in Silver.mapCategoryRule instead of hardcoding merchants in fact ETL.
-- Dependencies: Silver.mapCategoryRule, Silver.dimSpendingCategory, and ProcessFactTransaction.sql rule matching.

update Silver.mapCategoryRule
set
    isActive = false,
    modifiedDatetime = current_timestamp
where ruleName like 'Auto Category Rule %'
  and categoryAssignmentSource = 'rule'
  and descriptionMatchType is not null;

-- The values block below is the starter business-rule dictionary.
-- Each row describes "when a transaction from this source looks like this, classify it as
-- this category/event type." These are system rules, not code branches, so a later manual
-- or AI-approved rule can use the same table and higher priority.
merge into Silver.mapCategoryRule as targetCategoryRule
using (
    with sourceRule as (
        select *
        from (
            values
                (
                    'System Category Rule Checking Chase Credit Card Payment 1',
                    'checking',
                    null,
                    null,
                    'contains',
                    'CHASE CREDIT CRD',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    90
                ),
                (
                    'System Category Rule Checking Chase Credit Card Payment 2',
                    'checking',
                    null,
                    null,
                    'contains',
                    'CHASE CREDIT CARD',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    90
                ),
                (
                    'System Category Rule Checking Generic Credit Card Payment',
                    'checking',
                    null,
                    null,
                    'contains',
                    'CREDIT CARD PAYMENT',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    90
                ),
                (
                    'System Category Rule Checking Credit CRD Payment',
                    'checking',
                    null,
                    null,
                    'contains',
                    'CREDIT CRD',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    90
                ),
                (
                    'System Category Rule Checking Epay Payment',
                    'checking',
                    null,
                    null,
                    'contains',
                    'EPAY',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    80
                ),
                (
                    'System Category Rule Checking Capital One Mobile Payment',
                    'checking',
                    null,
                    null,
                    'contains',
                    'CAPITAL ONE MOBILE PMT',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    95
                ),
                (
                    'System Category Rule Checking Amazon Synchrony Payment',
                    'checking',
                    null,
                    null,
                    'contains',
                    'AMAZON CORP SYF PAYMNT',
                    'DebtPayment',
                    'debtPayment',
                    'rule',
                    95
                ),
                (
                    'System Category Rule Checking Robinhood Investment Transfer',
                    'checking',
                    null,
                    null,
                    'contains',
                    'ROBINHOOD',
                    'Investments',
                    'transfer',
                    'rule',
                    100
                ),
                (
                    'System Category Rule Checking Outgoing Zelle Spending',
                    'checking',
                    null,
                    'CHASE_TO_PARTNERFI',
                    'startsWith',
                    'ZELLE PAYMENT TO',
                    'Personal',
                    'purchase',
                    'rule',
                    95
                )
        ) as ruleValues (
            ruleName,
            sourceAccountType,
            sourceCategoryName,
            transactionType,
            descriptionMatchType,
            descriptionMatchText,
            spendingCategoryName,
            transactionEventType,
            categoryAssignmentSource,
            rulePriority
        )
    )
    select
        -- DuckDB infers VALUES column types from the literals. Explicit casts keep nullable
        -- columns such as sourceCategoryName from being inferred as the wrong type when all
        -- seed rows currently use null.
        sourceRule.ruleName::varchar as ruleName,
        sourceRule.sourceAccountType::varchar as sourceAccountType,
        sourceRule.sourceCategoryName::varchar as sourceCategoryName,
        sourceRule.transactionType::varchar as transactionType,
        sourceRule.descriptionMatchType::varchar as descriptionMatchType,
        sourceRule.descriptionMatchText::varchar as descriptionMatchText,
        spendingCategory.spendingCategoryKey,
        sourceRule.transactionEventType::varchar as transactionEventType,
        sourceRule.categoryAssignmentSource::varchar as categoryAssignmentSource,
        sourceRule.rulePriority::integer as rulePriority
    from sourceRule
    join Silver.dimSpendingCategory as spendingCategory
        on spendingCategory.spendingCategoryName = sourceRule.spendingCategoryName
) as sourceCategoryRule
on targetCategoryRule.ruleName = sourceCategoryRule.ruleName
-- Rerunning deployment should refresh existing seed rules without duplicating them.
when matched
    and (
        coalesce(targetCategoryRule.sourceAccountType, '') <> coalesce(sourceCategoryRule.sourceAccountType, '')
        or coalesce(targetCategoryRule.sourceCategoryName, '') <> coalesce(sourceCategoryRule.sourceCategoryName, '')
        or coalesce(targetCategoryRule.transactionType, '') <> coalesce(sourceCategoryRule.transactionType, '')
        or coalesce(targetCategoryRule.descriptionMatchType, '') <> coalesce(sourceCategoryRule.descriptionMatchType, '')
        or coalesce(targetCategoryRule.descriptionMatchText, '') <> coalesce(sourceCategoryRule.descriptionMatchText, '')
        or targetCategoryRule.spendingCategoryKey <> sourceCategoryRule.spendingCategoryKey
        or targetCategoryRule.transactionEventType <> sourceCategoryRule.transactionEventType
        or targetCategoryRule.categoryAssignmentSource <> sourceCategoryRule.categoryAssignmentSource
        or targetCategoryRule.rulePriority <> sourceCategoryRule.rulePriority
        or targetCategoryRule.isActive = false
    )
    then update set
        sourceAccountType = sourceCategoryRule.sourceAccountType,
        sourceCategoryName = sourceCategoryRule.sourceCategoryName,
        transactionType = sourceCategoryRule.transactionType,
        descriptionMatchType = sourceCategoryRule.descriptionMatchType,
        descriptionMatchText = sourceCategoryRule.descriptionMatchText,
        spendingCategoryKey = sourceCategoryRule.spendingCategoryKey,
        transactionEventType = sourceCategoryRule.transactionEventType,
        categoryAssignmentSource = sourceCategoryRule.categoryAssignmentSource,
        rulePriority = sourceCategoryRule.rulePriority,
        isActive = true,
        modifiedDatetime = current_timestamp
-- New seed rules get their surrogate categoryRuleKey from the table default.
when not matched then insert (
    ruleName,
    sourceAccountType,
    sourceCategoryName,
    transactionType,
    descriptionMatchType,
    descriptionMatchText,
    spendingCategoryKey,
    transactionEventType,
    categoryAssignmentSource,
    rulePriority
)
values (
    sourceCategoryRule.ruleName,
    sourceCategoryRule.sourceAccountType,
    sourceCategoryRule.sourceCategoryName,
    sourceCategoryRule.transactionType,
    sourceCategoryRule.descriptionMatchType,
    sourceCategoryRule.descriptionMatchText,
    sourceCategoryRule.spendingCategoryKey,
    sourceCategoryRule.transactionEventType,
    sourceCategoryRule.categoryAssignmentSource,
    sourceCategoryRule.rulePriority
);
