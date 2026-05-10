/**
 * Purpose: Renders suggested category-rule candidates for user review.
 * Runtime role: Lets the user choose a category and approve a rule that will be written back to Silver.mapCategoryRule through the API.
 * Dependencies: category rule suggestion rows, spending category selections, approval callbacks, and form/table CSS classes.
 */

import { formatCurrency } from "../domain/formatters.js";
import { EmptyPanelMessage } from "./EmptyPanelMessage.jsx";

export function CategoryRuleReview({
  approvingRuleKey,
  categoryRuleStatusMessage,
  categoryRuleSuggestionRows,
  onApproveRule,
  onSelectCategory,
  selectedSuggestedCategories,
  spendingCategories,
}) {
  if (categoryRuleSuggestionRows.length === 0) {
    return <EmptyPanelMessage message="No uncategorized transactions in the current view." />;
  }

  return (
    <div className="categoryReviewLayout">
      {categoryRuleStatusMessage && (
        <p className="categoryRuleStatus">{categoryRuleStatusMessage}</p>
      )}
      <div className="categoryRuleGrid">
        {categoryRuleSuggestionRows.slice(0, 6).map((categoryRuleSuggestion) => {
          const selectedCategoryName = selectedSuggestedCategories[categoryRuleSuggestion.suggestionKey]
            ?? categoryRuleSuggestion.suggestedCategoryName;
          return (
            <article className="categoryRuleCard" key={categoryRuleSuggestion.suggestionKey}>
              <div className="categoryRuleSummary">
                <div>
                  <strong>{categoryRuleSuggestion.exampleMerchant}</strong>
                  <span>
                    {categoryRuleSuggestion.transactionCount} transactions · {formatCurrency(categoryRuleSuggestion.totalAmount)}
                  </span>
                </div>
                <span className="confidenceBadge">{categoryRuleSuggestion.confidenceLabel}</span>
              </div>

              <div className="rulePreview">
                <span>Contains</span>
                <code>{categoryRuleSuggestion.descriptionMatchText}</code>
              </div>

              <label>
                Category
                <select
                  value={selectedCategoryName}
                  onChange={(event) =>
                    onSelectCategory(categoryRuleSuggestion.suggestionKey, event.target.value)}
                >
                  {spendingCategories.map((spendingCategory) => (
                    <option
                      value={spendingCategory.spendingCategoryName}
                      key={spendingCategory.spendingCategoryKey}
                    >
                      {spendingCategory.spendingCategoryName}
                    </option>
                  ))}
                </select>
              </label>

              <button
                type="button"
                onClick={() => onApproveRule(categoryRuleSuggestion)}
                disabled={
                  approvingRuleKey === categoryRuleSuggestion.suggestionKey
                  || !selectedCategoryName
                }
              >
                {approvingRuleKey === categoryRuleSuggestion.suggestionKey ? "Approving" : "Approve"}
              </button>
            </article>
          );
        })}
      </div>
    </div>
  );
}
