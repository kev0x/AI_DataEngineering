create table if not exists Silver.dimSpendingCategory (
    spendingCategoryKey integer primary key,
    spendingCategoryName varchar not null,
    parentSpendingCategoryName varchar not null,
    spendingCategoryDescription varchar,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (spendingCategoryName)
);

