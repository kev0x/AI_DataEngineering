/**
 * Purpose: Provides date parsing, formatting, and range helper methods for dashboard filters and analytics.
 * Runtime role: Normalizes JavaScript Date behavior so charts, date inputs, and transaction filtering all interpret dates consistently.
 * Dependencies: Native JavaScript Date and ISO-style date strings from Gold.vw_TransactionLedger.
 */

export class DateRange {
  static boundsFromTransactions(transactionRows) {
    const validDates = transactionRows
      .map((transaction) => DateRange.parseLocalDate(transaction.transactionDate))
      .filter(Boolean);
    if (validDates.length === 0) {
      return null;
    }
    const timestamps = validDates.map((transactionDate) => transactionDate.getTime());
    return {
      earliestDate: new Date(Math.min(...timestamps)),
      latestDate: new Date(Math.max(...timestamps)),
    };
  }

  static dateInputValue(dateValue) {
    if (!dateValue) {
      return "";
    }
    const month = String(dateValue.getMonth() + 1).padStart(2, "0");
    const day = String(dateValue.getDate()).padStart(2, "0");
    return `${dateValue.getFullYear()}-${month}-${day}`;
  }

  static fromDateInputs(selectedStartDate, selectedEndDate) {
    const startDate = DateRange.parseLocalDate(selectedStartDate);
    const endDate = DateRange.parseLocalDate(selectedEndDate);
    if (!startDate || !endDate) {
      return null;
    }
    return startDate <= endDate
      ? { startDate, endDate }
      : { startDate: endDate, endDate: startDate };
  }

  static includesDate(transactionDateText, selectedStartDate, selectedEndDate) {
    const transactionDate = DateRange.parseLocalDate(transactionDateText);
    if (!transactionDate) {
      return false;
    }
    const selectedDateWindow = DateRange.fromDateInputs(selectedStartDate, selectedEndDate);
    if (!selectedDateWindow) {
      return true;
    }
    return transactionDate >= selectedDateWindow.startDate
      && transactionDate <= selectedDateWindow.endDate;
  }

  static parseLocalDate(dateText) {
    if (!dateText) {
      return null;
    }
    const [year, month, day] = dateText.split("-").map(Number);
    if (!year || !month || !day) {
      return null;
    }
    return new Date(year, month - 1, day);
  }
}
