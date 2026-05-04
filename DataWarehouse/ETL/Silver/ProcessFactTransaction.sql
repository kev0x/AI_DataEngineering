create or replace temporary table processFactTransaction as
with sourceTransaction as (
    select
        sourceFileHash,
        sourceFileType,
        sourceRowNumber,
        'checking' as sourceAccountType,
        postingDate as transactionDateText,
        postingDate as postedDateText,
        description,
        null::varchar as sourceCategoryName,
        coalesce(nullif(trim(type), ''), 'unknown') as transactionType,
        amount as transactionAmountText
    from stageChaseCheckingTransaction
    union all
    select
        sourceFileHash,
        sourceFileType,
        sourceRowNumber,
        'creditCard' as sourceAccountType,
        transactionDate as transactionDateText,
        postDate as postedDateText,
        description,
        nullif(trim(category), '') as sourceCategoryName,
        coalesce(nullif(trim(type), ''), 'unknown') as transactionType,
        amount as transactionAmountText
    from stageChaseCreditTransaction
),
preparedTransaction as (
    select
        *,
        sourceFileType || ':' || sourceFileHash || ':' || sourceRowNumber::varchar as sourceRowIdentifier,
        try_strptime(nullif(trim(transactionDateText), ''), '%m/%d/%Y')::date as transactionDate,
        try_strptime(nullif(trim(postedDateText), ''), '%m/%d/%Y')::date as postedDate,
        regexp_replace(trim(description), '\s+', ' ', 'g') as transactionDescription,
        upper(regexp_replace(trim(description), '\s+', ' ', 'g')) as transactionDescriptionClean,
        replace(replace(replace(trim(transactionAmountText), '$', ''), ',', ''), ' ', '') as transactionAmountClean
    from sourceTransaction
),
normalizedTransaction as (
    select
        *,
        case
            when left(transactionAmountClean, 1) = '(' and right(transactionAmountClean, 1) = ')'
                then ('-' || replace(replace(transactionAmountClean, '(', ''), ')', ''))::decimal(18, 2)
            else transactionAmountClean::decimal(18, 2)
        end as transactionAmount
    from preparedTransaction
),
classifiedTransaction as (
    select
        *,
        case
            when sourceAccountType = 'checking'
             and transactionDescriptionClean like '%CHASE CREDIT CRD%' then 'CHASE CREDIT CRD'
            when sourceAccountType = 'checking'
             and transactionDescriptionClean like '%CHASE CREDIT CARD%' then 'CHASE CREDIT CARD'
            when sourceAccountType = 'checking'
             and transactionDescriptionClean like '%CREDIT CARD PAYMENT%' then 'CREDIT CARD PAYMENT'
            when sourceAccountType = 'checking'
             and transactionDescriptionClean like '%CREDIT CRD%' then 'CREDIT CRD'
            when sourceAccountType = 'checking'
             and transactionDescriptionClean like '%EPAY%' then 'EPAY'
            else null
        end as creditCardPaymentPattern
    from normalizedTransaction
),
assignedTransaction as (
    select
        *,
        case
            when sourceAccountType = 'checking' and creditCardPaymentPattern is not null then 'contains'
            else null
        end as descriptionMatchType,
        creditCardPaymentPattern as descriptionMatchText,
        case
            when sourceAccountType = 'checking' and creditCardPaymentPattern is not null then 'DebtPayment'
            when sourceAccountType = 'checking'
             and transactionType in ('ACCT_XFER', 'CHASE_TO_PARTNERFI', 'PARTNERFI_TO_CHASE') then 'Transfer'
            when sourceAccountType = 'checking'
             and transactionType in ('ACH_CREDIT', 'MISC_CREDIT', 'QUICKPAY_CREDIT') then 'Income'
            when sourceAccountType = 'checking' and transactionType = 'LOAN_PMT' then 'DebtPayment'
            when sourceAccountType = 'checking' and transactionType = 'FEE_TRANSACTION' then 'Fee'
            when sourceAccountType = 'checking' and transactionType = 'BILLPAY' then 'BillsAndUtilities'
            when sourceAccountType = 'checking'
             and transactionType in ('ACH_DEBIT', 'DEBIT_CARD', 'MISC_DEBIT') then 'Uncategorized'
            when sourceAccountType = 'creditCard' and transactionType = 'Payment' then 'DebtPayment'
            when sourceAccountType = 'creditCard' and transactionType = 'Return'
                then case
                    when sourceCategoryName = 'Automotive' then 'Transportation'
                    when sourceCategoryName = 'Bills & Utilities' then 'BillsAndUtilities'
                    when sourceCategoryName = 'Education' then 'Education'
                    when sourceCategoryName = 'Entertainment' then 'Entertainment'
                    when sourceCategoryName = 'Food & Drink' then 'Dining'
                    when sourceCategoryName = 'Gas' then 'Gas'
                    when sourceCategoryName = 'Groceries' then 'Groceries'
                    when sourceCategoryName = 'Health & Wellness' then 'Health'
                    when sourceCategoryName = 'Home' then 'Home'
                    when sourceCategoryName = 'Personal' then 'Personal'
                    when sourceCategoryName = 'Professional Services' then 'ProfessionalServices'
                    when sourceCategoryName = 'Shopping' then 'Shopping'
                    when sourceCategoryName = 'Travel' then 'Travel'
                    else 'Refund'
                end
            when sourceAccountType = 'creditCard' and transactionType = 'Sale'
                then case
                    when sourceCategoryName = 'Automotive' then 'Transportation'
                    when sourceCategoryName = 'Bills & Utilities' then 'BillsAndUtilities'
                    when sourceCategoryName = 'Education' then 'Education'
                    when sourceCategoryName = 'Entertainment' then 'Entertainment'
                    when sourceCategoryName = 'Food & Drink' then 'Dining'
                    when sourceCategoryName = 'Gas' then 'Gas'
                    when sourceCategoryName = 'Groceries' then 'Groceries'
                    when sourceCategoryName = 'Health & Wellness' then 'Health'
                    when sourceCategoryName = 'Home' then 'Home'
                    when sourceCategoryName = 'Personal' then 'Personal'
                    when sourceCategoryName = 'Professional Services' then 'ProfessionalServices'
                    when sourceCategoryName = 'Shopping' then 'Shopping'
                    when sourceCategoryName = 'Travel' then 'Travel'
                    else 'Uncategorized'
                end
            else 'Uncategorized'
        end as spendingCategoryName,
        case
            when sourceAccountType = 'checking' and creditCardPaymentPattern is not null then 'debtPayment'
            when sourceAccountType = 'checking'
             and transactionType in ('ACCT_XFER', 'CHASE_TO_PARTNERFI', 'PARTNERFI_TO_CHASE') then 'transfer'
            when sourceAccountType = 'checking'
             and transactionType in ('ACH_CREDIT', 'MISC_CREDIT', 'QUICKPAY_CREDIT') then 'income'
            when sourceAccountType = 'checking' and transactionType = 'LOAN_PMT' then 'debtPayment'
            when sourceAccountType = 'checking' and transactionType = 'FEE_TRANSACTION' then 'fee'
            when sourceAccountType = 'checking' and transactionType = 'BILLPAY' then 'purchase'
            when sourceAccountType = 'checking'
             and transactionType in ('ACH_DEBIT', 'DEBIT_CARD', 'MISC_DEBIT') then 'purchase'
            when sourceAccountType = 'creditCard' and transactionType = 'Sale' then 'purchase'
            when sourceAccountType = 'creditCard' and transactionType = 'Return' then 'refund'
            when sourceAccountType = 'creditCard' and transactionType = 'Payment' then 'payment'
            else 'other'
        end as transactionEventType,
        case
            when sourceAccountType = 'checking' and creditCardPaymentPattern is not null then 'rule'
            when sourceAccountType = 'checking'
             and transactionType in (
                'ACCT_XFER',
                'CHASE_TO_PARTNERFI',
                'PARTNERFI_TO_CHASE',
                'ACH_CREDIT',
                'MISC_CREDIT',
                'QUICKPAY_CREDIT',
                'LOAN_PMT',
                'FEE_TRANSACTION',
                'BILLPAY'
             ) then 'rule'
            when sourceAccountType = 'creditCard'
             and transactionType in ('Sale', 'Return')
             and sourceCategoryName is not null then 'chaseMapped'
            when sourceAccountType = 'creditCard' and transactionType = 'Payment' then 'rule'
            else 'fallback'
        end as categoryAssignmentSource
    from classifiedTransaction
),
assignedTransactionWithRule as (
    select
        assignedTransaction.*,
        coalesce(spendingCategory.spendingCategoryKey, -1) as assignedSpendingCategoryKey,
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
        ) as categoryRuleName
    from assignedTransaction
    left join Silver.dimSpendingCategory as spendingCategory
        on spendingCategory.spendingCategoryName = assignedTransaction.spendingCategoryName
),
newFactTransaction as (
    select
        sourceFile.sourceFileKey,
        coalesce(financialAccount.financialAccountKey, -1) as financialAccountKey,
        coalesce(cast(strftime(transactionDate, '%Y%m%d') as integer), 19000101) as transactionDateKey,
        coalesce(cast(strftime(postedDate, '%Y%m%d') as integer), 19000101) as postedDateKey,
        coalesce(merchant.merchantKey, -1) as merchantKey,
        coalesce(merchantRule.merchantRuleKey, -1) as merchantRuleKey,
        coalesce(categoryRule.spendingCategoryKey, assignedSpendingCategoryKey, -1) as spendingCategoryKey,
        coalesce(categoryRule.categoryRuleKey, -1) as categoryRuleKey,
        assignedTransactionWithRule.sourceRowNumber,
        assignedTransactionWithRule.sourceRowIdentifier,
        sha256(
            assignedTransactionWithRule.sourceFileHash || '|' ||
            assignedTransactionWithRule.sourceRowNumber::varchar || '|' ||
            coalesce(assignedTransactionWithRule.transactionDescriptionClean, '') || '|' ||
            assignedTransactionWithRule.transactionAmount::varchar || '|' ||
            assignedTransactionWithRule.transactionType
        ) as transactionNaturalKey,
        assignedTransactionWithRule.transactionDescription,
        assignedTransactionWithRule.transactionDescriptionClean,
        assignedTransactionWithRule.sourceCategoryName,
        assignedTransactionWithRule.transactionType,
        assignedTransactionWithRule.transactionEventType,
        assignedTransactionWithRule.transactionAmount
    from assignedTransactionWithRule
    join Silver.dimSourceFile as sourceFile
        on sourceFile.sourceFileHash = assignedTransactionWithRule.sourceFileHash
    left join stageSourceFileMetadata as sourceFileMetadata
        on sourceFileMetadata.sourceFileHash = assignedTransactionWithRule.sourceFileHash
    left join Silver.dimFinancialAccount as financialAccount
        on financialAccount.institutionName = 'chase'
       and financialAccount.accountType = assignedTransactionWithRule.sourceAccountType
       and financialAccount.accountLastFour = sourceFileMetadata.accountLastFour
    left join Silver.dimMerchant as merchant
        on merchant.merchantNormalizedName = assignedTransactionWithRule.transactionDescriptionClean
    left join Silver.mapMerchantRule as merchantRule
        on merchantRule.descriptionMatchType = 'exact'
       and merchantRule.descriptionMatchText = assignedTransactionWithRule.transactionDescriptionClean
       and merchantRule.merchantKey = merchant.merchantKey
    left join Silver.mapCategoryRule as categoryRule
        on categoryRule.ruleName = assignedTransactionWithRule.categoryRuleName
),
rankedFactTransaction as (
    select
        *,
        row_number() over (
            partition by sourceRowIdentifier
            order by sourceRowNumber
        ) as transactionRank
    from newFactTransaction
)
select
    sourceFileKey,
    financialAccountKey,
    transactionDateKey,
    postedDateKey,
    merchantKey,
    merchantRuleKey,
    spendingCategoryKey,
    categoryRuleKey,
    sourceRowNumber,
    sourceRowIdentifier,
    transactionNaturalKey,
    transactionDescription,
    transactionDescriptionClean,
    sourceCategoryName,
    transactionType,
    transactionEventType,
    transactionAmount
