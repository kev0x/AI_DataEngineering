/**
 * Purpose: Provides dashboard-shaped sample data when the API or DuckDB warehouse is unavailable.
 * Runtime role: Lets the React UI keep rendering during frontend-only work, demos, or first setup before private CSVs are loaded.
 * Dependencies: The same data shape returned by GET /api/dashboard and GET /api/spending-categories.
 */

export const mockDashboardModel = {
  dataStatus: {
    mode: "mock",
    label: "Sample",
    message: "Showing sample data.",
  },
  warehouseHealth: {
    status: "mock",
    warehouseExists: false,
  },
  warehouseRowCounts: [],
  silverFactTransactionCount: 0,
  spendingCategories: [
    { spendingCategoryKey: 100, spendingCategoryName: "Dining", parentSpendingCategoryName: "Food" },
    { spendingCategoryKey: 200, spendingCategoryName: "Groceries", parentSpendingCategoryName: "Food" },
    { spendingCategoryKey: 300, spendingCategoryName: "BillsAndUtilities", parentSpendingCategoryName: "Household" },
    { spendingCategoryKey: 400, spendingCategoryName: "Transportation", parentSpendingCategoryName: "Transportation" },
    { spendingCategoryKey: 700, spendingCategoryName: "Shopping", parentSpendingCategoryName: "Lifestyle" },
    { spendingCategoryKey: 1600, spendingCategoryName: "DebtPayment", parentSpendingCategoryName: "Financial" },
    { spendingCategoryKey: 1700, spendingCategoryName: "Transfer", parentSpendingCategoryName: "Financial" },
  ],
  metricCards: [
    { label: "Spending", value: "$1,284.63", helper: "Purchases less refunds" },
    { label: "Income", value: "$3,250.00", helper: "Money in" },
    { label: "Net Cashflow", value: "$1,965.37", helper: "Income less outflow" },
    { label: "Uncategorized", value: "7", helper: "Needs rules" },
  ],
  monthlyCashflowRows: [
    { yearMonth: "2026-01", inflowAmount: 3250, outflowAmount: 1284.63, netCashflowAmount: 1965.37 },
    { yearMonth: "2026-02", inflowAmount: 3250, outflowAmount: 1412.22, netCashflowAmount: 1837.78 },
    { yearMonth: "2026-03", inflowAmount: 3250, outflowAmount: 1198.44, netCashflowAmount: 2051.56 },
  ],
  categorySpendingRows: [
    { spendingCategoryName: "Groceries", netSpendingAmount: 372.18, purchaseTransactionCount: 8 },
    { spendingCategoryName: "Food & drink", netSpendingAmount: 246.54, purchaseTransactionCount: 12 },
    { spendingCategoryName: "Shopping", netSpendingAmount: 198.77, purchaseTransactionCount: 5 },
  ],
  topMerchantRows: [
    { merchantDisplayName: "Example Market", totalSpendingAmount: 214.5, purchaseTransactionCount: 4 },
    { merchantDisplayName: "City Tacos", totalSpendingAmount: 86.2, purchaseTransactionCount: 3 },
    { merchantDisplayName: "Transit Pass", totalSpendingAmount: 72, purchaseTransactionCount: 2 },
  ],
  transactionRows: [
    {
      transactionKey: 1,
      transactionDate: "2026-01-15",
      postedDate: "2026-01-16",
      yearMonth: "2026-01",
      monthStartDate: "2026-01-01",
      accountType: "creditCard",
      merchantDisplayName: "Example Market",
      parentSpendingCategoryName: "Needs",
      spendingCategoryName: "Groceries",
      transactionType: "Sale",
      transactionEventType: "purchase",
      transactionAmount: -42.1,
    },
    {
      transactionKey: 2,
      transactionDate: "2026-01-16",
      postedDate: "2026-01-16",
      yearMonth: "2026-01",
      monthStartDate: "2026-01-01",
      accountType: "checking",
      merchantDisplayName: "Payroll",
      parentSpendingCategoryName: "Income",
      spendingCategoryName: "Income",
      transactionType: "Deposit",
      transactionEventType: "income",
      transactionAmount: 900,
    },
  ],
};
