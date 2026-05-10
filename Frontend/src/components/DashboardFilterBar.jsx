/**
 * Purpose: Renders account, date, category, search, and granularity controls.
 * Runtime role: Collects user filter choices and reports them upward so App.jsx can recalculate analytics from transaction rows.
 * Dependencies: dashboard option lists, date input bounds, parent change handlers, and CSS form classes.
 */

import { accountOptions, cashflowGranularityOptions } from "../domain/dashboardOptions.js";

export function DashboardFilterBar({
  categoryOptions,
  dateInputs,
  filters,
  onChangeFilter,
}) {
  return (
    <section className="filterBar" aria-label="Dashboard filters">
      <label>
        Account
        <select
          value={filters.selectedAccount}
          onChange={(event) => onChangeFilter("selectedAccount", event.target.value)}
        >
          {accountOptions.map((accountOption) => (
            <option value={accountOption.value} key={accountOption.value}>
              {accountOption.label}
            </option>
          ))}
        </select>
      </label>
      <label>
        From
        <input
          type="date"
          min={dateInputs.earliestAvailableDate}
          max={dateInputs.latestAvailableDate}
          value={dateInputs.effectiveStartDate}
          onChange={(event) => onChangeFilter("selectedStartDate", event.target.value)}
        />
      </label>
      <label>
        To
        <input
          type="date"
          min={dateInputs.earliestAvailableDate}
          max={dateInputs.latestAvailableDate}
          value={dateInputs.effectiveEndDate}
          onChange={(event) => onChangeFilter("selectedEndDate", event.target.value)}
        />
      </label>
      <label>
        Group by
        <select
          value={filters.selectedCashflowGranularity}
          onChange={(event) => onChangeFilter("selectedCashflowGranularity", event.target.value)}
        >
          {cashflowGranularityOptions.map((granularityOption) => (
            <option value={granularityOption.value} key={granularityOption.value}>
              {granularityOption.label}
            </option>
          ))}
        </select>
      </label>
      <label>
        Category
        <select
          value={filters.selectedCategory}
          onChange={(event) => onChangeFilter("selectedCategory", event.target.value)}
        >
          <option value="all">All categories</option>
          {categoryOptions.map((categoryName) => (
            <option value={categoryName} key={categoryName}>
              {categoryName}
            </option>
          ))}
        </select>
      </label>
      <label className="searchField">
        Search
        <input
          value={filters.transactionSearchText}
          onChange={(event) => onChangeFilter("transactionSearchText", event.target.value)}
          placeholder="Search transactions"
        />
      </label>
    </section>
  );
}
