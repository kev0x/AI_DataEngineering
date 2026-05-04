merge into Bronze.rawChaseCreditTransaction as targetTransaction
using (
    select
        sourceFileName,
        sourceFileHash,
        sourceRowNumber,
        transactionDate,
        postDate,
        description,
        category,
        type,
        amount,
        memo
    from stageChaseCreditTransaction
) as sourceTransaction
on targetTransaction.sourceFileHash = sourceTransaction.sourceFileHash
and targetTransaction.sourceRowNumber = sourceTransaction.sourceRowNumber
when matched then update set
    sourceFileName = sourceTransaction.sourceFileName,
    modifiedDatetime = current_timestamp,
    transactionDate = sourceTransaction.transactionDate,
    postDate = sourceTransaction.postDate,
    description = sourceTransaction.description,
    category = sourceTransaction.category,
    type = sourceTransaction.type,
    amount = sourceTransaction.amount,
    memo = sourceTransaction.memo
when not matched then insert (
    sourceFileName,
    sourceFileHash,
    sourceRowNumber,
    createdDatetime,
    modifiedDatetime,
    transactionDate,
    postDate,
    description,
    category,
    type,
    amount,
    memo
)
values (
    sourceTransaction.sourceFileName,
    sourceTransaction.sourceFileHash,
    sourceTransaction.sourceRowNumber,
    current_timestamp,
    current_timestamp,
    sourceTransaction.transactionDate,
    sourceTransaction.postDate,
    sourceTransaction.description,
    sourceTransaction.category,
    sourceTransaction.type,
    sourceTransaction.amount,
    sourceTransaction.memo
);
