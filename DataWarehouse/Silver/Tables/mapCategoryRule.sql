-- Purpose: Defines configurable category/event classification rules for transactions.
-- Pipeline role: Keeps business meaning out of hardcoded ETL by letting system, manual, and future AI rules assign categories and event types.
-- Dependencies: Silver.dimSpendingCategory and ProcessFactTransaction.sql, which applies the highest-priority active matching rule.

create sequence if not exists Silver.seqMapCategoryRuleKey
start 100
increment 100;

create table if not exists Silver.mapCategoryRule (
    categoryRuleKey integer primary key default nextval('Silver.seqMapCategoryRuleKey'),
    ruleName varchar not null,
    sourceAccountType varchar,
    sourceCategoryName varchar,
    transactionType varchar,
    descriptionMatchType varchar,
    descriptionMatchText varchar,
    spendingCategoryKey integer not null default -1,
    transactionEventType varchar not null default 'other',
    categoryAssignmentSource varchar not null default 'fallback',
    rulePriority integer not null default 0,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (ruleName),
    check (sourceAccountType is null or sourceAccountType in ('checking', 'creditCard')),
    check (descriptionMatchType is null or descriptionMatchType in ('exact', 'startsWith', 'contains')),
    check (
        (descriptionMatchType is null and descriptionMatchText is null)
        or (descriptionMatchType is not null and descriptionMatchText is not null)
    ),
    check (transactionEventType in ('purchase', 'refund', 'payment', 'income', 'transfer', 'fee', 'debtPayment', 'other')),
    check (categoryAssignmentSource in ('chaseMapped', 'rule', 'fallback', 'manual', 'ai')),
    foreign key (spendingCategoryKey) references Silver.dimSpendingCategory(spendingCategoryKey)
);
