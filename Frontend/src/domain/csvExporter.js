/**
 * Purpose: Exports the currently filtered transaction table to a local CSV file.
 * Runtime role: Converts visible dashboard rows and columns into browser-downloadable text without involving the backend.
 * Dependencies: Browser Blob/URL APIs and TransactionTable column metadata.
 */

export class CsvExporter {
  static exportTransactions(transactionRows, visibleTableColumns) {
    const csvRows = [
      visibleTableColumns.map((tableColumn) => CsvExporter.csvValue(tableColumn.label)).join(","),
      ...transactionRows.map((transaction) =>
        visibleTableColumns
          .map((tableColumn) => CsvExporter.csvValue(tableColumn.render(transaction)))
          .join(","),
      ),
    ];
    const csvBlob = new Blob([csvRows.join("\n")], { type: "text/csv;charset=utf-8" });
    const downloadUrl = URL.createObjectURL(csvBlob);
    const downloadLink = document.createElement("a");
    downloadLink.href = downloadUrl;
    downloadLink.download = "filtered-transactions.csv";
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
    URL.revokeObjectURL(downloadUrl);
  }

  static csvValue(value) {
    return `"${String(value ?? "").replaceAll('"', '""')}"`;
  }
}
