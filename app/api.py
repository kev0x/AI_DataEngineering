"""FastAPI service for dashboard data and category rule approval.

Purpose:
    Provides the browser and future AI tools with a safe API over the DuckDB finance
    warehouse. The API reads from Gold views for dashboard data and writes only the
    approved category-rule workflow back into Silver.mapCategoryRule / Silver.factTransaction.
Pipeline role:
    Sits between the React frontend and DuckDB so the browser never opens the warehouse
    file directly and never receives raw Chase-only private fields.
Dependencies:
    DuckDB warehouse file, FastAPI, Pydantic request models, Gold dashboard views,
    Silver.dimSpendingCategory, Silver.mapCategoryRule, and Silver.factTransaction.
"""
from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
import hashlib
from pathlib import Path
import os

import duckdb
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


WAREHOUSE_PATH = Path(os.getenv("WAREHOUSE_PATH", "warehouse/finance.duckdb"))


class CategoryRuleApprovalRequest(BaseModel):
    """Payload sent by the dashboard when a user turns a suggestion into a rule.

    The field names intentionally match the camelCase API contract used by the React app.
    The values become one row in Silver.mapCategoryRule and are also used to update
    currently matching Uncategorized/Unknown facts so the user sees the correction right
    away.
    """

    sourceAccountType: str = Field(min_length=1)
    transactionType: str = Field(min_length=1)
    transactionEventType: str = Field(min_length=1)
    descriptionMatchType: str = Field(default="contains", min_length=1)
    descriptionMatchText: str = Field(min_length=1)
    spendingCategoryName: str = Field(min_length=1)


