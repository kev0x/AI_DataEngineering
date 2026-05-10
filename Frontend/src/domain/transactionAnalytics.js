/**
 * Purpose: Builds derived KPI, chart, category, merchant, and account-mix view models from filtered transactions.
 * Runtime role: Converts transaction ledger rows into the summarized structures that presentational components can render directly.
 * Dependencies: DateRange helpers, formatter helpers, and transaction/event-type conventions from the warehouse.
 */

import { DateRange } from "./dateRange.js";
import { formatCurrency, formatPercent, shortMonthLabel } from "./formatters.js";

export class TransactionAnalytics {
  /**
   * Build the complete analytics object consumed by App.jsx.
   * Input rows should already be filtered; this method does not know about UI controls.
   */
  static viewModel(transactionRows, selectedCashflowGranularity) {
    const monthlyCashflowRows = TransactionAnalytics.monthlyCashflowRows(
      transactionRows,
      selectedCashflowGranularity,
    );
    return {
      accountMixRows: TransactionAnalytics.accountMixRows(transactionRows),
      categoryRows: TransactionAnalytics.categoryRows(transactionRows),
      insightCards: TransactionAnalytics.insightCards(transactionRows),
      latestCashflowRow: monthlyCashflowRows.at(-1),
      merchantRows: TransactionAnalytics.merchantRows(transactionRows),
      metricCards: TransactionAnalytics.metricCards(transactionRows),
      monthlyCashflowRows,
      recentCashflowRows: monthlyCashflowRows.slice(-6),
    };
  }

