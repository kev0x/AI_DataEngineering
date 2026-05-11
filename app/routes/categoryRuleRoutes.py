"""FastAPI routes for category-rule approvals.

Purpose:
    Accepts a user's suggested-rule approval from the dashboard and delegates all
    validation/write logic to CategoryRuleService.
Pipeline role:
    Single write endpoint for user-guided transaction classification.
Dependencies:
    FastAPI APIRouter/HTTPException, app.models.CategoryRuleApprovalRequest, and
    app.services.categoryRuleService.CategoryRuleService.
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.models import CategoryRuleApprovalRequest
from app.services.categoryRuleService import CategoryRuleService


def build_category_rule_router(
    category_rule_service: CategoryRuleService,
) -> APIRouter:
    """Create routes that persist and apply user-approved category rules."""
    router = APIRouter()

    @router.post("/api/category-rules")
    def approve_category_rule(
        category_rule_request: CategoryRuleApprovalRequest,
    ) -> dict[str, object]:
        """Create a manual category rule and apply it to matching facts."""
        try:
            return category_rule_service.approve_category_rule_payload(
                category_rule_request
            )
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    return router