class WarehouseCatalog:
    """Coordinates all DuckDB access used by the API routes.

    Most methods are read-only and query Gold views, which are the privacy boundary for
    the dashboard and future AI tools. The one write path is approve_category_rule_payload,
    which inserts/updates a manual rule and stamps matching fact rows with that rule key.
    """

    def __init__(self, warehouse_path: Path) -> None:
        """Store the DuckDB file path used by API endpoints."""
        self.warehouse_path = warehouse_path

    def exists(self) -> bool:
        """Return whether the configured DuckDB warehouse file exists."""
        return self.warehouse_path.exists()

    def health_payload(self) -> dict[str, object]:
        """Build the API health response for the warehouse connection."""
        return {
            "status": "ok",
            "warehousePath": str(self.warehouse_path),
            "warehouseExists": self.exists(),
        }

    def objects_payload(self) -> dict[str, object]:
        """Return Bronze, Silver, and Gold table/view metadata for the API."""
        if not self.exists():
            return {
                "warehouseExists": False,
                "objects": [],
            }

        with duckdb.connect(str(self.warehouse_path), read_only=True) as connection:
            rows = connection.execute(self.objects_sql()).fetchall()

        return {
            "warehouseExists": True,
            "objects": [
                {
                    "schemaName": schema_name,
                    "objectName": object_name,
                    "objectType": object_type,
                }
                for schema_name, object_name, object_type in rows
            ],
        }

    def row_counts_payload(self) -> dict[str, object]:
        """Return Bronze, Silver, and Gold object metadata plus row counts."""
        if not self.exists():
            return {
                "warehouseExists": False,
                "objects": [],
            }

        with duckdb.connect(str(self.warehouse_path), read_only=True) as connection:
            objects = connection.execute(self.objects_sql()).fetchall()
            row_counts = [
                self.row_count_payload(connection, schema_name, object_name, object_type)
                for schema_name, object_name, object_type in objects
            ]

        return {
            "warehouseExists": True,
            "objects": row_counts,
        }

    def dashboard_payload(self) -> dict[str, object]:
        """Return the complete dashboard model from Gold views.

        This method deliberately returns an already-shaped payload instead of exposing
        arbitrary SQL to the frontend. Keeping that contract small makes it easier to
        protect private fields and lets the React app focus on filtering and rendering.
        """
        if not self.exists():
            return {
                "warehouseExists": False,
                "dashboard": None,
            }

        with duckdb.connect(str(self.warehouse_path), read_only=True) as connection:
            return {
                "warehouseExists": True,
                "dashboard": {
                    "summaryMetrics": self.dashboard_summary_metrics(connection),
                    "monthlyCashflow": self.query_rows(
                        connection,
                        self.monthly_cashflow_sql(),
                    ),
                    "categorySpending": self.query_rows(
                        connection,
                        self.category_spending_sql(),
                    ),
                    "topMerchants": self.query_rows(
                        connection,
                        self.top_merchants_sql(),
                    ),
                    "uncategorizedSummary": self.query_rows(
                        connection,
                        self.uncategorized_summary_sql(),
                    ),
                    "transactionRows": self.query_rows(
                        connection,
                        self.transaction_ledger_sql(),
                    ),
                },
            }

    def spending_categories_payload(self) -> dict[str, object]:
        """Return active spending categories available for manual rule approval."""
        if not self.exists():
            return {
                "warehouseExists": False,
                "spendingCategories": [],
            }

        with duckdb.connect(str(self.warehouse_path), read_only=True) as connection:
            rows = connection.execute(self.spending_categories_sql()).fetchall()

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

    def approve_category_rule_payload(
        self,
        category_rule_request: CategoryRuleApprovalRequest,
    ) -> dict[str, object]:
        """Persist a manual category rule and apply it to matching transactions.

        Manual rule approval is the only current API write. The transaction is explicit:
        validate request values, resolve the target spending category, upsert the rule,
        find still-uncategorized facts that match the rule, update those facts, then
        commit. If any step fails, the rollback keeps rule/fact lineage consistent.
        """
        if not self.exists():
            return {
                "warehouseExists": False,
                "ruleApplied": False,
                "updatedTransactionCount": 0,
            }

        self.validate_category_rule_request(category_rule_request)
        description_match_text = self.normalized_match_text(
            category_rule_request.descriptionMatchText
        )
        if description_match_text == "":
            raise ValueError("Description match text cannot be blank.")

        with duckdb.connect(str(self.warehouse_path), read_only=False) as connection:
            spending_category_row = connection.execute(
                """
                select spendingCategoryKey
                from Silver.dimSpendingCategory
                where spendingCategoryName = ?
                  and isActive = true
                """,
                [category_rule_request.spendingCategoryName],
            ).fetchone()
            if spending_category_row is None:
                raise ValueError(
                    f"Unknown spending category: {category_rule_request.spendingCategoryName}"
                )

            spending_category_key = int(spending_category_row[0])
            rule_name = self.manual_category_rule_name(
                category_rule_request,
                description_match_text,
                spending_category_key,
            )

            connection.execute("begin transaction")
            try:
                connection.execute(
                    self.upsert_manual_category_rule_sql(),
                    [
                        rule_name,
                        category_rule_request.sourceAccountType,
                        category_rule_request.transactionType,
                        category_rule_request.descriptionMatchType,
                        description_match_text,
                        spending_category_key,
                        category_rule_request.transactionEventType,
                    ],
                )
                category_rule_key = int(
                    connection.execute(
                        """
                        select categoryRuleKey
                        from Silver.mapCategoryRule
                        where ruleName = ?
                        """,
                        [rule_name],
                    ).fetchone()[0]
                )
                matching_transaction_keys = self.matching_uncategorized_transaction_keys(
                    connection,
                    category_rule_request,
                    description_match_text,
                )
                self.apply_category_rule_to_transactions(
                    connection,
                    matching_transaction_keys,
                    spending_category_key,
                    category_rule_key,
                )
                connection.execute("commit")
            except Exception:
                connection.execute("rollback")
                raise

        return {
            "warehouseExists": True,
            "ruleApplied": True,
            "ruleName": rule_name,
            "categoryRuleKey": category_rule_key,
            "updatedTransactionCount": len(matching_transaction_keys),
        }

    def dashboard_summary_metrics(
        self,
        connection: duckdb.DuckDBPyConnection,
    ) -> list[dict[str, object]]:
        """Return the four dashboard summary cards from Gold views.

        These cards are duplicated client-side after filtering, but the API-level totals
        remain useful as the unfiltered warehouse baseline and as a simple health signal
        that the Gold aggregation views are working.
        """
        summary_row = connection.execute(self.summary_metrics_sql()).fetchone()
        total_spending = self.normalize_api_value(summary_row[0])
        total_income = self.normalize_api_value(summary_row[1])
        net_cashflow = self.normalize_api_value(summary_row[2])
        uncategorized_transactions = self.normalize_api_value(summary_row[3])

        return [
            {
                "label": "Spending",
                "value": self.format_currency(total_spending),
                "helper": "Gold monthly category view",
            },
            {
                "label": "Income",
                "value": self.format_currency(total_income),
                "helper": "Gold monthly cashflow view",
            },
            {
                "label": "Net Cashflow",
                "value": self.format_currency(net_cashflow),
                "helper": "Income minus outflow",
            },
            {
                "label": "Uncategorized",
                "value": str(int(uncategorized_transactions or 0)),
                "helper": "Needs category rules",
            },
        ]

    def query_rows(
        self,
        connection: duckdb.DuckDBPyConnection,
        sql_statement: str,
    ) -> list[dict[str, object]]:
        """Execute a read-only dashboard query and return JSON-safe rows."""
        query_result = connection.execute(sql_statement)
        column_names = [column[0] for column in query_result.description]
        return [
            {
                column_name: self.normalize_api_value(column_value)
                for column_name, column_value in zip(column_names, row, strict=True)
            }
            for row in query_result.fetchall()
        ]

    def row_count_payload(
        self,
        connection: duckdb.DuckDBPyConnection,
        schema_name: str,
        object_name: str,
        object_type: str,
    ) -> dict[str, object]:
        """Return the row-count response object for one table or view."""
        qualified_name = (
            f"{self.quote_identifier(schema_name)}."
            f"{self.quote_identifier(object_name)}"
        )
        row_count = connection.execute(
            f"select count(*) from {qualified_name}"
        ).fetchone()[0]
        return {
            "schemaName": schema_name,
            "objectName": object_name,
            "objectType": object_type,
            "rowCount": row_count,
        }

    def matching_uncategorized_transaction_keys(
        self,
        connection: duckdb.DuckDBPyConnection,
        category_rule_request: CategoryRuleApprovalRequest,
        description_match_text: str,
    ) -> list[int]:
        """Return current Uncategorized/Unknown fact rows matched by the rule.

        The rule update intentionally touches only rows that are still Uncategorized or
        Unknown. That prevents a newly approved broad rule from overwriting transactions
        that were already categorized by a higher-trust system, manual, or future AI rule.
        """
        description_match_condition, description_match_value = (
            self.description_match_condition_and_value(
                category_rule_request.descriptionMatchType,
                description_match_text,
            )
        )
        rows = connection.execute(
            f"""
            select factTransaction.transactionKey
            from Silver.factTransaction as factTransaction
            join Silver.dimFinancialAccount as financialAccount
                on factTransaction.financialAccountKey = financialAccount.financialAccountKey
            join Silver.dimSpendingCategory as spendingCategory
                on factTransaction.spendingCategoryKey = spendingCategory.spendingCategoryKey
            where financialAccount.accountType = ?
              and factTransaction.transactionType = ?
              and factTransaction.transactionEventType = ?
              and spendingCategory.spendingCategoryName in ('Uncategorized', 'Unknown')
              and {description_match_condition}
            """,
            [
                category_rule_request.sourceAccountType,
                category_rule_request.transactionType,
                category_rule_request.transactionEventType,
                description_match_value,
            ],
        ).fetchall()
        return [int(row[0]) for row in rows]

    @staticmethod
    def apply_category_rule_to_transactions(
        connection: duckdb.DuckDBPyConnection,
        transaction_keys: list[int],
        spending_category_key: int,
        category_rule_key: int,
    ) -> None:
        """Update matching facts so the dashboard reflects an approved rule immediately.

        New ETL runs will also apply the saved rule from Silver.mapCategoryRule. This
        direct fact update is just the convenience path that keeps the current dashboard
        session from waiting for a full reload from source files.
        """
        if len(transaction_keys) == 0:
            return

        transaction_key_placeholders = ", ".join("?" for _ in transaction_keys)
        connection.execute(
            f"""
            update Silver.factTransaction
            set
                spendingCategoryKey = ?,
                categoryRuleKey = ?,
                modifiedDatetime = current_timestamp
            where transactionKey in ({transaction_key_placeholders})
            """,
            [spending_category_key, category_rule_key, *transaction_keys],
        )

    @staticmethod
    def normalize_api_value(value: object) -> object:
        """Convert DuckDB/Python values into JSON-safe API values."""
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, (date, datetime)):
            return value.isoformat()
        return value

    @staticmethod
    def format_currency(value: object) -> str:
        """Format a numeric API value as US currency for the dashboard shell."""
        numeric_value = float(value or 0)
        if numeric_value < 0:
            return f"-${abs(numeric_value):,.2f}"
        return f"${numeric_value:,.2f}"

    @staticmethod
    def validate_category_rule_request(
        category_rule_request: CategoryRuleApprovalRequest,
    ) -> None:
        """Validate category-rule values before they are used in SQL.

        Pydantic already checks that required strings exist. This method enforces the
        project vocabulary for account types, match behavior, and transaction event types
        so the rule table does not slowly drift into inconsistent labels.
        """
        valid_account_types = {"checking", "creditCard"}
        valid_match_types = {"exact", "startsWith", "contains"}
        valid_event_types = {
            "purchase",
            "refund",
            "payment",
            "income",
            "transfer",
            "fee",
            "debtPayment",
            "other",
        }
        if category_rule_request.sourceAccountType not in valid_account_types:
            raise ValueError("Invalid account type.")
        if category_rule_request.descriptionMatchType not in valid_match_types:
            raise ValueError("Invalid description match type.")
        if category_rule_request.transactionEventType not in valid_event_types:
            raise ValueError("Invalid transaction event type.")

    @staticmethod
    def normalized_match_text(description_match_text: str) -> str:
        """Normalize the approved match text into the fact-table comparison shape."""
        return " ".join(description_match_text.upper().strip().split())

    @staticmethod
    def manual_category_rule_name(
        category_rule_request: CategoryRuleApprovalRequest,
        description_match_text: str,
        spending_category_key: int,
    ) -> str:
        """Create a stable idempotent rule name from the approved rule grain."""
        rule_hash = hashlib.sha256(
            "|".join(
                [
                    category_rule_request.sourceAccountType,
                    category_rule_request.transactionType,
                    category_rule_request.transactionEventType,
                    category_rule_request.descriptionMatchType,
                    description_match_text,
                    str(spending_category_key),
                ]
            ).encode("utf-8")
        ).hexdigest()[:16]
        return f"Manual Category Rule {rule_hash}"

    @staticmethod
    def description_match_condition_and_value(
        description_match_type: str,
        description_match_text: str,
    ) -> tuple[str, str]:
        """Return the SQL condition and bind value for one approved match type."""
        if description_match_type == "exact":
            return "factTransaction.transactionDescriptionClean = ?", description_match_text
        if description_match_type == "startsWith":
            return "factTransaction.transactionDescriptionClean like ?", f"{description_match_text}%"
        return "factTransaction.transactionDescriptionClean like ?", f"%{description_match_text}%"

    @staticmethod
    def summary_metrics_sql() -> str:
        """Return the Gold-view SQL used for dashboard metric cards."""
        return """
        select
            (
                select coalesce(sum(netSpendingAmount), 0)
                from Gold.vw_MonthlySpendingByCategory
            ) as totalSpendingAmount,
            (
                select coalesce(sum(incomeAmount), 0)
                from Gold.vw_MonthlyCashflow
            ) as totalIncomeAmount,
            (
                select coalesce(sum(netCashflowAmount), 0)
                from Gold.vw_MonthlyCashflow
            ) as netCashflowAmount,
            (
                select coalesce(sum(transactionCount), 0)
                from Gold.vw_UncategorizedTransactionSummary
            ) as uncategorizedTransactionCount
        """

    @staticmethod
    def monthly_cashflow_sql() -> str:
        """Return monthly cashflow rows for the dashboard trend panel."""
        return """
        select
            yearMonth,
            min(monthStartDate) as monthStartDate,
            sum(inflowAmount) as inflowAmount,
            sum(outflowAmount) as outflowAmount,
            sum(netCashflowAmount) as netCashflowAmount
        from Gold.vw_MonthlyCashflow
        group by yearMonth
        order by monthStartDate
        """

    @staticmethod
    def category_spending_sql() -> str:
        """Return category spending rows for the dashboard category panel."""
        return """
        select
            parentSpendingCategoryName,
            spendingCategoryName,
            sum(purchaseTransactionCount) as purchaseTransactionCount,
            sum(netSpendingAmount) as netSpendingAmount
        from Gold.vw_MonthlySpendingByCategory
        group by parentSpendingCategoryName, spendingCategoryName
        order by netSpendingAmount desc
        limit 8
        """

    @staticmethod
    def top_merchants_sql() -> str:
        """Return top merchant rows for the dashboard merchant panel."""
        return """
        select
            merchantDisplayName,
            sum(purchaseTransactionCount) as purchaseTransactionCount,
            sum(totalSpendingAmount) as totalSpendingAmount,
            avg(averagePurchaseAmount) as averagePurchaseAmount
        from Gold.vw_TopMerchantsBySpending
        group by merchantDisplayName
        order by totalSpendingAmount desc
        limit 8
        """

    @staticmethod
    def uncategorized_summary_sql() -> str:
        """Return uncategorized transaction rows for dashboard warnings."""
        return """
        select
            yearMonth,
            accountType,
            transactionEventType,
            sum(transactionCount) as transactionCount,
            sum(netTransactionAmount) as netTransactionAmount
        from Gold.vw_UncategorizedTransactionSummary
        group by yearMonth, accountType, transactionEventType
        order by yearMonth desc, transactionCount desc
        limit 8
        """

    @staticmethod
    def spending_categories_sql() -> str:
        """Return user-selectable spending categories for category review."""
        return """
        select
            spendingCategoryKey,
            spendingCategoryName,
            parentSpendingCategoryName
        from Silver.dimSpendingCategory
        where isActive = true
          and spendingCategoryName not in ('Unknown', 'Uncategorized')
        order by parentSpendingCategoryName, spendingCategoryName
        """

    @staticmethod
    def upsert_manual_category_rule_sql() -> str:
        """Return SQL that idempotently upserts one manually approved category rule.

        The API uses a stable ruleName hash as the natural key. Approving the same rule
        again updates the existing row instead of creating duplicates, which keeps rule
        history understandable while the project is still simple.
        """
        return """
        merge into Silver.mapCategoryRule as targetCategoryRule
        using (
            select
                ? as ruleName,
                ? as sourceAccountType,
                null::varchar as sourceCategoryName,
                ? as transactionType,
                ? as descriptionMatchType,
                ? as descriptionMatchText,
                ?::integer as spendingCategoryKey,
                ? as transactionEventType,
                'manual' as categoryAssignmentSource,
                120 as rulePriority
        ) as sourceCategoryRule
        on targetCategoryRule.ruleName = sourceCategoryRule.ruleName
        when matched then update set
            sourceAccountType = sourceCategoryRule.sourceAccountType,
            sourceCategoryName = sourceCategoryRule.sourceCategoryName,
            transactionType = sourceCategoryRule.transactionType,
            descriptionMatchType = sourceCategoryRule.descriptionMatchType,
            descriptionMatchText = sourceCategoryRule.descriptionMatchText,
            spendingCategoryKey = sourceCategoryRule.spendingCategoryKey,
            transactionEventType = sourceCategoryRule.transactionEventType,
            categoryAssignmentSource = sourceCategoryRule.categoryAssignmentSource,
            rulePriority = sourceCategoryRule.rulePriority,
            isActive = true,
            modifiedDatetime = current_timestamp
        when not matched then insert (
            ruleName,
            sourceAccountType,
            sourceCategoryName,
            transactionType,
            descriptionMatchType,
            descriptionMatchText,
            spendingCategoryKey,
            transactionEventType,
            categoryAssignmentSource,
            rulePriority
        )
        values (
            sourceCategoryRule.ruleName,
            sourceCategoryRule.sourceAccountType,
            sourceCategoryRule.sourceCategoryName,
            sourceCategoryRule.transactionType,
            sourceCategoryRule.descriptionMatchType,
            sourceCategoryRule.descriptionMatchText,
            sourceCategoryRule.spendingCategoryKey,
            sourceCategoryRule.transactionEventType,
            sourceCategoryRule.categoryAssignmentSource,
            sourceCategoryRule.rulePriority
        )
        """

    @staticmethod
    def transaction_ledger_sql() -> str:
        """Return safe transaction-level rows for frontend filtering."""
        return """
        select
            transactionKey,
            transactionDate,
            postedDate,
            yearMonth,
            monthStartDate,
            accountType,
            merchantDisplayName,
            parentSpendingCategoryName,
            spendingCategoryName,
            transactionType,
            transactionEventType,
            transactionAmount
        from Gold.vw_TransactionLedger
        order by transactionDate desc, transactionKey desc
        """

    @staticmethod
    def objects_sql() -> str:
        """Return the information_schema query used to list warehouse objects."""
        return """
        select
            table_schema as schemaName,
            table_name as objectName,
            table_type as objectType
        from information_schema.tables
        where table_schema in ('Bronze', 'Silver', 'Gold')
        order by
            table_schema,
            table_type,
            table_name
        """

    @staticmethod
    def quote_identifier(identifier: str) -> str:
        """Quote a DuckDB identifier before injecting it into a SQL statement."""
        return '"' + identifier.replace('"', '""') + '"'


