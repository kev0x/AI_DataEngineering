/**
 * Purpose: Composes the finance dashboard page and coordinates dashboard state.
 * Runtime role: Owns top-level React state, loads the dashboard model, applies filters, approves category rules, and passes prepared data into focused child components.
 * Dependencies: React hooks, warehouse API functions, dashboardController, domain service classes, dashboard components, and mock fallback data.
 */

import { useCallback, useEffect, useMemo, useState } from "react";
import { approveCategoryRule } from "./api/warehouseApi.js";
import { AccountMixChart, BarChartList, CashflowChart } from "./components/DashboardCharts.jsx";
import { CategoryRuleReview } from "./components/CategoryRuleReview.jsx";
import { DashboardFilterBar } from "./components/DashboardFilterBar.jsx";
import { DashboardHeader } from "./components/DashboardHeader.jsx";
import { InsightGrid } from "./components/InsightGrid.jsx";
import { MetricGrid } from "./components/MetricGrid.jsx";
import {
  defaultTransactionColumnVisibility,
  TransactionTable,
} from "./components/TransactionTable.jsx";
import { dashboardController } from "./controllers/dashboardController.js";
import { CategoryRuleSuggestionService } from "./domain/categoryRuleSuggestionService.js";
import { CsvExporter } from "./domain/csvExporter.js";
import { defaultDashboardFilters } from "./domain/dashboardOptions.js";
import { DateRange } from "./domain/dateRange.js";
import {
  cashflowGranularityLabel,
  formatCurrency,
  periodCountLabel,
} from "./domain/formatters.js";
import { TransactionAnalytics } from "./domain/transactionAnalytics.js";
import { TransactionFilter } from "./domain/transactionFilter.js";
import { mockDashboardModel } from "./mockData/dashboardMockData.js";

