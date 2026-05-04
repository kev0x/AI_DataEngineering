create sequence if not exists Silver.seqFactTransactionKey
start 100
increment 100;

create table if not exists Silver.factTransaction (
    transactionKey integer primary key default nextval('Silver.seqFactTransactionKey'),
    sourceFileKey integer not null default -1,
    financialAccountKey integer not null default -1,
    transactionDateKey integer not null default 19000101,
    postedDateKey integer not null default 19000101,
    merchantKey integer not null default -1,
    merchantRuleKey integer not null default -1,
    spendingCategoryKey integer not null default -1,
    categoryRuleKey integer not null default -1,
    sourceRowNumber integer not null,
    sourceRowIdentifier varchar not null,
    transactionNaturalKey varchar not null,
    transactionDescription varchar,
    transactionDescriptionClean varchar,
    sourceCategoryName varchar,
    transactionType varchar not null,
    transactionEventType varchar not null default 'other',
    transactionAmount decimal(18, 2) not null,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (sourceRowIdentifier),
    unique (sourceFileKey, sourceRowNumber),
    check (sourceRowNumber > 0),
    check (transactionEventType in ('purchase', 'refund', 'payment', 'income', 'transfer', 'fee', 'debtPayment', 'other')),
    foreign key (sourceFileKey) references Silver.dimSourceFile(sourceFileKey),
    foreign key (financialAccountKey) references Silver.dimFinancialAccount(financialAccountKey),
    foreign key (transactionDateKey) references Silver.dimCalendarDate(calendarDateKey),
    foreign key (postedDateKey) references Silver.dimCalendarDate(calendarDateKey),
    foreign key (merchantKey) references Silver.dimMerchant(merchantKey),
    foreign key (merchantRuleKey) references Silver.mapMerchantRule(merchantRuleKey),
    foreign key (spendingCategoryKey) references Silver.dimSpendingCategory(spendingCategoryKey),
    foreign key (categoryRuleKey) references Silver.mapCategoryRule(categoryRuleKey)
);
