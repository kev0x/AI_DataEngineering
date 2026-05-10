-- Purpose: Defines the Silver financial account dimension for checking and credit-card sources.
-- Pipeline role: Lets facts join to account type/display attributes without exposing full account identifiers.
-- Dependencies: Silver schema and source file metadata staged by populateWarehouse.py.

create sequence if not exists Silver.seqDimFinancialAccountKey
start 100
increment 100;

create table if not exists Silver.dimFinancialAccount (
    financialAccountKey integer primary key default nextval('Silver.seqDimFinancialAccountKey'),
    institutionName varchar not null default 'chase',
    accountType varchar not null,
    accountLastFour varchar not null default 'unknown',
    accountDisplayName varchar not null,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (institutionName, accountType, accountLastFour),
    check (institutionName in ('chase', 'unknown')),
    check (accountType in ('checking', 'creditCard', 'unknown')),
    check (length(accountLastFour) = 4 or accountLastFour = 'unknown')
);
