create or replace temporary table processMapCategoryRule as
with checkingPrepared as (
    select
        'checking' as sourceAccountType,
        null::varchar as sourceCategoryName,
        coalesce(nullif(trim(type), ''), 'unknown') as transactionType,
        case
            when upper(regexp_replace(trim(description), '\s+', ' ', 'g')) like '%CHASE CREDIT CRD%' then 'CHASE CREDIT CRD'
            when upper(regexp_replace(trim(description), '\s+', ' ', 'g')) like '%CHASE CREDIT CARD%' then 'CHASE CREDIT CARD'
            when upper(regexp_replace(trim(description), '\s+', ' ', 'g')) like '%CREDIT CARD PAYMENT%' then 'CREDIT CARD PAYMENT'
            when upper(regexp_replace(trim(description), '\s+', ' ', 'g')) like '%CREDIT CRD%' then 'CREDIT CRD'
            when upper(regexp_replace(trim(description), '\s+', ' ', 'g')) like '%EPAY%' then 'EPAY'
            else null
        end as creditCardPaymentPattern
    from stageChaseCheckingTransaction
),
checkingAssignment as (
    select
        sourceAccountType,
        sourceCategoryName,
        transactionType,
        case
            when creditCardPaymentPattern is not null then 'contains'
            else null
        end as descriptionMatchType,
        creditCardPaymentPattern as descriptionMatchText,
        case
            when creditCardPaymentPattern is not null then 'DebtPayment'
            when transactionType in ('ACCT_XFER', 'CHASE_TO_PARTNERFI', 'PARTNERFI_TO_CHASE') then 'Transfer'
            when transactionType in ('ACH_CREDIT', 'MISC_CREDIT', 'QUICKPAY_CREDIT') then 'Income'
            when transactionType = 'LOAN_PMT' then 'DebtPayment'
            when transactionType = 'FEE_TRANSACTION' then 'Fee'
            when transactionType = 'BILLPAY' then 'BillsAndUtilities'
            when transactionType in ('ACH_DEBIT', 'DEBIT_CARD', 'MISC_DEBIT') then 'Uncategorized'
            else 'Uncategorized'
        end as spendingCategoryName,
        case
            when creditCardPaymentPattern is not null then 'debtPayment'
            when transactionType in ('ACCT_XFER', 'CHASE_TO_PARTNERFI', 'PARTNERFI_TO_CHASE') then 'transfer'
            when transactionType in ('ACH_CREDIT', 'MISC_CREDIT', 'QUICKPAY_CREDIT') then 'income'
            when transactionType = 'LOAN_PMT' then 'debtPayment'
            when transactionType = 'FEE_TRANSACTION' then 'fee'
            when transactionType = 'BILLPAY' then 'purchase'
            when transactionType in ('ACH_DEBIT', 'DEBIT_CARD', 'MISC_DEBIT') then 'purchase'
            else 'other'
        end as transactionEventType,
        case
            when creditCardPaymentPattern is not null then 'rule'
            when transactionType in ('ACCT_XFER', 'CHASE_TO_PARTNERFI', 'PARTNERFI_TO_CHASE') then 'rule'
            when transactionType in ('ACH_CREDIT', 'MISC_CREDIT', 'QUICKPAY_CREDIT') then 'rule'
            when transactionType in ('LOAN_PMT', 'FEE_TRANSACTION', 'BILLPAY') then 'rule'
            else 'fallback'
        end as categoryAssignmentSource,
        case
            when creditCardPaymentPattern is not null then 90
            when transactionType = 'BILLPAY' then 70
            when transactionType in (
                'ACCT_XFER',
                'CHASE_TO_PARTNERFI',
                'PARTNERFI_TO_CHASE',
                'ACH_CREDIT',
                'MISC_CREDIT',
                'QUICKPAY_CREDIT',
                'LOAN_PMT',
                'FEE_TRANSACTION'
            ) then 80
            else 0
        end as rulePriority
    from checkingPrepared
),
creditAssignment as (
    select
        'creditCard' as sourceAccountType,
        nullif(trim(category), '') as sourceCategoryName,
        coalesce(nullif(trim(type), ''), 'unknown') as transactionType,
        null::varchar as descriptionMatchType,
        null::varchar as descriptionMatchText,
        case
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Payment' then 'DebtPayment'
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Return'
                then case
                    when nullif(trim(category), '') = 'Automotive' then 'Transportation'
                    when nullif(trim(category), '') = 'Bills & Utilities' then 'BillsAndUtilities'
                    when nullif(trim(category), '') = 'Education' then 'Education'
                    when nullif(trim(category), '') = 'Entertainment' then 'Entertainment'
                    when nullif(trim(category), '') = 'Food & Drink' then 'Dining'
                    when nullif(trim(category), '') = 'Gas' then 'Gas'
                    when nullif(trim(category), '') = 'Groceries' then 'Groceries'
                    when nullif(trim(category), '') = 'Health & Wellness' then 'Health'
                    when nullif(trim(category), '') = 'Home' then 'Home'
                    when nullif(trim(category), '') = 'Personal' then 'Personal'
                    when nullif(trim(category), '') = 'Professional Services' then 'ProfessionalServices'
                    when nullif(trim(category), '') = 'Shopping' then 'Shopping'
                    when nullif(trim(category), '') = 'Travel' then 'Travel'
                    else 'Refund'
                end
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Sale'
                then case
                    when nullif(trim(category), '') = 'Automotive' then 'Transportation'
                    when nullif(trim(category), '') = 'Bills & Utilities' then 'BillsAndUtilities'
                    when nullif(trim(category), '') = 'Education' then 'Education'
                    when nullif(trim(category), '') = 'Entertainment' then 'Entertainment'
                    when nullif(trim(category), '') = 'Food & Drink' then 'Dining'
                    when nullif(trim(category), '') = 'Gas' then 'Gas'
                    when nullif(trim(category), '') = 'Groceries' then 'Groceries'
                    when nullif(trim(category), '') = 'Health & Wellness' then 'Health'
                    when nullif(trim(category), '') = 'Home' then 'Home'
                    when nullif(trim(category), '') = 'Personal' then 'Personal'
                    when nullif(trim(category), '') = 'Professional Services' then 'ProfessionalServices'
                    when nullif(trim(category), '') = 'Shopping' then 'Shopping'
                    when nullif(trim(category), '') = 'Travel' then 'Travel'
                    else 'Uncategorized'
                end
            else 'Uncategorized'
        end as spendingCategoryName,
        case
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Sale' then 'purchase'
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Return' then 'refund'
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Payment' then 'payment'
            else 'other'
        end as transactionEventType,
        case
            when coalesce(nullif(trim(type), ''), 'unknown') in ('Sale', 'Return')
             and nullif(trim(category), '') is not null then 'chaseMapped'
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Payment' then 'rule'
            else 'fallback'
        end as categoryAssignmentSource,
        case
            when coalesce(nullif(trim(type), ''), 'unknown') in ('Sale', 'Return')
             and nullif(trim(category), '') is not null then 100
            when coalesce(nullif(trim(type), ''), 'unknown') = 'Payment' then 50
            else 0
        end as rulePriority
    from stageChaseCreditTransaction
),
allAssignment as (
    select * from checkingAssignment
    union all
    select * from creditAssignment
),
distinctCategoryRule as (
    select distinct
        sourceAccountType,
        sourceCategoryName,
        transactionType,
        descriptionMatchType,
        descriptionMatchText,
        coalesce(spendingCategory.spendingCategoryKey, -1) as spendingCategoryKey,
        transactionEventType,
        categoryAssignmentSource,
        rulePriority,
        'Auto Category Rule ' || substr(
            sha256(
                coalesce(sourceAccountType, '') || '|' ||
                coalesce(sourceCategoryName, '') || '|' ||
                coalesce(transactionType, '') || '|' ||
                coalesce(descriptionMatchType, '') || '|' ||
                coalesce(descriptionMatchText, '') || '|' ||
                coalesce(spendingCategory.spendingCategoryKey, -1)::varchar || '|' ||
                coalesce(transactionEventType, '') || '|' ||
                coalesce(categoryAssignmentSource, '')
            ),
            1,
            16
        ) as ruleName
    from allAssignment
    left join Silver.dimSpendingCategory as spendingCategory
        on spendingCategory.spendingCategoryName = allAssignment.spendingCategoryName
),
rankedCategoryRule as (
    select
        *,
        row_number() over (
            partition by ruleName
            order by rulePriority desc, transactionEventType, categoryAssignmentSource
        ) as categoryRuleRank
    from distinctCategoryRule
)
select
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
from rankedCategoryRule
where categoryRuleRank = 1;

merge into Silver.mapCategoryRule as targetCategoryRule
using processMapCategoryRule as sourceCategoryRule
on targetCategoryRule.ruleName = sourceCategoryRule.ruleName
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
