"""Warehouse metadata service for FastAPI routes.

Purpose:
    Handles API responses about the DuckDB file itself: health, object names, and row
    counts. This keeps metadata concerns separate from dashboard analytics and rule writes.
Pipeline role:
    Lets the browser or developer inspect which Bronze/Silver/Gold objects exist without
    granting arbitrary SQL access.
Dependencies:
    app.database.WarehouseDatabase, app.database.load_sql, app.database.quote_identifier,
    and DuckDB information_schema.
"""
from __future__ import annotations

import duckdb

from app.database import WarehouseDatabase, load_sql, quote_identifier


class WarehouseService:
    """Builds API payloads for warehouse health and object metadata."""

    def __init__(self, warehouse_database: WarehouseDatabase) -> None:
        """Store the database helper shared by route handlers."""
        self.warehouse_database = warehouse_database

    def health_payload(self) -> dict[str, object]:
        """Return service health and whether the configured DuckDB file exists."""
        return {
            "status": "ok",
            "warehousePath": str(self.warehouse_database.warehouse_path),
            "warehouseExists": self.warehouse_database.exists(),
        }

    def objects_payload(self) -> dict[str, object]:
        """Return Bronze, Silver, and Gold table/view metadata."""
        if not self.warehouse_database.exists():
            return {
                "warehouseExists": False,
                "objects": [],
            }

        with self.warehouse_database.open_connection(read_only=True) as connection:
            rows = connection.execute(load_sql("warehouse/objects.sql")).fetchall()

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
        """Return row counts for every Bronze, Silver, and Gold object."""
        if not self.warehouse_database.exists():
            return {
                "warehouseExists": False,
                "objects": [],
            }

        with self.warehouse_database.open_connection(read_only=True) as connection:
            objects = connection.execute(load_sql("warehouse/objects.sql")).fetchall()
            row_counts = [
                self.row_count_payload(connection, schema_name, object_name, object_type)
                for schema_name, object_name, object_type in objects
            ]

        return {
            "warehouseExists": True,
            "objects": row_counts,
        }

    @staticmethod
    def row_count_payload(
        connection: duckdb.DuckDBPyConnection,
        schema_name: str,
        object_name: str,
        object_type: str,
    ) -> dict[str, object]:
        """Return the row-count response object for one table or view."""
        qualified_object_name = (
            f"{quote_identifier(schema_name)}.{quote_identifier(object_name)}"
        )
        row_count = connection.execute(
            f"select count(*) from {qualified_object_name}"
        ).fetchone()[0]
        return {
            "schemaName": schema_name,
            "objectName": object_name,
            "objectType": object_type,
            "rowCount": row_count,
        }
