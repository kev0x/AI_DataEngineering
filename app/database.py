"""DuckDB connection and SQL-file helpers for the backend API.

Purpose:
    Centralizes the small amount of database plumbing shared by all FastAPI services.
    Keeping this in one file prevents each route/service from knowing where the DuckDB
    file lives, how to open it, or how SQL files are loaded from disk.
Pipeline role:
    This module is the API's warehouse access boundary. Services ask it for a
    read-only or writable DuckDB connection and for named SQL scripts.
Dependencies:
    DuckDB, pathlib, contextlib, and SQL files under app/sql/.
"""
from __future__ import annotations

from contextlib import contextmanager
from functools import lru_cache
from pathlib import Path
from typing import Iterator

import duckdb


APPLICATION_ROOT = Path(__file__).resolve().parent
SQL_ROOT = APPLICATION_ROOT / "sql"


class WarehouseDatabase:
    """Small wrapper around the DuckDB warehouse file used by API services."""

    def __init__(self, warehouse_path: Path) -> None:
        """Store the DuckDB file path used by the running API process."""
        self.warehouse_path = warehouse_path

    def exists(self) -> bool:
        """Return whether the configured warehouse file exists on disk."""
        return self.warehouse_path.exists()

    @contextmanager
    def open_connection(
        self,
        *,
        read_only: bool,
    ) -> Iterator[duckdb.DuckDBPyConnection]:
        """Open a DuckDB connection and close it when the service operation finishes.

        Args:
            read_only: True for dashboard/metadata reads, False for the category-rule
                approval path that writes to Silver.mapCategoryRule and Silver.factTransaction.

        Yields:
            A DuckDB connection already pointed at the configured warehouse file.
        """
        with duckdb.connect(str(self.warehouse_path), read_only=read_only) as connection:
            yield connection


@lru_cache(maxsize=64)
def load_sql(relative_sql_path: str) -> str:
    """Read and cache one SQL file from app/sql/.

    Args:
        relative_sql_path: Path below app/sql/, for example
            "dashboard/monthlyCashflow.sql".

    Returns:
        The SQL text exactly as stored in the project file.
    """
    sql_path = SQL_ROOT / relative_sql_path
    return sql_path.read_text(encoding="utf-8")


def quote_identifier(identifier: str) -> str:
    """Safely quote a DuckDB identifier before injecting it into metadata SQL."""
    return '"' + identifier.replace('"', '""') + '"'
