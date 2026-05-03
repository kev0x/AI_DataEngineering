create table if not exists Silver.dimFinancialAccount (
    financialAccountKey integer primary key,
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

