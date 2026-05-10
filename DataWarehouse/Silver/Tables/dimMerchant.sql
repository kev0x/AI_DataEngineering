-- Purpose: Defines the Silver merchant dimension used by transaction facts and merchant spending charts.
-- Pipeline role: Stores cleaned merchant display names derived from Chase descriptions while keeping the parsing logic traceable through rules.
-- Dependencies: Silver schema, Silver.mapMerchantRule, and ProcessDimMerchant.sql.

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
