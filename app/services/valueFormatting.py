"""JSON serialization helpers shared by API services.

Purpose:
    Converts DuckDB/Python scalar values into shapes FastAPI can serialize cleanly.
Pipeline role:
    Keeps response formatting consistent across dashboard and warehouse metadata routes.
Dependencies:
    Python datetime/date and Decimal types.
"""
from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal


def normalize_api_value(value: object) -> object:
    """Convert DuckDB/Python scalar values into JSON-safe API values."""
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def format_currency(value: object) -> str:
    """Format a numeric value as US currency for the dashboard metric cards."""
    numeric_value = float(value or 0)
    if numeric_value < 0:
        return f"-${abs(numeric_value):,.2f}"
    return f"${numeric_value:,.2f}"
