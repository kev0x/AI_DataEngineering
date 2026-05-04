from __future__ import annotations

from pathlib import Path
import os

import duckdb
from fastapi import FastAPI


WAREHOUSE_PATH = Path(os.getenv("WAREHOUSE_PATH", "warehouse/finance.duckdb"))


class WarehouseCatalog:
    """Read-only catalog access for the local DuckDB warehouse."""

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
    """Creates the FastAPI application and wires routes to service classes."""

    def __init__(self, warehouse_catalog: WarehouseCatalog) -> None:
        """Store API collaborators used by route handlers."""
        self.warehouse_catalog = warehouse_catalog

    def create(self) -> FastAPI:
        """Create the FastAPI app and register all current API routes."""
        app = FastAPI(title="AI Data Engineering Lab", version="0.1.0")

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

        return app


warehouse_catalog = WarehouseCatalog(WAREHOUSE_PATH)
app = ApiApplicationFactory(warehouse_catalog).create()
