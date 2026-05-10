/**
 * Purpose: Loads dashboard data and chooses between live warehouse data and mock fallback data.
 * Runtime role: Keeps API orchestration out of App.jsx by calling health, row-count, dashboard, and category endpoints together.
 * Dependencies: Frontend/src/api/warehouseApi.js and Frontend/src/mockData/dashboardMockData.js.
 */

import {
  fetchDashboard,
  fetchSpendingCategories,
  fetchWarehouseHealth,
  fetchWarehouseRowCounts,
} from "../api/warehouseApi.js";
import { mockDashboardModel } from "../mockData/dashboardMockData.js";

class DashboardController {
  /**
   * Load the dashboard model used by App.jsx.
   * This is the frontend boundary between "talk to the API" and "render the page":
   * components should not need to know health endpoints, row-count endpoints, or fallback behavior.
   */
  async loadDashboardModel() {
    try {
      const [
        warehouseHealth,
        warehouseRowCountsPayload,
        dashboardPayload,
        spendingCategoriesPayload,
      ] = await Promise.all([
        fetchWarehouseHealth(),
        fetchWarehouseRowCounts(),
        fetchDashboard(),
        fetchSpendingCategories(),
      ]);

      if (!warehouseHealth.warehouseExists || !dashboardPayload.warehouseExists) {
        // First-run friendliness: the frontend remains usable before private CSVs are loaded.
        return this.mockDashboardModel("Data file is not available yet.");
      }

      const warehouseRowCounts = warehouseRowCountsPayload.objects ?? [];
      const dashboard = dashboardPayload.dashboard ?? {};

      return {
        ...mockDashboardModel,
        dataStatus: {
          mode: "live",
          label: "Current",
          message: "Current data loaded.",
        },
        warehouseHealth,
        warehouseRowCounts,
        silverFactTransactionCount: this.factTransactionCount(warehouseRowCounts),
        metricCards: dashboard.summaryMetrics ?? mockDashboardModel.metricCards,
        monthlyCashflowRows: dashboard.monthlyCashflow ?? [],
        categorySpendingRows: dashboard.categorySpending ?? [],
        topMerchantRows: dashboard.topMerchants ?? [],
        uncategorizedSummaryRows: dashboard.uncategorizedSummary ?? [],
        transactionRows: dashboard.transactionRows ?? mockDashboardModel.transactionRows,
        spendingCategories: spendingCategoriesPayload.spendingCategories ?? mockDashboardModel.spendingCategories,
      };
    } catch (error) {
      // API failures should not blank the UI. The message stays in dataStatus so the
      // dashboard can show a subtle state without exposing technical implementation text.
      return this.mockDashboardModel(error.message);
    }
  }

  /**
   * Return fallback data with the same shape as the live model.
   * Components can stay simple because they never branch on "mock versus live".
   */
  mockDashboardModel(reason) {
    return {
      ...mockDashboardModel,
      dataStatus: {
        ...mockDashboardModel.dataStatus,
        message: `${mockDashboardModel.dataStatus.message} ${reason}`,
      },
    };
  }

  /**
   * Extract the Silver fact count from generic warehouse row-count metadata.
   */
  factTransactionCount(warehouseRowCounts) {
    const factTransaction = warehouseRowCounts.find(
      (warehouseObject) =>
        warehouseObject.schemaName === "Silver" &&
        warehouseObject.objectName === "factTransaction",
    );
    return factTransaction?.rowCount ?? 0;
  }
}

export const dashboardController = new DashboardController();
