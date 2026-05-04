create sequence if not exists Silver.seqDimSourceFileKey
start 100
increment 100;

create table if not exists Silver.dimSourceFile (
    sourceFileKey integer primary key default nextval('Silver.seqDimSourceFileKey'),
    sourceFileName varchar not null,
    sourceFileHash varchar not null,
    sourceFileType varchar not null,
    sourceSystemName varchar not null default 'chase',
    rowCount integer not null default 0,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (sourceFileHash),
    check (sourceFileType in ('chaseCheckingCsv', 'chaseCreditCsv', 'unknown')),
    check (sourceSystemName in ('chase', 'unknown')),
    check (rowCount >= 0)
);
