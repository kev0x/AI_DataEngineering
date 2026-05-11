# UI Wireframe And Component Map

This document explains the current React dashboard layout and how each frontend component
fits into the page. The goal is to make the UI easy to navigate before opening the code.

## Screen Wireframe

```text
+--------------------------------------------------------------------------------+
| DashboardHeader                                                                |
| - Spending Dashboard title                                                     |
| - refresh action                                                               |
+--------------------------------------------------------------------------------+

+--------------------------------------------------------------------------------+
| DashboardFilterBar                                                             |
| Account | From date | To date | Group by | Category | Search                   |
+--------------------------------------------------------------------------------+

+-------------------+-------------------+-------------------+--------------------+
| MetricGrid        | MetricGrid        | MetricGrid        | MetricGrid         |
| Spending          | Income            | Net Cashflow      | Uncategorized      |
+-------------------+-------------------+-------------------+--------------------+

+-------------------+-------------------+-------------------+--------------------+
| InsightGrid       | InsightGrid       | InsightGrid       | InsightGrid        |
| Avg purchase      | Monthly pace      | Largest purchase  | Categorized rate   |
+-------------------+-------------------+-------------------+--------------------+

+--------------------------------------------------------------------------------+
| CashflowChart                                                                  |
| - income, outflow, and net cashflow by selected month/year granularity          |
+--------------------------------------------------------------------------------+

+--------------------------------------+-----------------------------------------+
| BarChartList                         | BarChartList                            |
| Spending By Category                 | Top Merchants                           |
+--------------------------------------+-----------------------------------------+

+--------------------------------------------------------------------------------+
| AccountMixChart                                                                 |
| - account spending split with legend                                             |
+--------------------------------------------------------------------------------+

+--------------------------------------------------------------------------------+
| CategoryRuleReview                                                              |
| - suggested rules for uncategorized rows                                         |
| - category selector                                                              |
| - approve button writes manual rule through FastAPI                              |
+--------------------------------------------------------------------------------+

+--------------------------------------------------------------------------------+
| TransactionTable                                                                |
| Filter button | Columns button | Export button                                  |
| Date | Account | Merchant | Category | Type | Amount                            |
+--------------------------------------------------------------------------------+
```

## Component Responsibilities

| Component | File | Responsibility | Receives | Sends Up |
| --- | --- | --- | --- | --- |
| `App` | `Frontend/src/App.jsx` | Owns page state, loads dashboard data, applies filters, coordinates rule approval, and composes the page. | Dashboard model, filter defaults, domain service results. | Filter changes, rule approvals, table column state. |
| `DashboardHeader` | `Frontend/src/components/DashboardHeader.jsx` | Renders dashboard title, short description, and refresh button. | Loading state and refresh callback. | Refresh request. |
| `DashboardFilterBar` | `Frontend/src/components/DashboardFilterBar.jsx` | Renders account, date, grouping, category, and search filters. | Current filter values, category options, date bounds. | Filter name/value changes. |
| `MetricGrid` | `Frontend/src/components/MetricGrid.jsx` | Renders the main KPI cards. | Prepared metric card view models. | None. |
| `InsightGrid` | `Frontend/src/components/InsightGrid.jsx` | Renders secondary insight cards. | Prepared insight card view models. | None. |
| `CashflowChart` | `Frontend/src/components/DashboardCharts.jsx` | Renders income, outflow, and net cashflow bars by month or year. | Prepared cashflow rows. | None. |
| `BarChartList` | `Frontend/src/components/DashboardCharts.jsx` | Renders ranked horizontal bars for category and merchant panels. | Prepared rows, label key, value key, color class. | None. |
| `AccountMixChart` | `Frontend/src/components/DashboardCharts.jsx` | Renders account mix donut and account legend. | Prepared account mix rows. | None. |
| `CategoryRuleReview` | `Frontend/src/components/CategoryRuleReview.jsx` | Renders suggested category rules and approval controls. | Suggested rules, spending categories, selected category values, approval state. | Category selection and approve request. |
| `TransactionTable` | `Frontend/src/components/TransactionTable.jsx` | Renders filtered ledger rows, column visibility controls, filter toggle, and CSV export action. | Filtered transaction rows and visible column map. | Toggle filter bar, toggle columns, export request. |
| `EmptyPanelMessage` | `Frontend/src/components/EmptyPanelMessage.jsx` | Renders consistent empty states for panels with no rows. | Message text. | None. |

## Domain And Controller Responsibilities

| Module | Responsibility |
| --- | --- |
| `Frontend/src/controllers/dashboardController.js` | Calls FastAPI endpoints, returns live dashboard data, and falls back to mock data if the API or warehouse is unavailable. |
| `Frontend/src/api/warehouseApi.js` | Centralizes browser `fetch` calls to FastAPI. |
| `Frontend/src/domain/transactionFilter.js` | Applies account, category, date, and search filters to transaction ledger rows. |
| `Frontend/src/domain/transactionAnalytics.js` | Builds KPI, insight, chart, category, merchant, account mix, and date-bound view models from filtered rows. |
| `Frontend/src/domain/categoryRuleSuggestionService.js` | Groups uncategorized transaction patterns into suggested rules. |
| `Frontend/src/domain/csvExporter.js` | Exports the visible filtered transaction table to CSV in the browser. |
| `Frontend/src/domain/dateRange.js` | Normalizes date parsing, date input values, and date range checks. |
| `Frontend/src/domain/formatters.js` | Formats money, percentages, account labels, month labels, chart widths, and amount tone classes. |
| `Frontend/src/domain/dashboardOptions.js` | Stores dashboard default filters and option lists. |
| `Frontend/src/mockData/dashboardMockData.js` | Provides dashboard-shaped fallback data for frontend-only work or first setup. |

## Data Flow

```text
FastAPI /api/dashboard
    -> dashboardController.loadDashboardModel()
    -> App dashboardModel state
    -> TransactionFilter.apply()
    -> TransactionAnalytics.viewModel()
    -> MetricGrid / InsightGrid / DashboardCharts / TransactionTable

FastAPI /api/spending-categories
    -> dashboardController.loadDashboardModel()
    -> App dashboardModel.spendingCategories
    -> CategoryRuleReview category dropdowns

CategoryRuleReview approve button
    -> App.approveSuggestedCategoryRule()
    -> warehouseApi.approveCategoryRule()
    -> FastAPI POST /api/category-rules
    -> Silver.mapCategoryRule and Silver.factTransaction update
    -> App reloads dashboard data
```

## Current UI Behavior

- All metrics and charts are recalculated from the currently filtered transaction rows.
- Empty date filters use the earliest and latest transaction dates from the warehouse, not
  the current calendar date.
- Suggested category rules are generated only from visible Uncategorized/Unknown purchase
  and refund rows.
- A suggested rule disappears only when the API reports that matching transactions were
  actually updated.
- Refresh reloads the dashboard model from FastAPI.
- Export downloads the currently filtered rows and currently visible table columns.

## Privacy Boundary

The frontend reads from `Gold.vw_TransactionLedger` through FastAPI. The ledger intentionally
does not expose raw Chase descriptions, account last four, memo, balance, check/slip number,
or source file names.