from rankedFactTransaction
where transactionRank = 1;

merge into Silver.factTransaction as targetFactTransaction
using processFactTransaction as sourceFactTransaction
on targetFactTransaction.sourceRowIdentifier = sourceFactTransaction.sourceRowIdentifier
when matched
    and (
        targetFactTransaction.sourceFileKey <> sourceFactTransaction.sourceFileKey
        or targetFactTransaction.financialAccountKey <> sourceFactTransaction.financialAccountKey
        or targetFactTransaction.transactionDateKey <> sourceFactTransaction.transactionDateKey
        or targetFactTransaction.postedDateKey <> sourceFactTransaction.postedDateKey
        or targetFactTransaction.merchantKey <> sourceFactTransaction.merchantKey
        or targetFactTransaction.merchantRuleKey <> sourceFactTransaction.merchantRuleKey
        or targetFactTransaction.spendingCategoryKey <> sourceFactTransaction.spendingCategoryKey
        or targetFactTransaction.categoryRuleKey <> sourceFactTransaction.categoryRuleKey
        or targetFactTransaction.transactionNaturalKey <> sourceFactTransaction.transactionNaturalKey
        or coalesce(targetFactTransaction.transactionDescription, '') <> coalesce(sourceFactTransaction.transactionDescription, '')
        or coalesce(targetFactTransaction.transactionDescriptionClean, '') <> coalesce(sourceFactTransaction.transactionDescriptionClean, '')
        or coalesce(targetFactTransaction.sourceCategoryName, '') <> coalesce(sourceFactTransaction.sourceCategoryName, '')
        or targetFactTransaction.transactionType <> sourceFactTransaction.transactionType
        or targetFactTransaction.transactionEventType <> sourceFactTransaction.transactionEventType
        or targetFactTransaction.transactionAmount <> sourceFactTransaction.transactionAmount
    )
    then update set
        sourceFileKey = sourceFactTransaction.sourceFileKey,
        financialAccountKey = sourceFactTransaction.financialAccountKey,
        transactionDateKey = sourceFactTransaction.transactionDateKey,
        postedDateKey = sourceFactTransaction.postedDateKey,
        merchantKey = sourceFactTransaction.merchantKey,
        merchantRuleKey = sourceFactTransaction.merchantRuleKey,
        spendingCategoryKey = sourceFactTransaction.spendingCategoryKey,
        categoryRuleKey = sourceFactTransaction.categoryRuleKey,
        transactionNaturalKey = sourceFactTransaction.transactionNaturalKey,
        transactionDescription = sourceFactTransaction.transactionDescription,
        transactionDescriptionClean = sourceFactTransaction.transactionDescriptionClean,
        sourceCategoryName = sourceFactTransaction.sourceCategoryName,
        transactionType = sourceFactTransaction.transactionType,
        transactionEventType = sourceFactTransaction.transactionEventType,
        transactionAmount = sourceFactTransaction.transactionAmount,
        modifiedDatetime = current_timestamp
