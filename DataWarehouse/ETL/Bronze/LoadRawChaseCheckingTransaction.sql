-- Purpose: Loads staged Chase checking rows into the Bronze checking transaction table.
-- Pipeline role: Performs an idempotent MERGE from the temporary queue into Bronze using source file hash and source row number as the source grain.
-- Dependencies: stageChaseCheckingTransaction temp table, Bronze.rawChaseCheckingTransaction, and populateWarehouse.py chunk orchestration.

merge into Bronze.rawChaseCheckingTransaction as targetTransaction
using (
    select
        sourceFileName,
        sourceFileHash,
        sourceRowNumber,
        details,
        postingDate,
        description,
        amount,
        type,
        balance,
        checkOrSlipNumber
    from stageChaseCheckingTransaction
) as sourceTransaction
on targetTransaction.sourceFileHash = sourceTransaction.sourceFileHash
and targetTransaction.sourceRowNumber = sourceTransaction.sourceRowNumber
when matched then update set
    sourceFileName = sourceTransaction.sourceFileName,
    modifiedDatetime = current_timestamp,
    details = sourceTransaction.details,
    postingDate = sourceTransaction.postingDate,
    description = sourceTransaction.description,
    amount = sourceTransaction.amount,
    type = sourceTransaction.type,
    balance = sourceTransaction.balance,
    checkOrSlipNumber = sourceTransaction.checkOrSlipNumber
when not matched then insert (
    sourceFileName,
    sourceFileHash,
    sourceRowNumber,
    createdDatetime,
    modifiedDatetime,
    details,
    postingDate,
    description,
    amount,
    type,
    balance,
    checkOrSlipNumber
)
values (
    sourceTransaction.sourceFileName,
    sourceTransaction.sourceFileHash,
    sourceTransaction.sourceRowNumber,
    current_timestamp,
    current_timestamp,
    sourceTransaction.details,
    sourceTransaction.postingDate,
    sourceTransaction.description,
    sourceTransaction.amount,
    sourceTransaction.type,
    sourceTransaction.balance,
    sourceTransaction.checkOrSlipNumber
);
