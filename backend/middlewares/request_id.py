"""Attach a unique request ID to every incoming request.

Reads X-Request-ID from the incoming headers (for distributed tracing).
Falls back to a new UUID if not present.
Sets X-Request-ID on the response and stores the value in:
  - request.state.request_id  (for route handlers)
  - request_id_var context var (for services / response formatter)
  - structlog contextvars      (for log lines)
"""
from __future__ import annotations

import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from utils.request_context import request_id_var


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())

        # Make it available everywhere
        request.state.request_id = request_id
        token = request_id_var.set(request_id)
        structlog.contextvars.bind_contextvars(requestId=request_id)

        try:
            response: Response = await call_next(request)
        finally:
            request_id_var.reset(token)
            structlog.contextvars.clear_contextvars()

        response.headers["x-request-id"] = request_id
        return response
