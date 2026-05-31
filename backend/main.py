from __future__ import annotations

import traceback

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from errors import AppError
from logger import logger
from middlewares.cache_headers import CacheHeadersMiddleware
from middlewares.request_id import RequestIdMiddleware
from middlewares.request_logger import RequestLoggerMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from routers import admin, discover, events, garments, notifications, outfits, profile, stylist
from tasks.daily_outfit import run_daily_notifications
from tasks.wardrobe_nudges import run_forgotten_garment_nudges, run_weekly_insight_nudges
from services.supabase_client import supabase
from utils.response_formatter import format_error, format_success
from utils.request_context import get_request_id

app = FastAPI(
    title="Dresser API",
    description="AI-powered wardrobe management backend",
    version="1.0.0",
)

# ---------------------------------------------------------------------------
# Middleware (order matters — outermost wraps all inner)
# ---------------------------------------------------------------------------

# 1. Request ID must be first so every subsequent layer can read it
app.add_middleware(RequestIdMiddleware)

# 2. Request logger comes after request ID is set
app.add_middleware(RequestLoggerMiddleware)

# 3. Cache-Control headers on safe GET responses
app.add_middleware(CacheHeadersMiddleware)

# 4. CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------


@app.exception_handler(AppError)
async def app_error_handler(_request: Request, exc: AppError) -> JSONResponse:
    request_id = get_request_id()
    if exc.status_code >= 500:
        logger.error(
            "app_error",
            error_code=exc.error_code,
            message=exc.message,
            status_code=exc.status_code,
            stack=traceback.format_exc(),
        )
        message = "Internal server error"
    else:
        logger.warning(
            "client_error",
            error_code=exc.error_code,
            message=exc.message,
            status_code=exc.status_code,
        )
        message = exc.message

    details = getattr(exc, "details", None)
    return JSONResponse(
        status_code=exc.status_code,
        content=format_error(message, exc.error_code, details),
        headers={"x-request-id": request_id},
    )


@app.exception_handler(Exception)
async def unhandled_error_handler(_request: Request, exc: Exception) -> JSONResponse:
    request_id = get_request_id()
    logger.error(
        "unhandled_exception",
        exc_type=type(exc).__name__,
        message=str(exc),
        stack=traceback.format_exc(),
    )
    return JSONResponse(
        status_code=500,
        content=format_error("Internal server error", "INTERNAL_ERROR"),
        headers={"x-request-id": request_id},
    )


# ---------------------------------------------------------------------------
# Health checks (not behind auth)
# ---------------------------------------------------------------------------


@app.get("/health", tags=["health"])
async def health():
    return format_success({"status": "ok", "version": "1.0.0"})


@app.get("/health/deep", tags=["health"])
async def health_deep():
    checks: dict = {}

    try:
        start_ns = __import__("time").monotonic()
        supabase.table("profiles").select("id").limit(1).execute()
        checks["database"] = {
            "status": "ok",
            "latency_ms": round((__import__("time").monotonic() - start_ns) * 1000, 2),
        }
    except Exception as exc:
        checks["database"] = {"status": "error", "message": str(exc)}

    all_healthy = all(c["status"] == "ok" for c in checks.values())
    status_code = 200 if all_healthy else 503

    import time
    return JSONResponse(
        status_code=status_code,
        content=format_success(
            {
                "status": "ok" if all_healthy else "degraded",
                "uptime_seconds": round(__import__("time").process_time(), 2),
                "checks": checks,
            }
        ),
    )


# ---------------------------------------------------------------------------
# API routers
# ---------------------------------------------------------------------------

app.include_router(admin.router)
app.include_router(profile.router)
app.include_router(garments.router)
app.include_router(outfits.router)
app.include_router(stylist.router)
app.include_router(discover.router)
app.include_router(events.router)
app.include_router(notifications.router)

# ---------------------------------------------------------------------------
# Scheduler — daily outfit notifications
# ---------------------------------------------------------------------------

_scheduler = AsyncIOScheduler(timezone="UTC")


@app.on_event("startup")
async def _startup() -> None:
    _scheduler.add_job(
        run_daily_notifications,
        trigger="cron", minute="*",
        id="daily_outfit_check", replace_existing=True,
    )
    _scheduler.add_job(
        run_forgotten_garment_nudges,
        trigger="cron", minute="*",
        id="forgotten_garment_check", replace_existing=True,
    )
    _scheduler.add_job(
        run_weekly_insight_nudges,
        trigger="cron", minute="*",
        id="weekly_insight_check", replace_existing=True,
    )
    _scheduler.start()
    logger.info("scheduler_started", jobs=["daily_outfit", "forgotten_garment", "weekly_insight"])


@app.on_event("shutdown")
async def _shutdown() -> None:
    _scheduler.shutdown(wait=False)
    logger.info("scheduler_stopped")

# ---------------------------------------------------------------------------
# 404 catch-all
# ---------------------------------------------------------------------------


@app.api_route("/{full_path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def not_found(full_path: str = ""):  # noqa: ARG001
    from errors import NotFoundError
    raise NotFoundError("Route")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=settings.port, reload=True)
