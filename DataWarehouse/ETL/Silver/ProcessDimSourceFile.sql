-- Purpose: Upserts source file metadata into Silver.dimSourceFile.
-- Pipeline role: Creates the file lineage dimension that Bronze and Silver transaction rows use to prove where each row came from.
-- Dependencies: stageSourceFileMetadata temp table and Silver.dimSourceFile.

create or replace temporary table processDimSourceFile as
with rankedSourceFile as (
    select
        sourceFileName,
        sourceFileHash,
        sourceFileType,
        rowCount,
        row_number() over (
            partition by sourceFileHash
            order by sourceFileName
        ) as sourceFileRank
    from stageSourceFileMetadata
)
select
    sourceFileName,
    sourceFileHash,
    sourceFileType,
    rowCount
from rankedSourceFile
where sourceFileRank = 1;

merge into Silver.dimSourceFile as targetSourceFile
using processDimSourceFile as sourceFile
on targetSourceFile.sourceFileHash = sourceFile.sourceFileHash
when matched
    and (
        targetSourceFile.sourceFileName <> sourceFile.sourceFileName
        or targetSourceFile.sourceFileType <> sourceFile.sourceFileType
        or targetSourceFile.rowCount <> sourceFile.rowCount
    )
    then update set
        sourceFileName = sourceFile.sourceFileName,
        sourceFileType = sourceFile.sourceFileType,
        rowCount = sourceFile.rowCount,
        modifiedDatetime = current_timestamp
when not matched then insert (
    sourceFileName,
    sourceFileHash,
    sourceFileType,
    rowCount
)
values (
    sourceFile.sourceFileName,
    sourceFile.sourceFileHash,
    sourceFile.sourceFileType,
    sourceFile.rowCount
);
