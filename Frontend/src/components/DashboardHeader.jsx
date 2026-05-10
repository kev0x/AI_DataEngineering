/**
 * Purpose: Renders the dashboard title area and refresh action.
 * Runtime role: Gives users a clear top-level control for reloading live warehouse data without exposing backend implementation details.
 * Dependencies: Parent callbacks from App.jsx and CSS classes in Frontend/src/styles.css.
 */

export function DashboardHeader({ isLoadingDashboard, onRefreshDashboard }) {
  return (
    <header className="topBar">
      <div className="brandLockup">
        <span className="trellisMark" aria-hidden="true">
          <span />
        </span>
        <div>
          <p className="eyebrow">Overview</p>
          <h1>Spending Dashboard</h1>
          <p className="heroCopy">Spending, income, cashflow, and category trends.</p>
        </div>
      </div>
      <div className="topBarActions">
        <button type="button" onClick={onRefreshDashboard}>
          {isLoadingDashboard ? "Refreshing" : "Refresh"}
        </button>
      </div>
    </header>
  );
}
