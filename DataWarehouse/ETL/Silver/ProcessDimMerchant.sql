-- Purpose: Upserts merchant dimension rows from cleaned transaction descriptions.
-- Pipeline role: Creates consistent merchant display names before facts join to Silver.dimMerchant for charts and filtering.
-- Dependencies: staged Chase transaction temp tables, Silver.mapMerchantRule, and Silver.dimMerchant.

create or replace temporary table processDimMerchant as
with stagedMerchant as (
    select
        upper(regexp_replace(trim(description), '\s+', ' ', 'g')) as merchantNormalizedName,
        regexp_replace(trim(description), '\s+', ' ', 'g') as merchantDisplayName
    from (
        select description
        from stageChaseCheckingTransaction
        union all
        select description
        from stageChaseCreditTransaction
    ) as stagedDescription
    where nullif(trim(description), '') is not null
),
rankedMerchant as (
    select
        merchantNormalizedName,
        merchantDisplayName,
        row_number() over (
            partition by merchantNormalizedName
            order by merchantDisplayName
        ) as merchantRank
    from stagedMerchant
)
select
    merchantNormalizedName,
    merchantDisplayName
from rankedMerchant
where merchantRank = 1;

merge into Silver.dimMerchant as targetMerchant
using processDimMerchant as sourceMerchant
on targetMerchant.merchantNormalizedName = sourceMerchant.merchantNormalizedName
when matched
    and targetMerchant.merchantDisplayName <> sourceMerchant.merchantDisplayName
    then update set
        merchantDisplayName = sourceMerchant.merchantDisplayName,
        modifiedDatetime = current_timestamp
when not matched then insert (
    merchantNormalizedName,
    merchantDisplayName
)
values (
    sourceMerchant.merchantNormalizedName,
    sourceMerchant.merchantDisplayName
);