  /**
   * Summarize purchase/refund activity by account type for the account mix panel.
   * Payments and transfers are excluded because they are movement of money, not spending.
   */
  static accountMixRows(transactionRows) {
    const purchaseAndRefundRows = transactionRows.filter((transaction) =>
      ["purchase", "refund"].includes(transaction.transactionEventType),
    );
    return Array.from(groupRows(purchaseAndRefundRows, (transaction) => transaction.accountType).entries())
      .map(([accountType, accountTransactions]) => {
        const purchaseAmount = sumTransactions(accountTransactions, (transaction) =>
          transaction.transactionEventType === "purchase" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        const refundAmount = sumTransactions(accountTransactions, (transaction) =>
          transaction.transactionEventType === "refund" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        return {
          accountType,
          spendingAmount: purchaseAmount - refundAmount,
        };
      })
      .filter((accountMixRow) => accountMixRow.spendingAmount > 0)
      .sort((leftAccount, rightAccount) => rightAccount.spendingAmount - leftAccount.spendingAmount);
  }

  /**
   * Return category names available in the current ledger rows for the filter dropdown.
   */
  static categoryOptions(transactionRows) {
    return uniqueSortedValues(transactionRows.map((transaction) => transaction.spendingCategoryName));
  }

  /**
   * Summarize spending by category for the ranked category chart.
   * Spending is defined as purchases minus refunds, matching the Gold view convention.
   */
  static categoryRows(transactionRows) {
    const purchaseAndRefundRows = transactionRows.filter((transaction) =>
      ["purchase", "refund"].includes(transaction.transactionEventType),
    );
    return Array.from(groupRows(purchaseAndRefundRows, (transaction) => transaction.spendingCategoryName).entries())
      .map(([spendingCategoryName, categoryTransactions]) => {
        const purchaseAmount = sumTransactions(categoryTransactions, (transaction) =>
          transaction.transactionEventType === "purchase" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        const refundAmount = sumTransactions(categoryTransactions, (transaction) =>
          transaction.transactionEventType === "refund" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        return {
          spendingCategoryName,
          netSpendingAmount: purchaseAmount - refundAmount,
        };
      })
      .filter((categoryRow) => categoryRow.netSpendingAmount !== 0)
      .sort((leftCategory, rightCategory) => rightCategory.netSpendingAmount - leftCategory.netSpendingAmount)
      .slice(0, 8);
  }

  /**
   * Return the earliest and latest transaction dates available to the date picker.
   */
  static dateBounds(transactionRows) {
    return DateRange.boundsFromTransactions(transactionRows);
  }

  /**
   * Build compact context cards that explain the filtered slice beyond basic totals.
   */
  static insightCards(transactionRows) {
    const purchaseRows = transactionRows.filter((transaction) =>
      transaction.transactionEventType === "purchase",
    );
    const monthCount = new Set(transactionRows.map((transaction) => transaction.yearMonth).filter(Boolean)).size || 1;
    const purchaseAmount = sumTransactions(purchaseRows, (transaction) =>
      Math.abs(Number(transaction.transactionAmount)),
    );
    const averagePurchaseAmount = purchaseRows.length > 0 ? purchaseAmount / purchaseRows.length : 0;
    const monthlyPaceAmount = purchaseAmount / monthCount;
    const largestPurchase = purchaseRows.reduce((largestTransaction, transaction) => {
      if (!largestTransaction) {
        return transaction;
      }
      return Math.abs(Number(transaction.transactionAmount)) > Math.abs(Number(largestTransaction.transactionAmount))
        ? transaction
        : largestTransaction;
    }, null);
    const uncategorizedCount = transactionRows.filter((transaction) =>
      ["Uncategorized", "Unknown"].includes(transaction.spendingCategoryName),
    ).length;
    const categorizedRate = transactionRows.length > 0
      ? Math.round(((transactionRows.length - uncategorizedCount) / transactionRows.length) * 100)
      : 0;

    return [
      {
        label: "Avg Purchase",
        value: formatCurrency(averagePurchaseAmount),
        helper: `${purchaseRows.length} purchases`,
        toneClass: "insightMint",
      },
      {
        label: "Monthly Pace",
        value: formatCurrency(monthlyPaceAmount),
        helper: "Average spending",
        toneClass: "insightOrange",
      },
      {
        label: "Largest Purchase",
        value: formatCurrency(Math.abs(Number(largestPurchase?.transactionAmount ?? 0))),
        helper: largestPurchase?.merchantDisplayName ?? "No purchases",
        toneClass: "insightBlue",
      },
      {
        label: "Categorized",
        value: formatPercent(categorizedRate),
        helper: "Rules coverage",
        toneClass: "insightGreen",
      },
    ];
  }

  /**
   * Rank merchants by purchase amount for the top merchants chart.
   * Refunds are intentionally not included here because this chart answers "where was money spent?"
   */
  static merchantRows(transactionRows) {
    const purchaseRows = transactionRows.filter((transaction) => transaction.transactionEventType === "purchase");
    return Array.from(groupRows(purchaseRows, (transaction) => transaction.merchantDisplayName).entries())
      .map(([merchantDisplayName, merchantTransactions]) => ({
        merchantDisplayName,
        totalSpendingAmount: sumTransactions(merchantTransactions, (transaction) =>
          Math.abs(Number(transaction.transactionAmount)),
        ),
      }))
      .sort((leftMerchant, rightMerchant) => rightMerchant.totalSpendingAmount - leftMerchant.totalSpendingAmount)
      .slice(0, 8);
  }

  /**
   * Build the main KPI cards from filtered transactions.
   * These formulas mirror the warehouse definitions so the UI stays reconcilable.
   */
  static metricCards(transactionRows) {
    const incomeAmount = sumTransactions(transactionRows, (transaction) =>
      transaction.transactionEventType === "income" ? Number(transaction.transactionAmount) : 0,
    );
    const purchaseAmount = sumTransactions(transactionRows, (transaction) =>
      transaction.transactionEventType === "purchase" ? Math.abs(Number(transaction.transactionAmount)) : 0,
    );
    const refundAmount = sumTransactions(transactionRows, (transaction) =>
      transaction.transactionEventType === "refund" ? Math.abs(Number(transaction.transactionAmount)) : 0,
    );
    const feeAmount = sumTransactions(transactionRows, (transaction) =>
      transaction.transactionEventType === "fee" ? Math.abs(Number(transaction.transactionAmount)) : 0,
    );
    const netSpendingAmount = purchaseAmount - refundAmount;
    const netCashflowAmount = incomeAmount - (netSpendingAmount + feeAmount);
    const uncategorizedCount = transactionRows.filter((transaction) =>
      ["Uncategorized", "Unknown"].includes(transaction.spendingCategoryName),
    ).length;

    return [
      { label: "Spending", value: formatCurrency(netSpendingAmount), helper: "Purchases less refunds" },
      { label: "Income", value: formatCurrency(incomeAmount), helper: "Money in" },
      { label: "Net Cashflow", value: formatCurrency(netCashflowAmount), helper: "Income less outflow" },
      { label: "Uncategorized", value: String(uncategorizedCount), helper: "Needs rules" },
    ];
  }

  /**
   * Aggregate income/outflow/net cashflow by month or year for the trend chart.
   */
  static monthlyCashflowRows(transactionRows, selectedCashflowGranularity) {
    const cashflowRowsByPeriod = groupRows(
      transactionRows,
      (transaction) => periodKeyFromTransaction(transaction, selectedCashflowGranularity),
    );
    return Array.from(cashflowRowsByPeriod.entries())
      .map(([periodKey, periodTransactions]) => {
        const incomeAmount = sumTransactions(periodTransactions, (transaction) =>
          transaction.transactionEventType === "income" ? Number(transaction.transactionAmount) : 0,
        );
        const purchaseAmount = sumTransactions(periodTransactions, (transaction) =>
          transaction.transactionEventType === "purchase" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        const refundAmount = sumTransactions(periodTransactions, (transaction) =>
          transaction.transactionEventType === "refund" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        const feeAmount = sumTransactions(periodTransactions, (transaction) =>
          transaction.transactionEventType === "fee" ? Math.abs(Number(transaction.transactionAmount)) : 0,
        );
        const outflowAmount = purchaseAmount - refundAmount + feeAmount;
        return {
          periodKey,
          periodLabel: periodLabel(periodKey, selectedCashflowGranularity),
          inflowAmount: incomeAmount,
          outflowAmount,
          netCashflowAmount: incomeAmount - outflowAmount,
        };
      })
      .sort((leftPeriod, rightPeriod) => leftPeriod.periodKey.localeCompare(rightPeriod.periodKey));
  }
}

function groupRows(rows, keySelector) {
  // Shared grouping helper for small dashboard collections.
  // It returns a Map so callers can preserve keys and transform each group explicitly.
  return rows.reduce((groupedRows, row) => {
    const groupKey = keySelector(row) ?? "Unknown";
    if (!groupedRows.has(groupKey)) {
      groupedRows.set(groupKey, []);
    }
    groupedRows.get(groupKey).push(row);
    return groupedRows;
  }, new Map());
}

function periodKeyFromTransaction(transaction, selectedCashflowGranularity) {
  // Yearly mode derives the year from the transaction date; monthly mode reuses yearMonth
  // from Gold.vw_TransactionLedger so UI grouping matches warehouse grouping.
  if (selectedCashflowGranularity === "year") {
    const transactionDate = DateRange.parseLocalDate(transaction.transactionDate);
    return transactionDate ? String(transactionDate.getFullYear()) : "Unknown";
  }
  return transaction.yearMonth ?? String(transaction.transactionDate).slice(0, 7);
}

function periodLabel(periodKey, selectedCashflowGranularity) {
  if (selectedCashflowGranularity === "year") {
    return periodKey;
  }
  return shortMonthLabel(periodKey);
}

function sumTransactions(transactionRows, amountSelector) {
  // The selector makes each metric state its event-type rules at the call site.
  return transactionRows.reduce(
    (sumAmount, transaction) => sumAmount + amountSelector(transaction),
    0,
  );
}

function uniqueSortedValues(values) {
  return Array.from(new Set(values.filter(Boolean))).sort((leftValue, rightValue) =>
    leftValue.localeCompare(rightValue),
  );
}
