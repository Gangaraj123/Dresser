"""
admin.py — Internal admin endpoints (service-key auth only).

These routes are NOT intended to be exposed to end-users.
They are protected by the Supabase service role key passed in the
X-Service-Key header, which is only known to server-side tooling.

Current endpoints
-----------------
POST /api/v1/admin/garments/import/batch
    Bulk-import clean garment images into any user's wardrobe.
    Accepts user_id as a form field instead of deriving it from a JWT.
"""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, Form, Header, HTTPException, UploadFile, File
from fastapi import status as http_status

from config import settings
from errors import AppError
from logger import logger
from routers.garments import _fast_ingest, _background_photo_job, _BATCH_SEMAPHORE
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])


# ---------------------------------------------------------------------------
# Auth dependency — service key only
# ---------------------------------------------------------------------------

async def require_service_key(
    x_service_key: str = Header(..., alias="X-Service-Key"),
) -> None:
    """Reject any request whose X-Service-Key doesn't match the env value."""
    if x_service_key != settings.supabase_service_key:
        raise HTTPException(
            status_code=http_status.HTTP_403_FORBIDDEN,
            detail="Invalid service key",
        )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/garments/import/batch", dependencies=[Depends(require_service_key)])
async def admin_import_garments_batch(
    user_id: str = Form(...),
    files: list[UploadFile] = File(...),
    clean: bool = Form(True),
):
    """
    Bulk-import garment images into *any* user's wardrobe.

    Auth: X-Service-Key header (service role key — never expose to clients).

    Form fields
    -----------
    user_id   Supabase auth UUID of the target user.
    files     One or more image files (jpg / png / webp).
    clean     true (default): skip classify + product-photo pipeline.
              false: run the full pipeline on each file.

    Returns a per-file result list identical to the user-facing batch endpoint.
    """
    log = logger.bind(module="admin.garments", user_id=user_id)
    log.info("admin_import_batch_started", file_count=len(files), clean=clean)

    if len(files) > 50:
        raise AppError("Batch limit is 50 files per request.", status_code=422, error_code="BATCH_TOO_LARGE")

    async def _process_one(file: UploadFile) -> dict:
        async with _BATCH_SEMAPHORE:
            try:
                image_bytes = await file.read()
                garment, base_name = await _fast_ingest(image_bytes, user_id, clean=clean)
                if not clean:
                    asyncio.create_task(
                        _background_photo_job(image_bytes, user_id, garment["id"], base_name)
                    )
                return {"filename": file.filename, "status": "ok", "garment": garment}
            except AppError as exc:
                return {"filename": file.filename, "status": "error", "message": exc.message}
            except Exception as exc:
                log.error("admin_import_item_failed", filename=file.filename, error=str(exc))
                return {"filename": file.filename, "status": "error", "message": "Processing failed."}

    results = await asyncio.gather(*[_process_one(f) for f in files])

    succeeded = sum(1 for r in results if r["status"] == "ok")
    failed    = len(results) - succeeded
    log.info("admin_import_batch_completed", succeeded=succeeded, failed=failed)

    return format_success({
        "total":     len(results),
        "succeeded": succeeded,
        "failed":    failed,
        "results":   list(results),
    })
