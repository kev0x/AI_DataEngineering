/*
Purpose:
    Idempotently inserts or updates one user-approved category rule.
Dependencies:
    Silver.mapCategoryRule and the bind values supplied by CategoryRuleService.
*/
merge into Silver.mapCategoryRule as targetCategoryRule
using (
    select
        ? as ruleName,
        ? as sourceAccountType,
        null::varchar as sourceCategoryName,
        ? as transactionType,
        ? as descriptionMatchType,
        ? as descriptionMatchText,
        ?::integer as spendingCategoryKey,
        ? as transactionEventType,
        'manual' as categoryAssignmentSource,
        120 as rulePriority
) as sourceCategoryRule
on targetCategoryRule.ruleName = sourceCategoryRule.ruleName
when matched then update set
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
)
