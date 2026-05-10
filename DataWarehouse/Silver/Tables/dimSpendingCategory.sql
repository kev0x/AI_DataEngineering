-- Purpose: Defines the Silver spending category dimension used by dashboard reporting and rule approval.
-- Pipeline role: Provides stable category keys for facts while allowing categories to be seeded, reused, and referenced by rules.
-- Dependencies: Silver schema and DataWarehouse/Silver/Seeds/defaultSpendingCategories.sql.

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
