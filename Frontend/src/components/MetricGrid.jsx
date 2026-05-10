/**
 * Purpose: Renders the primary KPI cards at the top of the dashboard.
 * Runtime role: Displays high-level totals prepared by TransactionAnalytics without owning calculation logic.
 * Dependencies: metric card view models and CSS metric-card classes.
 */

import { metricToneClass } from "../domain/formatters.js";

export function MetricGrid({ metricCards }) {
  return (
    <section className="metricGrid" aria-label="Summary metrics">
      {metricCards.map((metricCard) => (
        <article className={`metricCard ${metricToneClass(metricCard.label)}`} key={metricCard.label}>
          <span className="metricAccent" aria-hidden="true" />
          <p>{metricCard.label}</p>
          <strong>{metricCard.value}</strong>
          <span>{metricCard.helper}</span>
        </article>
      ))}
    </section>
  );
}
