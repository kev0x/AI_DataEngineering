"""FastAPI routes for warehouse health and metadata.

Purpose:
    Exposes simple read-only endpoints that help confirm the API can see the DuckDB file
    and list deployed Bronze/Silver/Gold objects.
Pipeline role:
    Developer-facing observability for the local warehouse.
Dependencies:
    FastAPI APIRouter and app.services.warehouseService.WarehouseService.
"""
from __future__ import annotations

from fastapi import APIRouter

from app.services.warehouseService import WarehouseService


def build_warehouse_router(warehouse_service: WarehouseService) -> APIRouter:
    """Create routes for warehouse health, object listing, and row counts."""
    router = APIRouter()

    @router.get("/health")
    def health() -> dict[str, object]:
        """Return service and warehouse-file health."""
        return warehouse_service.health_payload()

    @router.get("/api/warehouse/objects")
    def warehouse_objects() -> dict[str, object]:
        """Return warehouse table and view names."""
        return warehouse_service.objects_payload()

    @router.get("/api/warehouse/row-counts")
    def warehouse_row_counts() -> dict[str, object]:
        """Return warehouse table and view row counts."""
        return warehouse_service.row_counts_payload()

    return router