class ApiApplicationFactory:
    """Creates the FastAPI application and wires routes to service classes.

    The factory keeps route declaration near the service object but avoids doing work at
    import time beyond constructing the app. That makes the module easy to run in Docker,
    test from Python, or later extend with MCP/AI endpoints.
    """

    def __init__(self, warehouse_catalog: WarehouseCatalog) -> None:
        """Store API collaborators used by route handlers."""
        self.warehouse_catalog = warehouse_catalog

    def create(self) -> FastAPI:
        """Create the FastAPI app and register all current API routes."""
        app = FastAPI(title="AI Data Engineering Lab", version="0.1.0")
        app.add_middleware(
            CORSMiddleware,
            allow_origins=[
                "http://localhost:5173",
                "http://127.0.0.1:5173",
                "http://localhost:3000",
                "http://127.0.0.1:3000",
            ],
            allow_credentials=False,
            allow_methods=["GET", "POST"],
            allow_headers=["*"],
        )

        @app.get("/health")
        def health() -> dict[str, object]:
            """Return service and warehouse-file health."""
            return self.warehouse_catalog.health_payload()

        @app.get("/api/warehouse/objects")
        def warehouse_objects() -> dict[str, object]:
            """Return warehouse table and view names."""
            return self.warehouse_catalog.objects_payload()

        @app.get("/api/warehouse/row-counts")
        def warehouse_row_counts() -> dict[str, object]:
            """Return warehouse table and view row counts."""
            return self.warehouse_catalog.row_counts_payload()

        @app.get("/api/dashboard")
        def dashboard() -> dict[str, object]:
            """Return dashboard data from safe Gold views."""
            return self.warehouse_catalog.dashboard_payload()

        @app.get("/api/spending-categories")
        def spending_categories() -> dict[str, object]:
            """Return active spending categories for category review."""
            return self.warehouse_catalog.spending_categories_payload()

        @app.post("/api/category-rules")
        def approve_category_rule(
            category_rule_request: CategoryRuleApprovalRequest,
        ) -> dict[str, object]:
            """Create a manual category rule and apply it to matching facts."""
            try:
                return self.warehouse_catalog.approve_category_rule_payload(
                    category_rule_request
                )
            except ValueError as error:
                raise HTTPException(status_code=400, detail=str(error)) from error

        return app


warehouse_catalog = WarehouseCatalog(WAREHOUSE_PATH)
app = ApiApplicationFactory(warehouse_catalog).create()