when not matched then insert (
    sourceFileKey,
    financialAccountKey,
    transactionDateKey,
    postedDateKey,
    merchantKey,
    merchantRuleKey,
    spendingCategoryKey,
    categoryRuleKey,
    sourceRowNumber,
    sourceRowIdentifier,
    transactionNaturalKey,
    transactionDescription,
    transactionDescriptionClean,
    sourceCategoryName,
    transactionType,
    transactionEventType,
    transactionAmount
)
values (
    sourceFactTransaction.sourceFileKey,
    sourceFactTransaction.financialAccountKey,
    sourceFactTransaction.transactionDateKey,
    sourceFactTransaction.postedDateKey,
    sourceFactTransaction.merchantKey,
    sourceFactTransaction.merchantRuleKey,
    sourceFactTransaction.spendingCategoryKey,
    sourceFactTransaction.categoryRuleKey,
    sourceFactTransaction.sourceRowNumber,
    sourceFactTransaction.sourceRowIdentifier,
    sourceFactTransaction.transactionNaturalKey,
    sourceFactTransaction.transactionDescription,
    sourceFactTransaction.transactionDescriptionClean,
    sourceFactTransaction.sourceCategoryName,
    sourceFactTransaction.transactionType,
    sourceFactTransaction.transactionEventType,
    sourceFactTransaction.transactionAmount
);
