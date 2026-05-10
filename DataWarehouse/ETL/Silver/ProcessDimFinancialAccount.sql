-- Purpose: Upserts account records into Silver.dimFinancialAccount from source file metadata.
-- Pipeline role: Creates a privacy-aware account dimension using account type and last-four-only display attributes.
-- Dependencies: stageSourceFileMetadata temp table and Silver.dimFinancialAccount.

create or replace temporary table processDimFinancialAccount as
with stagedFinancialAccount as (
    select distinct
        accountType,
        accountLastFour,
        case
            when accountType = 'checking' and accountLastFour <> 'unknown'
                then 'Chase Checking ' || accountLastFour
            when accountType = 'creditCard'
                then 'Chase Credit Card'
            else 'Chase Checking'
        end as accountDisplayName
    from stageSourceFileMetadata
),
rankedFinancialAccount as (
    select
        accountType,
        accountLastFour,
        accountDisplayName,
        row_number() over (
            partition by accountType, accountLastFour
            order by accountDisplayName
        ) as financialAccountRank
    from stagedFinancialAccount
)
select
    accountType,
    accountLastFour,
    accountDisplayName
from rankedFinancialAccount
where financialAccountRank = 1;

merge into Silver.dimFinancialAccount as targetFinancialAccount
using processDimFinancialAccount as sourceFinancialAccount
on targetFinancialAccount.institutionName = 'chase'
and targetFinancialAccount.accountType = sourceFinancialAccount.accountType
and targetFinancialAccount.accountLastFour = sourceFinancialAccount.accountLastFour
when matched
    and targetFinancialAccount.accountDisplayName <> sourceFinancialAccount.accountDisplayName
    then update set
        accountDisplayName = sourceFinancialAccount.accountDisplayName,
        modifiedDatetime = current_timestamp
when not matched then insert (
    accountType,
    accountLastFour,
    accountDisplayName
)
values (
    sourceFinancialAccount.accountType,
    sourceFinancialAccount.accountLastFour,
    sourceFinancialAccount.accountDisplayName
);
