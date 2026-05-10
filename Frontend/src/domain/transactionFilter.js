/**
 * Purpose: Applies account, category, date, and search filters to dashboard transactions.
 * Runtime role: Encapsulates row-matching logic so App.jsx can ask for filtered rows without knowing each predicate detail.
 * Dependencies: DateRange helpers, account label formatting, and transaction rows from Gold.vw_TransactionLedger.
 */

import { accountLabel } from "./formatters.js";
import { DateRange } from "./dateRange.js";

export class TransactionFilter {
  /**
   * Store normalized filter values once so each row can be checked cheaply.
   * The filter object mirrors defaultDashboardFilters from dashboardOptions.js.
   */
  constructor({
    selectedAccount,
    selectedCategory,
    selectedStartDate,
    selectedEndDate,
    transactionSearchText,
  }) {
    this.selectedAccount = selectedAccount;
    this.selectedCategory = selectedCategory;
    this.selectedStartDate = selectedStartDate;
    this.selectedEndDate = selectedEndDate;
    this.normalizedSearchText = transactionSearchText.trim().toLowerCase();
  }

  /**
   * Public entry point used by App.jsx.
   * Returns the rows that should drive every KPI, chart, suggestion, table, and export.
   */
  static apply(transactionRows, filterValues) {
    const transactionFilter = new TransactionFilter(filterValues);
    return transactionRows.filter((transaction) => transactionFilter.matches(transaction));
  }

  /**
   * Check one transaction against account, category, date, and search predicates.
   * Returning early keeps each rule easy to read and easy to extend later.
   */
  matches(transaction) {
    if (this.selectedAccount !== "all" && transaction.accountType !== this.selectedAccount) {
      return false;
    }
    if (this.selectedCategory !== "all" && transaction.spendingCategoryName !== this.selectedCategory) {
      return false;
    }
    if (!DateRange.includesDate(
      transaction.transactionDate,
      this.selectedStartDate,
      this.selectedEndDate,
    )) {
      return false;
    }
    return this.matchesSearchText(transaction);
  }

  /**
   * Search across the same human-facing fields visible in the transaction table.
   */
  matchesSearchText(transaction) {
    if (!this.normalizedSearchText) {
      return true;
    }
    return [
      transaction.transactionDate,
      accountLabel(transaction.accountType),
      transaction.merchantDisplayName,
      transaction.spendingCategoryName,
      transaction.transactionType,
      transaction.transactionEventType,
      transaction.transactionAmount,
    ].some((transactionValue) =>
      String(transactionValue).toLowerCase().includes(this.normalizedSearchText),
    );
  }
}
