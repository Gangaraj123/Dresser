"""Standard response envelope for all API endpoints.

Success:  { success: true,  data: ...,  error: null,  requestId: "..." }
Error:    { success: false, data: null, error: { message, code, details? }, requestId: "..." }
"""
from __future__ import annotations

from utils.request_context import get_request_id


def format_success(data, meta: dict | None = None) -> dict:
    response = {
        "success": True,
        "data": data,
        "error": None,
        "requestId": get_request_id(),
    }
    if meta is not None:
        response["meta"] = meta
    return response


def format_error(
    message: str,
    error_code: str = "INTERNAL_ERROR",
    details: list | None = None,
) -> dict:
    error_body: dict = {"message": message, "code": error_code}
    if details:
        error_body["details"] = details
    return {
        "success": False,
        "data": None,
        "error": error_body,
        "requestId": get_request_id(),
    }
