"""FastAPI application entrypoint for the local finance data platform.

Purpose:
    Wires the backend together: DuckDB connection helper, service classes, route groups,
    CORS settings, and the final FastAPI app object used by Uvicorn.
Pipeline role:
    API boundary between the React dashboard/future AI agents and the DuckDB warehouse.
    Read routes expose curated Gold-view data; the category-rule route writes approved
    classification rules back into Silver.
Dependencies:
    FastAPI, app.database.WarehouseDatabase, app.routes.*, and app.services.*.
"""
from __future__ import annotations

from pathlib import Path
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import WarehouseDatabase
from app.routes.categoryRuleRoutes import build_category_rule_router
from app.routes.dashboardRoutes import build_dashboard_router
from app.routes.warehouseRoutes import build_warehouse_router
from app.services.categoryRuleService import CategoryRuleService
from app.services.dashboardService import DashboardService
from app.services.warehouseService import WarehouseService


WAREHOUSE_PATH = Path(os.getenv("WAREHOUSE_PATH", "warehouse/finance.duckdb"))


def create_app() -> FastAPI:
    """Create the FastAPI app and register all current route groups."""
    warehouse_database = WarehouseDatabase(WAREHOUSE_PATH)
    warehouse_service = WarehouseService(warehouse_database)
    dashboard_service = DashboardService(warehouse_database)
    category_rule_service = CategoryRuleService(warehouse_database)

    fastapi_app = FastAPI(title="AI Data Engineering Lab", version="0.1.0")
    fastapi_app.add_middleware(
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
    fastapi_app.include_router(build_warehouse_router(warehouse_service))
    fastapi_app.include_router(build_dashboard_router(dashboard_service))
    fastapi_app.include_router(build_category_rule_router(category_rule_service))

    return fastapi_app


app = create_app()
