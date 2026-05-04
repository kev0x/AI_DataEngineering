create sequence if not exists Bronze.seqRawChaseCreditTransactionRecordKey
start 100
increment 100;

create table if not exists Bronze.rawChaseCreditTransaction (
    recordKey integer primary key default nextval('Bronze.seqRawChaseCreditTransactionRecordKey'),
    sourceFileName varchar not null,
    sourceFileHash varchar not null,
    sourceRowNumber integer not null,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    transactionDate varchar,
    postDate varchar,
    description varchar,
    category varchar,
    type varchar,
    amount varchar,
    memo varchar,
    unique (sourceFileHash, sourceRowNumber),
    check (sourceRowNumber > 0)
);
