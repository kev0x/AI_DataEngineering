create table if not exists Silver.mapMerchantRule (
    merchantRuleKey integer primary key,
    ruleName varchar not null,
    descriptionMatchType varchar not null,
    descriptionMatchText varchar not null,
    merchantKey integer not null default -1,
    rulePriority integer not null default 0,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (ruleName),
    unique (descriptionMatchType, descriptionMatchText, merchantKey),
    check (descriptionMatchType in ('exact', 'startsWith', 'contains')),
    foreign key (merchantKey) references Silver.dimMerchant(merchantKey)
);

