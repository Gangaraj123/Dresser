"""Add Cache-Control headers to safe read-only responses."""
from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Endpoints that are safe to cache client-side.
# Value = max-age in seconds.
_CACHEABLE: dict[str, int] = {
    "/api/v1/garments":        60,   # garment list — 1 min
    "/api/v1/garments/stats":  60,
    "/api/v1/outfits":         60,
    "/api/v1/profile":        120,   # profile changes rarely — 2 min
    "/api/v1/discover":       300,   # discover feed — 5 min
}


class CacheHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response: Response = await call_next(request)

        # Only cache successful GET responses
        if request.method != "GET" or response.status_code != 200:
            return response

        path = request.url.path
        max_age = _CACHEABLE.get(path)

        # Also match /api/v1/garments/<id>  (single garment fetch)
        if max_age is None and path.startswith("/api/v1/garments/"):
            max_age = 60

        if max_age is not None:
            response.headers["Cache-Control"] = f"private, max-age={max_age}"

        return response
