create or replace temporary table processDimCalendarDate as
with stagedDateText as (
    select postingDate as calendarDateText
    from stageChaseCheckingTransaction
    union all
    select transactionDate as calendarDateText
    from stageChaseCreditTransaction
    union all
    select postDate as calendarDateText
    from stageChaseCreditTransaction
),
parsedCalendarDate as (
    select distinct
        try_strptime(nullif(trim(calendarDateText), ''), '%m/%d/%Y')::date as calendarDate
    from stagedDateText
)
select
    cast(strftime(calendarDate, '%Y%m%d') as integer) as calendarDateKey,
    calendarDate,
    date_part('year', calendarDate)::integer as calendarYear,
    date_part('quarter', calendarDate)::integer as calendarQuarter,
    date_part('month', calendarDate)::integer as calendarMonth,
    strftime(calendarDate, '%B') as calendarMonthName,
    date_part('month', calendarDate)::integer as calendarMonthNumber,
    date_part('day', calendarDate)::integer as calendarDayOfMonth,
    date_part('isodow', calendarDate)::integer as calendarDayOfWeek,
    strftime(calendarDate, '%A') as calendarDayName,
    date_part('isodow', calendarDate) in (6, 7) as isWeekend,
    strftime(calendarDate, '%Y-%m') as yearMonth,
    date_trunc('month', calendarDate)::date as monthStartDate,
    last_day(calendarDate) as monthEndDate
from parsedCalendarDate
where calendarDate is not null;

merge into Silver.dimCalendarDate as targetCalendarDate
using processDimCalendarDate as sourceCalendarDate
on targetCalendarDate.calendarDateKey = sourceCalendarDate.calendarDateKey
when matched
    and (
        targetCalendarDate.calendarDate <> sourceCalendarDate.calendarDate
        or targetCalendarDate.yearMonth <> sourceCalendarDate.yearMonth
    )
    then update set
        calendarDate = sourceCalendarDate.calendarDate,
        calendarYear = sourceCalendarDate.calendarYear,
        calendarQuarter = sourceCalendarDate.calendarQuarter,
        calendarMonth = sourceCalendarDate.calendarMonth,
        calendarMonthName = sourceCalendarDate.calendarMonthName,
        calendarMonthNumber = sourceCalendarDate.calendarMonthNumber,
        calendarDayOfMonth = sourceCalendarDate.calendarDayOfMonth,
        calendarDayOfWeek = sourceCalendarDate.calendarDayOfWeek,
        calendarDayName = sourceCalendarDate.calendarDayName,
        isWeekend = sourceCalendarDate.isWeekend,
        yearMonth = sourceCalendarDate.yearMonth,
        monthStartDate = sourceCalendarDate.monthStartDate,
        monthEndDate = sourceCalendarDate.monthEndDate,
        modifiedDatetime = current_timestamp
when not matched then insert (
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
    monthEndDate,
    createdDatetime,
    modifiedDatetime
)
values (
    sourceCalendarDate.calendarDateKey,
    sourceCalendarDate.calendarDate,
    sourceCalendarDate.calendarYear,
    sourceCalendarDate.calendarQuarter,
    sourceCalendarDate.calendarMonth,
    sourceCalendarDate.calendarMonthName,
    sourceCalendarDate.calendarMonthNumber,
    sourceCalendarDate.calendarDayOfMonth,
    sourceCalendarDate.calendarDayOfWeek,
    sourceCalendarDate.calendarDayName,
    sourceCalendarDate.isWeekend,
    sourceCalendarDate.yearMonth,
    sourceCalendarDate.monthStartDate,
    sourceCalendarDate.monthEndDate,
    current_timestamp,
    current_timestamp
);
