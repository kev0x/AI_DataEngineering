create table if not exists Silver.dimMerchant (
    merchantKey integer primary key,
    merchantNormalizedName varchar not null,
    merchantDisplayName varchar not null,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (merchantNormalizedName)
);

