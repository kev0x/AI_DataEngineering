/**
 * Purpose: Renders secondary insight cards under the main KPI cards.
 * Runtime role: Surfaces contextual observations such as top category, top merchant, or uncategorized risk from prepared analytics.
 * Dependencies: insight card view models and CSS insight-card classes.
 */

export function InsightGrid({ insightCards }) {
  return (
    <section className="insightGrid" aria-label="Quick insights">
      {insightCards.map((insightCard) => (
        <article className={`insightCard ${insightCard.toneClass}`} key={insightCard.label}>
          <span>{insightCard.label}</span>
          <strong>{insightCard.value}</strong>
          <p>{insightCard.helper}</p>
        </article>
      ))}
    </section>
  );
}
