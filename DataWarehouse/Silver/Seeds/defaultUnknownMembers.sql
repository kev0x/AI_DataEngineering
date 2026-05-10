-- Purpose: Seeds default Unknown members used when a required dimension value is missing.
-- Pipeline role: Keeps fact foreign keys non-null while making unresolved data obvious through -1 or 19000101 defaults.
-- Dependencies: Silver dimension and map tables must exist before this seed runs.

insert or ignore into Silver.dimSourceFile (
    sourceFileKey,
    sourceFileName,
    sourceFileHash,
    sourceFileType,
    sourceSystemName,
    rowCount
) values (
    -1,
    'Unknown',
    'unknown',
    'unknown',
    'unknown',
    0
);

insert or ignore into Silver.dimFinancialAccount (
    financialAccountKey,
    institutionName,
    accountType,
    accountLastFour,
    accountDisplayName
) values (
    -1,
    'unknown',
    'unknown',
    'unknown',
    'Unknown Account'
);

insert or ignore into Silver.dimMerchant (
    merchantKey,
    merchantNormalizedName,
    merchantDisplayName
) values (
    -1,
    'unknown',
    'Unknown Merchant'
);

insert or ignore into Silver.dimCalendarDate (
    calendarDateKey,
    calendarDate,
    calendarYear,
    calendarQuarter,
    calendarMonth,
    calendarMonthName,
    calendarMonthNumber,
    calendarDayOfMonth,
    calendarDayOfWeek,
    calendarDayName,
    isWeekend,
    yearMonth,
    monthStartDate,
    monthEndDate
) values (
    19000101,
    date '1900-01-01',
    1900,
    1,
    1,
    'January',
    1,
    1,
    1,
    'Monday',
    false,
    '1900-01',
    date '1900-01-01',
    date '1900-01-31'
);

insert or ignore into Silver.mapMerchantRule (
    merchantRuleKey,
    ruleName,
    descriptionMatchType,
    descriptionMatchText,
    merchantKey,
    rulePriority
) values (
    -1,
    'Unknown Merchant Rule',
    'exact',
    '__NO_MERCHANT_RULE__',
    -1,
    0
);

insert or ignore into Silver.mapCategoryRule (
    categoryRuleKey,
    ruleName,
    spendingCategoryKey,
    transactionEventType,
    categoryAssignmentSource,
    rulePriority
) values (
    -1,
    'Unknown Category Rule',
    -1,
    'other',
    'fallback',
    0
);
