/**
 * Purpose: Provides display formatting helpers for amounts, percentages, months, labels, and chart sizing.
 * Runtime role: Keeps presentational formatting consistent across metric cards, charts, insight cards, and tables.
 * Dependencies: Browser Intl formatting APIs and dashboard value conventions.
 */

export function accountLabel(accountType) {
  if (accountType === "creditCard") {
    return "Credit card";
  }
  if (accountType === "checking") {
    return "Checking";
  }
  return accountType ?? "Unknown";
}

export function amountToneClass(value) {
  const numericValue = Number(value ?? 0);
  if (numericValue > 0) {
    return "amountPositive";
  }
  if (numericValue < 0) {
    return "amountNegative";
  }
  return "amountNeutral";
}

export function cashflowGranularityLabel(selectedCashflowGranularity) {
  return selectedCashflowGranularity === "year" ? "Year" : "Month";
}

export function chartWidth(value, largestVisibleAmount) {
  const absoluteValue = Math.abs(Number(value ?? 0));
  return `${Math.max(3, Math.round((absoluteValue / largestVisibleAmount) * 100))}%`;
}

export function formatCurrency(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(Number(value ?? 0));
}

export function formatPercent(value) {
  return `${Number(value ?? 0).toFixed(0)}%`;
}

export function metricToneClass(metricLabel) {
  const normalizedMetricLabel = metricLabel.replace(/\s+/g, "").toLowerCase();
  return `metricCard-${normalizedMetricLabel}`;
}

export function periodCountLabel(periodCount, selectedCashflowGranularity) {
  const noun = selectedCashflowGranularity === "year" ? "year" : "month";
  return `${periodCount} ${periodCount === 1 ? noun : `${noun}s`}`;
}

export function shortMonthLabel(yearMonth) {
  const [year, month] = String(yearMonth).split("-").map(Number);
  if (!year || !month) {
    return yearMonth;
  }
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    year: "2-digit",
  }).format(new Date(year, month - 1, 1));
}
