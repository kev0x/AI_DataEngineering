"""Category-rule approval service for user-guided transaction classification.

Purpose:
    Persists a user-approved rule in Silver.mapCategoryRule and applies that rule to
    currently matching Uncategorized/Unknown facts so the dashboard updates immediately.
Pipeline role:
    This is the API's only warehouse write path. All dashboard reads remain Gold-only,
    while this service carefully writes to the Silver rule and fact lineage tables.
Dependencies:
    DuckDB, hashlib, regex text normalization, app.database.WarehouseDatabase,
    app.models.CategoryRuleApprovalRequest, and app/sql/categoryRules/.
"""
from __future__ import annotations

import hashlib
import re

import duckdb

from app.database import WarehouseDatabase, load_sql
from app.models import CategoryRuleApprovalRequest


class CategoryRuleService:
    """Handles validation, upsert, matching, and fact updates for category rules."""

    def __init__(self, warehouse_database: WarehouseDatabase) -> None:
        """Store the database helper used for writable category-rule operations."""
        self.warehouse_database = warehouse_database

    def approve_category_rule_payload(
        self,
        category_rule_request: CategoryRuleApprovalRequest,
    ) -> dict[str, object]:
        """Persist a manual category rule and apply it to matching transactions."""
        if not self.warehouse_database.exists():
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

        with self.warehouse_database.open_connection(read_only=False) as connection:
            spending_category_key = self.spending_category_key(
                connection,
                category_rule_request.spendingCategoryName,
            )
            rule_name = self.manual_category_rule_name(
                category_rule_request,
                description_match_text,
                spending_category_key,
            )

            connection.execute("begin transaction")
            try:
                self.upsert_manual_category_rule(
                    connection,
                    category_rule_request,
                    description_match_text,
                    spending_category_key,
                    rule_name,
                )
                category_rule_key = self.category_rule_key(connection, rule_name)
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

    @staticmethod
    def spending_category_key(
        connection: duckdb.DuckDBPyConnection,
        spending_category_name: str,
    ) -> int:
        """Resolve a human category name to its Silver.dimSpendingCategory key."""
        spending_category_row = connection.execute(
            """
            select spendingCategoryKey
            from Silver.dimSpendingCategory
            where spendingCategoryName = ?
              and isActive = true
            """,
            [spending_category_name],
        ).fetchone()
        if spending_category_row is None:
            raise ValueError(f"Unknown spending category: {spending_category_name}")

        return int(spending_category_row[0])

    @staticmethod
    def upsert_manual_category_rule(
        connection: duckdb.DuckDBPyConnection,
        category_rule_request: CategoryRuleApprovalRequest,
        description_match_text: str,
        spending_category_key: int,
        rule_name: str,
    ) -> None:
        """Insert or update the approved rule using ruleName as the natural key."""
        connection.execute(
            load_sql("categoryRules/upsertManualCategoryRule.sql"),
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

    @staticmethod
    def category_rule_key(
        connection: duckdb.DuckDBPyConnection,
        rule_name: str,
    ) -> int:
        """Return the surrogate key for a rule after the idempotent upsert."""
        category_rule_row = connection.execute(
            """
            select categoryRuleKey
            from Silver.mapCategoryRule
            where ruleName = ?
            """,
            [rule_name],
        ).fetchone()
        if category_rule_row is None:
            raise ValueError(f"Category rule was not saved: {rule_name}")

        return int(category_rule_row[0])

    def matching_uncategorized_transaction_keys(
        self,
        connection: duckdb.DuckDBPyConnection,
        category_rule_request: CategoryRuleApprovalRequest,
        description_match_text: str,
    ) -> list[int]:
        """Return current Uncategorized/Unknown fact rows matched by the approved rule."""
        description_match_condition, description_match_values = (
            self.description_match_condition_and_values(
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
                *description_match_values,
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
        """Update matched facts so the dashboard reflects the new rule immediately."""
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
    def validate_category_rule_request(
        category_rule_request: CategoryRuleApprovalRequest,
    ) -> None:
        """Validate rule values before they are written into Silver.mapCategoryRule."""
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
        """Normalize approved text into the same shape used for fact matching."""
        alphanumeric_match_text = re.sub(
            r"[^A-Z0-9]+",
            " ",
            description_match_text.upper(),
        )
        return " ".join(alphanumeric_match_text.strip().split())

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
    def description_match_condition_and_values(
        description_match_type: str,
        description_match_text: str,
    ) -> tuple[str, list[str]]:
        """Return the SQL condition and bind values for one approved match type.

        "contains" is token based because real bank descriptions often include store
        numbers, punctuation, phone numbers, and dates between the words a user sees in
        the dashboard suggestion.
        """
        normalized_description_expression = CategoryRuleService.normalized_sql_expression(
            "factTransaction.transactionDescriptionClean"
        )
        if description_match_type == "exact":
            return f"{normalized_description_expression} = ?", [description_match_text]
        if description_match_type == "startsWith":
            return f"{normalized_description_expression} like ?", [f"{description_match_text}%"]

        match_tokens = [
            match_token
            for match_token in description_match_text.split()
            if len(match_token) > 1
        ]
        if len(match_tokens) == 0:
            match_tokens = [description_match_text]

        token_conditions = " and ".join(
            f"{normalized_description_expression} like ?"
            for _ in match_tokens
        )
        return token_conditions, [f"%{match_token}%" for match_token in match_tokens]

    @staticmethod
    def normalized_sql_expression(sql_expression: str) -> str:
        """Return a DuckDB SQL expression that normalizes text for rule matching."""
        return (
            "regexp_replace("
            f"trim(regexp_replace(upper(coalesce({sql_expression}, '')), '[^A-Z0-9]+', ' ', 'g')), "
            "'\\s+', "
            "' ', "
            "'g'"
            ")"
        )
