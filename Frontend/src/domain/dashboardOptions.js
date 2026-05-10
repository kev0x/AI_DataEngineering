/**
 * Purpose: Stores default dashboard filter values and option lists.
 * Runtime role: Keeps UI defaults in one place so App.jsx and filter components do not duplicate magic strings.
 * Dependencies: Filter names expected by TransactionFilter and DashboardFilterBar.
 */

export const accountOptions = [
  { value: "all", label: "All accounts" },
  { value: "checking", label: "Checking" },
  { value: "creditCard", label: "Credit card" },
];

export const cashflowGranularityOptions = [
  { value: "month", label: "Month" },
  { value: "year", label: "Year" },
];

export const defaultDashboardFilters = {
  selectedAccount: "all",
  selectedStartDate: "",
  selectedEndDate: "",
  selectedCashflowGranularity: "month",
  selectedCategory: "all",
  transactionSearchText: "",
};
