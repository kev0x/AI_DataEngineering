-- Purpose: Defines the Silver calendar date dimension used by transaction and posted date keys.
-- Pipeline role: Gives facts deterministic YYYYMMDD date keys plus month/year attributes for filtering, grouping, and charting.
-- Dependencies: Silver schema; populated by DataWarehouse/ETL/Silver/ProcessDimCalendarDate.sql.

create table if not exists Silver.dimCalendarDate (
    calendarDateKey integer primary key,
    calendarDate date not null,
    calendarYear integer not null,
    calendarQuarter integer not null,
    calendarMonth integer not null,
    calendarMonthName varchar not null,
    calendarMonthNumber integer not null,
    calendarDayOfMonth integer not null,
    calendarDayOfWeek integer not null,
    calendarDayName varchar not null,
    isWeekend boolean not null,
    yearMonth varchar not null,
    monthStartDate date not null,
    monthEndDate date not null,
    createdDatetime timestamp not null default current_timestamp,
    modifiedDatetime timestamp not null default current_timestamp,
    unique (calendarDate),
    check (calendarMonth between 1 and 12),
    check (calendarMonthNumber between 1 and 12),
    check (calendarQuarter between 1 and 4),
    check (calendarDayOfMonth between 1 and 31)
);
