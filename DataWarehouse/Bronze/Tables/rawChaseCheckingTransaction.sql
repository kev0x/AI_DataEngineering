create table if not exists Bronze.rawChaseCheckingTransaction (
    recordKey integer primary key default nextval('Bronze.seqRawChaseCheckingTransactionRecordKey'),
    sourceFileName varchar not null,
    sourceFileHash varchar not null,
    sourceRowNumber integer not null,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    details varchar,
    postingDate varchar,
    description varchar,
    amount varchar,
    type varchar,
    balance varchar,
    checkOrSlipNumber varchar,
    unique (sourceFileHash, sourceRowNumber),
    check (sourceRowNumber > 0)
);

