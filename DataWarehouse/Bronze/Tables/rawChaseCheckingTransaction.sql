-- Purpose: Defines the source-shaped Bronze table for Chase checking CSV transaction rows.
-- Pipeline role: Preserves checking data close to the incoming CSV shape while adding record keys, file lineage, source row numbers, and UTC audit timestamps.
-- Dependencies: Bronze schema and the stageChaseCheckingTransaction temp table loaded by populateWarehouse.py.

create sequence if not exists Bronze.seqRawChaseCheckingTransactionRecordKey
start 100
increment 100;

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
