"""Dashboard data service for Gold-view API responses.

Purpose:
    Shapes all read-only dashboard payloads from the curated Gold views and the category
    dimension. The frontend receives ready-to-render JSON and does not need direct SQL.
Pipeline role:
    Enforces the privacy boundary: dashboard reads use Gold views for analytics and only
    the safe category dimension for rule-review dropdowns.
Dependencies:
    DuckDB, app.database.WarehouseDatabase, app.database.load_sql, and Gold/Silver SQL
    objects deployed by DataWarehouse/Deployment/deployWarehouse.py.
"""
from __future__ import annotations

import duckdb

from app.database import WarehouseDatabase, load_sql
from app.services.valueFormatting import format_currency, normalize_api_value


class DashboardService:
    """Builds the dashboard JSON contract consumed by the React app."""

    def __init__(self, warehouse_database: WarehouseDatabase) -> None:
        """Store the database helper used for read-only dashboard queries."""
        self.warehouse_database = warehouse_database

    def dashboard_payload(self) -> dict[str, object]:
        """Return the complete dashboard model from safe Gold views."""
        if not self.warehouse_database.exists():
            return {
                "warehouseExists": False,
                "dashboard": None,
            }

        with self.warehouse_database.open_connection(read_only=True) as connection:
            return {
                "warehouseExists": True,
                "dashboard": {
                    "summaryMetrics": self.dashboard_summary_metrics(connection),
                    "monthlyCashflow": self.query_rows(
                        connection,
                        load_sql("dashboard/monthlyCashflow.sql"),
                    ),
                    "categorySpending": self.query_rows(
                        connection,
                        load_sql("dashboard/categorySpending.sql"),
                    ),
                    "topMerchants": self.query_rows(
                        connection,
                        load_sql("dashboard/topMerchants.sql"),
                    ),
                    "uncategorizedSummary": self.query_rows(
                        connection,
                        load_sql("dashboard/uncategorizedSummary.sql"),
                    ),
                    "transactionRows": self.query_rows(
                        connection,
                        load_sql("dashboard/transactionLedger.sql"),
                    ),
                },
            }

    def spending_categories_payload(self) -> dict[str, object]:
        """Return active spending categories available for manual rule approval."""
        if not self.warehouse_database.exists():
            return {
                "warehouseExists": False,
                "spendingCategories": [],
            }

        with self.warehouse_database.open_connection(read_only=True) as connection:
            rows = connection.execute(load_sql("dashboard/spendingCategories.sql")).fetchall()

        return {
            "warehouseExists": True,
            "spendingCategories": [
                {
                    "spendingCategoryKey": spending_category_key,
                    "spendingCategoryName": spending_category_name,
                    "parentSpendingCategoryName": parent_spending_category_name,
                }
                for (
                    spending_category_key,
                    spending_category_name,
                    parent_spending_category_name,
                ) in rows
            ],
        }

    @staticmethod
    def dashboard_summary_metrics(
        connection: duckdb.DuckDBPyConnection,
    ) -> list[dict[str, object]]:
        """Return the four unfiltered summary cards from Gold views."""
        summary_row = connection.execute(load_sql("dashboard/summaryMetrics.sql")).fetchone()
        total_spending = normalize_api_value(summary_row[0])
        total_income = normalize_api_value(summary_row[1])
        net_cashflow = normalize_api_value(summary_row[2])
        uncategorized_transactions = normalize_api_value(summary_row[3])

        return [
            {
                "label": "Spending",
                "value": format_currency(total_spending),
                "helper": "Gold monthly category view",
            },
            {
                "label": "Income",
                "value": format_currency(total_income),
                "helper": "Gold monthly cashflow view",
            },
            {
                "label": "Net Cashflow",
                "value": format_currency(net_cashflow),
                "helper": "Income minus outflow",
            },
            {
                "label": "Uncategorized",
                "value": str(int(uncategorized_transactions or 0)),
                "helper": "Needs category rules",
            },
        ]

    @staticmethod
    def query_rows(
        connection: duckdb.DuckDBPyConnection,
        sql_statement: str,
    ) -> list[dict[str, object]]:
        """Execute a dashboard query and return JSON-safe dictionaries."""
        query_result = connection.execute(sql_statement)
        column_names = [column[0] for column in query_result.description]
        return [
            {
                column_name: normalize_api_value(column_value)
                for column_name, column_value in zip(column_names, row, strict=True)
            }
            for row in query_result.fetchall()
        ]
