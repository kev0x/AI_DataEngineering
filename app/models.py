"""Pydantic request models used by the backend API.

Purpose:
    Defines the JSON contracts accepted by FastAPI route handlers. Keeping these models
    outside the route files makes it easy to see what the browser is allowed to send.
Pipeline role:
    Models validate inbound UI requests before any service tries to write to DuckDB.
Dependencies:
    Pydantic BaseModel and Field.
"""
from __future__ import annotations

from pydantic import BaseModel, Field


class CategoryRuleApprovalRequest(BaseModel):
    """Payload sent when the user turns a UI suggestion into a category rule.

    The field names intentionally remain camelCase because they are part of the API
    contract consumed by the React frontend.
    """

    sourceAccountType: str = Field(min_length=1)
    transactionType: str = Field(min_length=1)
    transactionEventType: str = Field(min_length=1)
    descriptionMatchType: str = Field(default="contains", min_length=1)
    descriptionMatchText: str = Field(min_length=1)
    spendingCategoryName: str = Field(min_length=1)
