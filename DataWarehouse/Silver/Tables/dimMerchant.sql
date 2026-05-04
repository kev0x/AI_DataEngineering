create sequence if not exists Silver.seqDimMerchantKey
start 100
increment 100;

create table if not exists Silver.dimMerchant (
    merchantKey integer primary key default nextval('Silver.seqDimMerchantKey'),
    merchantNormalizedName varchar not null,
    merchantDisplayName varchar not null,
    isActive boolean not null default true,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (merchantNormalizedName)
);
