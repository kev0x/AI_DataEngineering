/**
 * Purpose: Suggests category rules from currently uncategorized transaction patterns.
 * Runtime role: Groups similar transaction descriptions into reviewable rule candidates that the user can approve through the API.
 * Dependencies: Filtered transaction rows, spending category options, and the manual rule endpoint contract.
 */

export class CategoryRuleSuggestionService {
  /**
   * Build reviewable rule suggestions from the currently visible Uncategorized rows.
   * Suggestions are grouped by account type, transaction type, event type, and a cleaned
   * description fragment so approving one suggestion updates a repeatable pattern.
   */
  static suggestionsFromTransactions(transactionRows, spendingCategories) {
    const availableCategoryNames = new Set(
      spendingCategories.map((spendingCategory) => spendingCategory.spendingCategoryName),
    );
    const uncategorizedTransactions = transactionRows.filter((transaction) =>
      ["Uncategorized", "Unknown"].includes(transaction.spendingCategoryName)
      && ["purchase", "refund"].includes(transaction.transactionEventType),
    );
    const groupedSuggestions = groupRows(
      uncategorizedTransactions,
      (transaction) => {
        const descriptionMatchText = suggestedDescriptionMatchText(transaction.merchantDisplayName);
        return [
          transaction.accountType,
          transaction.transactionType,
          transaction.transactionEventType,
          descriptionMatchText,
        ].join("|");
      },
    );

    return Array.from(groupedSuggestions.entries())
      .map(([suggestionKey, suggestionTransactions]) =>
        CategoryRuleSuggestionService.suggestionFromGroup(
          suggestionKey,
          suggestionTransactions,
          availableCategoryNames,
        ),
      )
      .filter((suggestion) => suggestion.descriptionMatchText.length > 0)
      .sort((leftSuggestion, rightSuggestion) =>
        rightSuggestion.transactionCount - leftSuggestion.transactionCount
        || rightSuggestion.totalAmount - leftSuggestion.totalAmount,
      );
  }

  /**
   * Convert one grouped pattern into the UI/API payload used by CategoryRuleReview.
   */
  static suggestionFromGroup(suggestionKey, suggestionTransactions, availableCategoryNames) {
    const exampleTransaction = suggestionTransactions[0];
    const descriptionMatchText = suggestedDescriptionMatchText(exampleTransaction.merchantDisplayName);
    return {
      suggestionKey,
      sourceAccountType: exampleTransaction.accountType,
      transactionType: exampleTransaction.transactionType,
      transactionEventType: exampleTransaction.transactionEventType,
      descriptionMatchType: "contains",
      descriptionMatchText,
      suggestedCategoryName: suggestedCategoryNameForMatchText(
        descriptionMatchText,
        availableCategoryNames,
      ),
      exampleMerchant: exampleTransaction.merchantDisplayName,
      transactionCount: suggestionTransactions.length,
      totalAmount: sumRows(suggestionTransactions, (transaction) =>
        Math.abs(Number(transaction.transactionAmount)),
      ),
      confidenceLabel: confidenceLabelForSuggestion(descriptionMatchText, suggestionTransactions.length),
    };
  }
}

function confidenceLabelForSuggestion(descriptionMatchText, transactionCount) {
  // Confidence is intentionally simple and explainable: repeated short patterns are more
  // likely to be safe rules; one-off or long patterns deserve human review.
  if (transactionCount >= 5 && descriptionMatchText.split(" ").length <= 2) {
    return "High";
  }
  if (transactionCount >= 2) {
    return "Medium";
  }
  return "Review";
}

function groupRows(rows, keySelector) {
  return rows.reduce((groupedRows, row) => {
    const groupKey = keySelector(row) ?? "Unknown";
    if (!groupedRows.has(groupKey)) {
      groupedRows.set(groupKey, []);
    }
    groupedRows.get(groupKey).push(row);
    return groupedRows;
  }, new Map());
}

function meaningfulRuleWords(value) {
  // Chase ACH descriptions contain routing words that are useful for banking but noisy
  // for category rules. Removing them makes suggested match text easier to approve.
  const stopWords = new Set([
    "ACH",
    "CO",
    "DESCR",
    "ENTRY",
    "ID",
    "IND",
    "NAME",
    "ORIG",
    "SEC",
    "WEB",
  ]);
  return normalizeRuleText(value)
    .replace(/[:*#/,-]/g, " ")
    .split(/\s+/)
    .filter((word) => word.length > 1)
    .filter((word) => !stopWords.has(word))
    .filter((word) => !/^\d+$/.test(word));
}

function normalizeRuleText(value) {
  return String(value ?? "")
    .toUpperCase()
    .replace(/\s+/g, " ")
    .trim();
}

function suggestedCategoryNameForMatchText(descriptionMatchText, availableCategoryNames) {
  // These hints are UI defaults only. The durable truth is created only after the user
  // approves a suggestion through the API and the rule lands in Silver.mapCategoryRule.
  if (/(ROBINHOOD|FIDELITY|VANGUARD|SCHWAB|BROKERAGE)/.test(descriptionMatchText)) {
    if (availableCategoryNames.has("Investments")) {
      return "Investments";
    }
    if (availableCategoryNames.has("Transfer")) {
      return "Transfer";
    }
  }

  const categoryPatterns = [
    { pattern: /(UBER|LYFT|TRANSIT|MTA|PARKING|TRAIN|BUS)/, categoryName: "Transportation" },
    { pattern: /(SHELL|EXXON|BP|CHEVRON|GAS)/, categoryName: "Gas" },
    { pattern: /(MARKET|GROCERY|SAFEWAY|KROGER|TRADER|WHOLE FOODS|COSTCO)/, categoryName: "Groceries" },
    { pattern: /(CAFE|COFFEE|RESTAURANT|TACO|PIZZA|STARBUCKS|DUNKIN|CHIPOTLE)/, categoryName: "Dining" },
    { pattern: /(AMAZON|TARGET|WALMART|SHOP|STORE)/, categoryName: "Shopping" },
    { pattern: /(VERIZON|TMOBILE|COMCAST|UTILITY|ELECTRIC|WATER|GAS BILL)/, categoryName: "BillsAndUtilities" },
    { pattern: /(PHARMACY|CVS|WALGREENS|MEDICAL|HEALTH)/, categoryName: "Health" },
  ];
  const matchedCategory = categoryPatterns.find((categoryPattern) =>
    categoryPattern.pattern.test(descriptionMatchText),
  )?.categoryName;
  if (matchedCategory && availableCategoryNames.has(matchedCategory)) {
    return matchedCategory;
  }
  if (availableCategoryNames.has("Personal")) {
    return "Personal";
  }
  return Array.from(availableCategoryNames)[0] ?? "";
}

function suggestedDescriptionMatchText(merchantDisplayName) {
  // For ACH-style descriptions, prefer the origin company name because it is usually the
  // real merchant or counterparty. For card-style descriptions, use the cleaned merchant.
  const normalizedMerchantName = normalizeRuleText(merchantDisplayName);
  const originCompanyMatch = normalizedMerchantName.match(/ORIG CO NAME:([^]+?) CO ENTRY/);
  if (originCompanyMatch?.[1]) {
    return meaningfulRuleWords(originCompanyMatch[1]).slice(0, 3).join(" ");
  }
  return meaningfulRuleWords(normalizedMerchantName).slice(0, 3).join(" ");
}

function sumRows(rows, amountSelector) {
  return rows.reduce((sumAmount, row) => sumAmount + amountSelector(row), 0);
}
