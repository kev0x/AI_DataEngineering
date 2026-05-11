"""FastAPI routes for dashboard read models.

Purpose:
    Exposes the dashboard data contract and spending-category dropdown values to the
    React frontend.
Pipeline role:
    Read-only API layer over Gold analytics views and the safe category dimension.
Dependencies:
    FastAPI APIRouter and app.services.dashboardService.DashboardService.
"""
from __future__ import annotations

from fastapi import APIRouter

from app.services.dashboardService import DashboardService


def build_dashboard_router(dashboard_service: DashboardService) -> APIRouter:
    """Create routes used by the dashboard screen."""
    router = APIRouter()

    @router.get("/api/dashboard")
    def dashboard() -> dict[str, object]:
        """Return dashboard data from safe Gold views."""
        return dashboard_service.dashboard_payload()

    @router.get("/api/spending-categories")
    def spending_categories() -> dict[str, object]:
        """Return active spending categories for category review."""
        return dashboard_service.spending_categories_payload()

    return router
