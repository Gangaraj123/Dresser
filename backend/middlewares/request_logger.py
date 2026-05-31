"""Log every request start and response completion with latency."""
from __future__ import annotations

import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from logger import logger


class RequestLoggerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.monotonic()

        log = logger.bind(method=request.method, url=str(request.url.path))
        log.info("request_started")

        response: Response = await call_next(request)

        latency_ms = round((time.monotonic() - start) * 1000, 2)
        log_data = dict(
            method=request.method,
            url=request.url.path,
            status_code=response.status_code,
            latency_ms=latency_ms,
        )

        if response.status_code >= 500:
            logger.error("request_failed", **log_data)
        elif response.status_code >= 400:
            logger.warning("request_client_error", **log_data)
        else:
            logger.info("request_completed", **log_data)

        return response
