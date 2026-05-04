create or replace temporary table processMapMerchantRule as
select
    'Auto Merchant Rule ' || substr(
        sha256(merchant.merchantNormalizedName || '|' || merchant.merchantKey::varchar),
        1,
        16
    ) as ruleName,
    'exact' as descriptionMatchType,
    merchant.merchantNormalizedName as descriptionMatchText,
    merchant.merchantKey,
    10 as rulePriority
from Silver.dimMerchant as merchant
where merchant.merchantKey > 0;

merge into Silver.mapMerchantRule as targetMerchantRule
using processMapMerchantRule as sourceMerchantRule
on targetMerchantRule.descriptionMatchType = sourceMerchantRule.descriptionMatchType
and targetMerchantRule.descriptionMatchText = sourceMerchantRule.descriptionMatchText
and targetMerchantRule.merchantKey = sourceMerchantRule.merchantKey
when matched
    and (
        targetMerchantRule.ruleName <> sourceMerchantRule.ruleName
        or targetMerchantRule.rulePriority <> sourceMerchantRule.rulePriority
        or targetMerchantRule.isActive = false
    )
    then update set
        ruleName = sourceMerchantRule.ruleName,
        rulePriority = sourceMerchantRule.rulePriority,
        isActive = true,
        modifiedDatetime = current_timestamp
when not matched then insert (
    ruleName,
    descriptionMatchType,
    descriptionMatchText,
    merchantKey,
    rulePriority
)
values (
    sourceMerchantRule.ruleName,
    sourceMerchantRule.descriptionMatchType,
    sourceMerchantRule.descriptionMatchText,
    sourceMerchantRule.merchantKey,
    sourceMerchantRule.rulePriority
);
