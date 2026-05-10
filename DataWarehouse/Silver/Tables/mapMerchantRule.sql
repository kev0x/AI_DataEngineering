-- Purpose: Defines configurable merchant-name cleanup rules for transaction descriptions.
-- Pipeline role: Turns noisy Chase descriptions into consistent merchant display names before facts join to Silver.dimMerchant.
-- Dependencies: Silver.dimMerchant and ProcessDimMerchant/ProcessFactTransaction SQL transforms.

create sequence if not exists Silver.seqMapMerchantRuleKey
start 100
increment 100;

create table if not exists Silver.mapMerchantRule (
    merchantRuleKey integer primary key default nextval('Silver.seqMapMerchantRuleKey'),
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
