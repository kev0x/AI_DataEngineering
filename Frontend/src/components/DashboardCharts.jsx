/**
 * Purpose: Renders dashboard chart components for cashflow, ranked bars, and account mix.
 * Runtime role: Provides lightweight chart visuals without introducing a charting library while the project is still a learning lab.
 * Dependencies: formatter helpers, EmptyPanelMessage, prepared chart rows, and chart-specific CSS classes.
 */

import {
  accountLabel,
  amountToneClass,
  chartWidth,
  formatCurrency,
  formatPercent,
} from "../domain/formatters.js";
import { EmptyPanelMessage } from "./EmptyPanelMessage.jsx";

export function AccountMixChart({ accountMixRows }) {
  const totalSpendingAmount = accountMixRows.reduce(
    (sumAmount, accountMixRow) => sumAmount + Number(accountMixRow.spendingAmount),
    0,
  );
  const checkingSpendingAmount = accountMixRows.find(
    (accountMixRow) => accountMixRow.accountType === "checking",
  )?.spendingAmount ?? 0;
  const checkingShare = totalSpendingAmount > 0
    ? Math.round((Number(checkingSpendingAmount) / totalSpendingAmount) * 100)
    : 0;

  if (accountMixRows.length === 0) {
    return <EmptyPanelMessage message="No account spending for this filter." />;
  }

  return (
    <div className="accountMixLayout">
      <div
        className="donutChart"
        style={{
          background: `conic-gradient(var(--accent-mint) 0 ${checkingShare}%, var(--accent-orange) ${checkingShare}% 100%)`,
        }}
        aria-label={`Checking ${checkingShare} percent`}
      >
        <span>{formatPercent(checkingShare)}</span>
      </div>
      <div className="accountLegend">
        {accountMixRows.map((accountMixRow) => (
          <div className="accountLegendRow" key={accountMixRow.accountType}>
            <span className={`legendDot ${accountMixRow.accountType}`} />
            <div>
              <strong>{accountLabel(accountMixRow.accountType)}</strong>
              <p>{formatCurrency(accountMixRow.spendingAmount)}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export function BarChartList({ rows, labelKey, valueKey, toneClass }) {
  const largestVisibleAmount = Math.max(
    1,
    ...rows.map((row) => Math.abs(Number(row[valueKey] ?? 0))),
  );

  if (rows.length === 0) {
    return <EmptyPanelMessage message="No rows for this filter." />;
  }

  return (
    <div className="barChartList">
      {rows.map((row) => (
        <div className="barChartRow" key={row[labelKey]}>
          <div className="barChartHeader">
            <span>{row[labelKey]}</span>
            <strong>{formatCurrency(row[valueKey])}</strong>
          </div>
          <div className="barTrack" aria-hidden="true">
            <span
              className={`barFill ${toneClass}`}
              style={{ "--bar-width": chartWidth(row[valueKey], largestVisibleAmount) }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

export function CashflowChart({ cashflowRows }) {
  const largestVisibleAmount = Math.max(
    1,
    ...cashflowRows.flatMap((cashflowRow) => [
      Math.abs(Number(cashflowRow.inflowAmount ?? 0)),
      Math.abs(Number(cashflowRow.outflowAmount ?? 0)),
      Math.abs(Number(cashflowRow.netCashflowAmount ?? 0)),
    ]),
  );

  if (cashflowRows.length === 0) {
    return <EmptyPanelMessage message="No cashflow for this filter." />;
  }

  return (
    <div className="cashflowChart">
      <div className="chartLegend" aria-hidden="true">
        <span className="legendIncome">Income</span>
        <span className="legendOutflow">Outflow</span>
        <span className="legendNet">Net</span>
      </div>
      {cashflowRows.map((cashflowRow) => (
        <div className="cashflowRow" key={cashflowRow.periodKey}>
          <span className="chartLabel">{cashflowRow.periodLabel}</span>
          <div className="cashflowBars">
            <span
              className="cashflowBar incomeBar"
              style={{ "--bar-width": chartWidth(cashflowRow.inflowAmount, largestVisibleAmount) }}
            />
            <span
              className="cashflowBar outflowBar"
              style={{ "--bar-width": chartWidth(cashflowRow.outflowAmount, largestVisibleAmount) }}
            />
            <span
              className={`cashflowBar netBar ${amountToneClass(cashflowRow.netCashflowAmount)}`}
              style={{ "--bar-width": chartWidth(cashflowRow.netCashflowAmount, largestVisibleAmount) }}
            />
          </div>
          <strong className={amountToneClass(cashflowRow.netCashflowAmount)}>
            {formatCurrency(cashflowRow.netCashflowAmount)}
          </strong>
        </div>
      ))}
    </div>
  );
}