function App() {
  // State in this component is limited to page-level coordination:
  // data loading, active filters, visible table columns, and the category-rule approval flow.
  // Calculations and JSX details live in domain services and child components.
  const [approvingRuleKey, setApprovingRuleKey] = useState("");
  const [categoryRuleStatusMessage, setCategoryRuleStatusMessage] = useState("");
  const [dashboardFilters, setDashboardFilters] = useState(defaultDashboardFilters);
  const [dashboardModel, setDashboardModel] = useState(mockDashboardModel);
  const [isColumnPanelVisible, setIsColumnPanelVisible] = useState(false);
  const [isFilterBarVisible, setIsFilterBarVisible] = useState(true);
  const [isLoadingDashboard, setIsLoadingDashboard] = useState(true);
  const [selectedSuggestedCategories, setSelectedSuggestedCategories] = useState({});
  const [visibleColumnKeys, setVisibleColumnKeys] = useState(
    defaultTransactionColumnVisibility(),
  );

  const loadDashboard = useCallback(() => {
    // The controller decides whether live API data or mock fallback data should be used.
    // App.jsx only cares that it receives the dashboard-shaped model.
    setIsLoadingDashboard(true);
    dashboardController
      .loadDashboardModel()
      .then(setDashboardModel)
      .finally(() => setIsLoadingDashboard(false));
  }, []);

  useEffect(() => {
    loadDashboard();
  }, [loadDashboard]);

  const transactionDateBounds = useMemo(
    () => TransactionAnalytics.dateBounds(dashboardModel.transactionRows),
    [dashboardModel.transactionRows],
  );
  // Empty date filters mean "use the full range available in the current data."
  // This matters because source data can be historical, so the default range should be
  // based on transaction dates from DuckDB, not today's calendar date.
  const earliestAvailableDate = DateRange.dateInputValue(transactionDateBounds?.earliestDate);
  const latestAvailableDate = DateRange.dateInputValue(transactionDateBounds?.latestDate);
  const effectiveStartDate = dashboardFilters.selectedStartDate || earliestAvailableDate;
  const effectiveEndDate = dashboardFilters.selectedEndDate || latestAvailableDate;
  const dateInputs = {
    earliestAvailableDate,
    effectiveEndDate,
    effectiveStartDate,
    latestAvailableDate,
  };

  const categoryOptions = useMemo(
    () => TransactionAnalytics.categoryOptions(dashboardModel.transactionRows),
    [dashboardModel.transactionRows],
  );

  const filteredTransactionRows = useMemo(() =>
    // Filtering happens client-side over Gold.vw_TransactionLedger rows. That keeps the
    // UI responsive while the backend remains a small fixed set of safe endpoints.
    TransactionFilter.apply(dashboardModel.transactionRows, {
      ...dashboardFilters,
      selectedEndDate: effectiveEndDate,
      selectedStartDate: effectiveStartDate,
    }), [
    dashboardFilters,
    dashboardModel.transactionRows,
    effectiveEndDate,
    effectiveStartDate,
  ]);

  const dashboardViewModel = useMemo(() =>
    // TransactionAnalytics turns filtered row-level data into the chart/KPI models that
    // the presentational components can render without knowing business rules.
    TransactionAnalytics.viewModel(
      filteredTransactionRows,
      dashboardFilters.selectedCashflowGranularity,
    ), [
    dashboardFilters.selectedCashflowGranularity,
    filteredTransactionRows,
  ]);

  const categoryRuleSuggestionRows = useMemo(() =>
    // Suggestions are intentionally generated from the currently visible rows, so changing
    // filters also changes which rule candidates the user is reviewing.
    CategoryRuleSuggestionService.suggestionsFromTransactions(
      filteredTransactionRows,
      dashboardModel.spendingCategories,
    ), [
    dashboardModel.spendingCategories,
    filteredTransactionRows,
  ]);

  function approveSuggestedCategoryRule(categoryRuleSuggestion) {
    // Approval writes a durable manual rule to Silver.mapCategoryRule through FastAPI.
    // The API also updates matching Uncategorized/Unknown facts immediately, then the
    // dashboard reloads so the corrected category appears everywhere.
    const spendingCategoryName = selectedSuggestedCategories[categoryRuleSuggestion.suggestionKey]
      ?? categoryRuleSuggestion.suggestedCategoryName;
    setApprovingRuleKey(categoryRuleSuggestion.suggestionKey);
    setCategoryRuleStatusMessage("");

    approveCategoryRule({
      sourceAccountType: categoryRuleSuggestion.sourceAccountType,
      transactionType: categoryRuleSuggestion.transactionType,
      transactionEventType: categoryRuleSuggestion.transactionEventType,
      descriptionMatchType: categoryRuleSuggestion.descriptionMatchType,
      descriptionMatchText: categoryRuleSuggestion.descriptionMatchText,
      spendingCategoryName,
    })
      .then((approvalResponse) => {
        setCategoryRuleStatusMessage(
          `Rule approved. Updated ${approvalResponse.updatedTransactionCount} transactions.`,
        );
        loadDashboard();
      })
      .catch((error) => {
        setCategoryRuleStatusMessage(`Could not approve rule. ${error.message}`);
      })
      .finally(() => setApprovingRuleKey(""));
  }

  function changeDashboardFilter(filterName, filterValue) {
    // All filter controls report changes through this single method so new filters can be
    // added without threading separate handlers through the component tree.
    setDashboardFilters((currentFilters) => ({
      ...currentFilters,
      [filterName]: filterValue,
    }));
  }

  function exportFilteredTransactions(visibleTableColumns) {
    // Export uses the same filtered rows and visible columns the user is looking at.
    // That avoids the confusing "exported CSV does not match the table" problem.
    CsvExporter.exportTransactions(filteredTransactionRows, visibleTableColumns);
  }

  function selectSuggestedCategory(suggestionKey, spendingCategoryName) {
    setSelectedSuggestedCategories((currentSelections) => ({
      ...currentSelections,
      [suggestionKey]: spendingCategoryName,
    }));
  }

  function toggleColumn(columnKey, isVisible) {
    setVisibleColumnKeys((currentColumnKeys) => ({
      ...currentColumnKeys,
      [columnKey]: isVisible,
    }));
  }

  return (
    <main className="applicationShell">
      <DashboardHeader
        isLoadingDashboard={isLoadingDashboard}
        onRefreshDashboard={loadDashboard}
      />

      {isFilterBarVisible && (
        <DashboardFilterBar
          categoryOptions={categoryOptions}
          dateInputs={dateInputs}
          filters={dashboardFilters}
          onChangeFilter={changeDashboardFilter}
        />
      )}

      <MetricGrid metricCards={dashboardViewModel.metricCards} />
      <InsightGrid insightCards={dashboardViewModel.insightCards} />

      <section className="mainGrid">
        <article className="panel trendPanel">
          <div className="panelHeader">
            <h2>Cashflow by {cashflowGranularityLabel(dashboardFilters.selectedCashflowGranularity)}</h2>
            <span>
              {periodCountLabel(
                dashboardViewModel.recentCashflowRows.length,
                dashboardFilters.selectedCashflowGranularity,
              )}
            </span>
          </div>
          <CashflowChart cashflowRows={dashboardViewModel.recentCashflowRows} />
          <p className="panelNote">
            Latest net cashflow: {formatCurrency(dashboardViewModel.latestCashflowRow?.netCashflowAmount ?? 0)}
          </p>
        </article>
      </section>

      <section className="secondaryGrid">
        <article className="panel">
          <div className="panelHeader">
            <h2>Spending By Category</h2>
          </div>
          <BarChartList
            rows={dashboardViewModel.categoryRows}
            labelKey="spendingCategoryName"
            valueKey="netSpendingAmount"
            toneClass="orangeBar"
          />
        </article>
        <article className="panel">
          <div className="panelHeader">
            <h2>Top Merchants</h2>
          </div>
          <BarChartList
            rows={dashboardViewModel.merchantRows}
            labelKey="merchantDisplayName"
            valueKey="totalSpendingAmount"
            toneClass="blueBar"
          />
        </article>
      </section>

      <section className="tertiaryGrid">
        <article className="panel accountPanel">
          <div className="panelHeader">
            <h2>Account Mix</h2>
            <span>{dashboardViewModel.accountMixRows.length} accounts</span>
          </div>
          <AccountMixChart accountMixRows={dashboardViewModel.accountMixRows} />
        </article>
      </section>

      <section className="panel categoryReviewPanel">
        <div className="panelHeader">
          <h2>Suggested Rules</h2>
          <span>{categoryRuleSuggestionRows.length} suggestions</span>
        </div>
        <CategoryRuleReview
          approvingRuleKey={approvingRuleKey}
          categoryRuleStatusMessage={categoryRuleStatusMessage}
          categoryRuleSuggestionRows={categoryRuleSuggestionRows}
          onApproveRule={approveSuggestedCategoryRule}
          onSelectCategory={selectSuggestedCategory}
          selectedSuggestedCategories={selectedSuggestedCategories}
          spendingCategories={dashboardModel.spendingCategories}
        />
      </section>

      <TransactionTable
        filteredTransactionRows={filteredTransactionRows}
        isColumnPanelVisible={isColumnPanelVisible}
        onExportTransactions={exportFilteredTransactions}
        onToggleColumn={toggleColumn}
        onToggleColumnPanel={() => setIsColumnPanelVisible((isVisible) => !isVisible)}
        onToggleFilterBar={() => setIsFilterBarVisible((isVisible) => !isVisible)}
        visibleColumnKeys={visibleColumnKeys}
      />
    </main>
  );
}

export default App;
