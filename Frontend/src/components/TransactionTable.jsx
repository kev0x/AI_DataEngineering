/**
 * Purpose: Renders the filtered transaction ledger and its column visibility controls.
 * Runtime role: Gives users a row-level audit surface for the dashboard numbers and controls which fields are exported.
 * Dependencies: safe transaction rows from Gold.vw_TransactionLedger, formatter helpers, parent export/column callbacks, and table CSS classes.
 */

import { accountLabel, amountToneClass, formatCurrency } from "../domain/formatters.js";

export const transactionTableColumns = [
  // Column metadata is the single source of truth for rendering, visibility toggles, and CSV export.
  // Adding a new table column should usually mean adding one object here, not editing table loops.
  { key: "transactionDate", label: "Date", render: (transaction) => transaction.transactionDate },
  { key: "accountType", label: "Account", render: (transaction) => accountLabel(transaction.accountType) },
  { key: "merchantDisplayName", label: "Merchant", render: (transaction) => transaction.merchantDisplayName },
  { key: "spendingCategoryName", label: "Category", render: (transaction) => transaction.spendingCategoryName },
  { key: "transactionType", label: "Type", render: (transaction) => transaction.transactionType },
  { key: "transactionAmount", label: "Amount", render: (transaction) => formatCurrency(transaction.transactionAmount) },
];

export function defaultTransactionColumnVisibility() {
  // Start with every safe ledger column visible; the UI prevents hiding the final column.
  return transactionTableColumns.reduce(
    (columnVisibility, tableColumn) => ({
      ...columnVisibility,
      [tableColumn.key]: true,
    }),
    {},
  );
}

export function TransactionTable({
  filteredTransactionRows,
  isColumnPanelVisible,
  onExportTransactions,
  onToggleColumn,
  onToggleColumnPanel,
  onToggleFilterBar,
  visibleColumnKeys,
}) {
  // The table is intentionally presentational. It receives already-filtered rows from App.jsx
  // and uses column metadata to keep display and export behavior aligned.
  const visibleTableColumns = transactionTableColumns.filter(
    (tableColumn) => visibleColumnKeys[tableColumn.key],
  );
  const visibleColumnCount = visibleTableColumns.length;

  return (
    <section className="panel transactionsPanel">
      <div className="panelHeader">
        <h2>Transactions</h2>
        <span>{filteredTransactionRows.length} transactions</span>
        <div className="buttonRow">
          <button
            type="button"
            className="secondaryButton"
            onClick={onToggleFilterBar}
          >
            Filter
          </button>
          <button
            type="button"
            className="secondaryButton"
            onClick={onToggleColumnPanel}
          >
            Columns
          </button>
          <button
            type="button"
            className="secondaryButton"
            onClick={() => onExportTransactions(visibleTableColumns)}
          >
            Export
          </button>
        </div>
      </div>
      {isColumnPanelVisible && (
        <div className="columnPanel">
          {transactionTableColumns.map((tableColumn) => (
            <label className="checkboxLabel" key={tableColumn.key}>
              <input
                type="checkbox"
                checked={visibleColumnKeys[tableColumn.key]}
                disabled={visibleColumnKeys[tableColumn.key] && visibleColumnCount === 1}
                onChange={(event) => onToggleColumn(tableColumn.key, event.target.checked)}
              />
              {tableColumn.label}
            </label>
          ))}
        </div>
      )}
      <div className="tableScroller">
        <table>
          <thead>
            <tr>
              {visibleTableColumns.map((tableColumn) => (
                <th key={tableColumn.key}>{tableColumn.label}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredTransactionRows.map((transaction) => (
              <tr className={`transactionRow event-${transaction.transactionEventType}`} key={transaction.transactionKey}>
                {visibleTableColumns.map((tableColumn) => (
                  <td
                    className={tableColumn.key === "transactionAmount"
                      ? amountToneClass(transaction.transactionAmount)
                      : undefined}
                    key={tableColumn.key}
                  >
                    {tableColumn.render(transaction)}
                  </td>
                ))}
              </tr>
            ))}
            {filteredTransactionRows.length === 0 && (
              <tr>
                <td className="emptyTableCell" colSpan={Math.max(visibleColumnCount, 1)}>
                  No transactions match the active filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
