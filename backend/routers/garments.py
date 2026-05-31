from __future__ import annotations

import asyncio
import uuid
from datetime import date

import re

from fastapi import APIRouter, BackgroundTasks, Depends, Form, Query, UploadFile, File

from dependencies import get_current_user
from errors import AppError, NotFoundError
from logger import logger
from models.schemas import GarmentUpdate, WardrobeStats
from services.color_scoring import score_garment_compatibility
from services.firebase_service import send_push
from services.gemini_service import (
    classify_input,
    generate_product_photo,
    compress_for_storage,
    generate_thumbnail,
    analyze_garment,
)
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/garments", tags=["garments"])

_BATCH_SEMAPHORE = asyncio.Semaphore(3)

_RETAKE_MESSAGES = {
    "too_blurry": "The photo is too blurry. Please retake in better lighting.",
    "garment_not_visible": "Make sure the garment is clearly visible and well-lit.",
    "too_dark": "The photo is too dark. Move to a brighter area and try again.",
    "multiple_items": "Please upload one garment at a time.",
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _build_garment_record(user_id: str, display_url: str, thumb_url: str | None, metadata: dict, skin_score: int | None) -> dict:
    return {
        "user_id": user_id,
        "display_image_url": display_url,
        "thumbnail_url": thumb_url,          # None signals "photo still processing"
        "category": metadata.get("category"),
        "sub_category": metadata.get("sub_category"),
        "colors": metadata.get("colors"),
        "dominant_color_hex": metadata.get("dominant_color_hex"),
        "dominant_color_name": metadata.get("dominant_color_name"),
        "color_family": metadata.get("color_family"),
        "pattern": metadata.get("pattern"),
        "fabric": metadata.get("fabric"),
        "formality_score": metadata.get("formality_score"),
        "season_suitability": metadata.get("season_suitability"),
        "brand": metadata.get("brand"),
        "ai_confidence": metadata.get("confidence"),
        "skin_compatibility_score": skin_score,
    }


def _fetch_skin_score(user_id: str, dominant_color_hex: str | None) -> int | None:
    if not dominant_color_hex:
        return None
    profile = (
        supabase.table("profiles")
        .select("seasonal_type")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    seasonal_type = profile.data.get("seasonal_type") if profile.data else None
    if seasonal_type:
        return score_garment_compatibility(dominant_color_hex, seasonal_type)
    return None


async def _fast_ingest(image_bytes: bytes, user_id: str, *, clean: bool = False) -> tuple[dict, str]:
    """
    Fast path: store original, quality-gate (if dirty), analyze metadata,
    insert garment with compressed-original as display placeholder,
    thumbnail_url=None (signals "photo processing" to clients).

    Returns (garment_row, base_name). base_name is passed to the background job.
    """
    base_name = str(uuid.uuid4())

    # ── Store original (fire-and-forget style; supabase client is sync) ───────
    original_path = f"{user_id}/{base_name}_original.jpg"
    supabase.storage.from_("dresser-originals").upload(
        original_path, image_bytes, {"content-type": "image/jpeg"}
    )

    # ── Quality gate (skip for clean imports) ─────────────────────────────────
    if not clean:
        classification = await classify_input(image_bytes)
        if not classification.get("can_process", True):
            reason = classification.get("retake_reason") or "garment_not_visible"
            raise AppError(
                _RETAKE_MESSAGES.get(reason, "Please retake the photo and try again."),
                status_code=422,
                error_code="RETAKE_NEEDED",
            )

    # ── Compressed original as display placeholder ────────────────────────────
    display_bytes = compress_for_storage(image_bytes, quality=85)
    display_path = f"{user_id}/{base_name}_display.jpg"
    supabase.storage.from_("dresser-display").upload(
        display_path, display_bytes, {"content-type": "image/jpeg"}
    )
    display_url = supabase.storage.from_("dresser-display").get_public_url(display_path)

    # ── For clean images: generate thumbnail immediately (no AI image gen) ────
    thumb_url: str | None = None
    if clean:
        thumbnail_bytes = generate_thumbnail(display_bytes)
        thumb_path = f"{user_id}/{base_name}_thumb.png"
        supabase.storage.from_("dresser-thumbnails").upload(
            thumb_path, thumbnail_bytes, {"content-type": "image/png"}
        )
        thumb_url = supabase.storage.from_("dresser-thumbnails").get_public_url(thumb_path)

    # ── Analyze garment metadata + skin score (parallel) ──────────────────────
    metadata, skin_score = await asyncio.gather(
        analyze_garment(image_bytes),
        asyncio.to_thread(_fetch_skin_score, user_id, None),  # placeholder, replaced below
    )
    skin_score = _fetch_skin_score(user_id, metadata.get("dominant_color_hex"))

    # ── Insert ────────────────────────────────────────────────────────────────
    record = _build_garment_record(user_id, display_url, thumb_url, metadata, skin_score)
    result = supabase.table("garments").insert(record).execute()
    return result.data[0], base_name


async def _notify_photo_ready(user_id: str, garment_id: str, *, enhanced: bool) -> None:
    """Fire-and-forget push when a garment's background photo job finishes."""
    try:
        profile = (
            supabase.table("profiles")
            .select("fcm_token")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        token = (profile.data or {}).get("fcm_token")
        if not token:
            return
        body = (
            "Your garment photo has been enhanced and is ready to view."
            if enhanced
            else "Your garment has been added to your wardrobe."
        )
        result = await send_push(
            fcm_token=token,
            title="Photo ready",
            body=body,
            data={"type": "photo_ready", "garment_id": garment_id},
        )
        if result.get("should_delete_token"):
            supabase.table("profiles").update({"fcm_token": None}).eq("id", user_id).execute()
    except Exception as exc:
        logger.warning("notify_photo_ready_failed", error=str(exc))


async def _background_photo_job(image_bytes: bytes, user_id: str, garment_id: str, base_name: str) -> None:
    """
    Background task: generate clean product photo, replace the placeholder
    display image, generate thumbnail, update garment record.

    If generation fails the garment keeps its compressed-original display
    and gets a thumbnail generated from it — so nothing is left broken.
    """
    log = logger.bind(module="garments.bg", garment_id=garment_id)
    log.info("background_photo_job_started")

    display_path = f"{user_id}/{base_name}_display.jpg"
    thumb_path   = f"{user_id}/{base_name}_thumb.png"

    try:
        product_bytes = await generate_product_photo(image_bytes)
        display_bytes = compress_for_storage(product_bytes, quality=85)

        # Overwrite the placeholder display with the processed photo
        supabase.storage.from_("dresser-display").upload(
            display_path, display_bytes,
            {"content-type": "image/jpeg", "upsert": "true"},
        )
        display_url = supabase.storage.from_("dresser-display").get_public_url(display_path)

        thumbnail_bytes = generate_thumbnail(display_bytes)
        supabase.storage.from_("dresser-thumbnails").upload(
            thumb_path, thumbnail_bytes, {"content-type": "image/png"}
        )
        thumb_url = supabase.storage.from_("dresser-thumbnails").get_public_url(thumb_path)

        supabase.table("garments").update({
            "display_image_url": display_url,
            "thumbnail_url": thumb_url,
        }).eq("id", garment_id).execute()

        log.info("background_photo_job_completed")
        await _notify_photo_ready(user_id, garment_id, enhanced=True)

    except Exception as exc:
        log.error("background_photo_job_failed", error=str(exc))
        # Fallback: generate thumbnail from original so card never stays blank
        try:
            fallback_bytes = compress_for_storage(image_bytes, quality=85)
            thumbnail_bytes = generate_thumbnail(fallback_bytes)
            supabase.storage.from_("dresser-thumbnails").upload(
                thumb_path, thumbnail_bytes, {"content-type": "image/png"}
            )
            thumb_url = supabase.storage.from_("dresser-thumbnails").get_public_url(thumb_path)
            supabase.table("garments").update({"thumbnail_url": thumb_url}).eq("id", garment_id).execute()
            log.info("background_photo_job_fallback_thumbnail_set")
            await _notify_photo_ready(user_id, garment_id, enhanced=False)
        except Exception as fallback_exc:
            log.error("background_photo_job_fallback_failed", error=str(fallback_exc))


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("")
async def list_garments(
    category: str | None = Query(None),
    status: str = Query("active"),
    formality_min: int | None = Query(None),
    formality_max: int | None = Query(None),
    season: str | None = Query(None),
    user=Depends(get_current_user),
):
    log = logger.bind(module="garments", user_id=user["user_id"])
    log.debug("list_garments", category=category, status=status)

    query = (
        supabase.table("garments")
        .select("*")
        .eq("user_id", user["user_id"])
        .eq("status", status)
    )
    if category:
        query = query.eq("category", category)
    if formality_min is not None:
        query = query.gte("formality_score", formality_min)
    if formality_max is not None:
        query = query.lte("formality_score", formality_max)
    if season:
        query = query.contains("season_suitability", [season])
    result = query.order("created_at", desc=True).execute()
    return format_success(result.data)


@router.post("")
async def upload_garment(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    """
    Fast ingest: classify → analyze → insert with compressed original as placeholder.
    No product photo generation yet — call POST /{id}/enhance after the user saves
    to trigger that in the background.
    """
    log = logger.bind(module="garments", user_id=user["user_id"])
    log.info("upload_garment_started", filename=file.filename)
    image_bytes = await file.read()
    garment, _ = await _fast_ingest(image_bytes, user["user_id"], clean=False)
    log.info("upload_garment_returned", garment_id=garment["id"])
    return format_success(garment)


@router.post("/import")
async def import_garment(file: UploadFile = File(...), user=Depends(get_current_user)):
    """
    Import a single clean product photo. No background job — thumbnail is
    generated immediately since no AI image generation is needed.
    """
    log = logger.bind(module="garments", user_id=user["user_id"])
    log.info("import_garment_started", filename=file.filename)
    image_bytes = await file.read()
    garment, _ = await _fast_ingest(image_bytes, user["user_id"], clean=True)
    log.info("import_garment_completed", garment_id=garment["id"])
    return format_success(garment)


@router.post("/import/batch")
async def import_garments_batch(
    files: list[UploadFile] = File(...),
    clean: bool = Form(True),
    user=Depends(get_current_user),
):
    """
    Bulk import. clean=true (default): no background job, thumbnails immediate.
    clean=false: background photo job per file.
    """
    log = logger.bind(module="garments", user_id=user["user_id"])
    log.info("import_batch_started", file_count=len(files), clean=clean)

    if len(files) > 50:
        raise AppError("Batch limit is 50 files per request.", status_code=422, error_code="BATCH_TOO_LARGE")

    async def _process_one(file: UploadFile) -> dict:
        async with _BATCH_SEMAPHORE:
            try:
                image_bytes = await file.read()
                garment, base_name = await _fast_ingest(image_bytes, user["user_id"], clean=clean)
                if not clean:
                    # Kick off background job per item (shares the semaphore pool)
                    asyncio.create_task(
                        _background_photo_job(image_bytes, user["user_id"], garment["id"], base_name)
                    )
                return {"filename": file.filename, "status": "ok", "garment": garment}
            except AppError as exc:
                return {"filename": file.filename, "status": "error", "message": exc.message}
            except Exception as exc:
                log.error("import_batch_item_failed", filename=file.filename, error=str(exc))
                return {"filename": file.filename, "status": "error", "message": "Processing failed."}

    results = await asyncio.gather(*[_process_one(f) for f in files])
    succeeded = sum(1 for r in results if r["status"] == "ok")
    failed = len(results) - succeeded
    log.info("import_batch_completed", succeeded=succeeded, failed=failed)

    return format_success({"total": len(results), "succeeded": succeeded, "failed": failed, "results": list(results)})


@router.get("/stats")
async def get_stats(user=Depends(get_current_user)):
    result = (
        supabase.table("garments")
        .select("*")
        .eq("user_id", user["user_id"])
        .eq("status", "active")
        .execute()
    )
    garments = result.data

    if not garments:
        return format_success(
            WardrobeStats(total=0, topwear=0, bottomwear=0, footwear=0, outerwear=0, accessory=0).model_dump()
        )

    most_worn = max(garments, key=lambda g: g.get("times_worn") or 0)
    least_worn = min(garments, key=lambda g: g.get("times_worn") or 0)
    total_value = sum(g.get("purchase_price") or 0 for g in garments)

    stats = WardrobeStats(
        total=len(garments),
        topwear=sum(1 for g in garments if g.get("category") == "topwear"),
        bottomwear=sum(1 for g in garments if g.get("category") == "bottomwear"),
        footwear=sum(1 for g in garments if g.get("category") == "footwear"),
        outerwear=sum(1 for g in garments if g.get("category") == "outerwear"),
        accessory=sum(1 for g in garments if g.get("category") == "accessory"),
        total_value=total_value if total_value > 0 else None,
        most_worn_id=most_worn.get("id"),
        least_worn_id=least_worn.get("id"),
    )
    return format_success(stats.model_dump())


@router.get("/{garment_id}")
async def get_garment(garment_id: str, user=Depends(get_current_user)):
    result = (
        supabase.table("garments")
        .select("*")
        .eq("id", garment_id)
        .eq("user_id", user["user_id"])
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise NotFoundError("Garment")
    return format_success(result.data)


@router.put("/{garment_id}")
async def update_garment(
    garment_id: str, body: GarmentUpdate, user=Depends(get_current_user)
):
    update_data = body.model_dump(exclude_none=True)
    result = (
        supabase.table("garments")
        .update(update_data)
        .eq("id", garment_id)
        .eq("user_id", user["user_id"])
        .execute()
    )
    if not result.data:
        raise NotFoundError("Garment")
    return format_success(result.data[0])


@router.delete("/{garment_id}")
async def delete_garment(garment_id: str, user=Depends(get_current_user)):
    log = logger.bind(module="garments", user_id=user["user_id"])
    supabase.table("garments").delete().eq("id", garment_id).eq(
        "user_id", user["user_id"]
    ).execute()
    log.info("garment_deleted", garment_id=garment_id)
    return format_success({"status": "deleted"})


@router.post("/{garment_id}/enhance")
async def enhance_garment(
    garment_id: str,
    background_tasks: BackgroundTasks,
    skip: bool = Query(False, description="Skip AI photo enhancement — just generate thumbnail from current display"),
    user=Depends(get_current_user),
):
    """
    Trigger background product-photo enhancement for a garment.

    Called by the client after the user saves a newly uploaded garment.
    - skip=false (default): generate a pressed, clean product photo via Gemini
      and replace the placeholder display image.
    - skip=true: generate a thumbnail from the current (original) display and
      mark the garment as ready — no AI image generation.

    Returns immediately; the heavy work runs in the background.
    """
    log = logger.bind(module="garments", user_id=user["user_id"])

    garment_result = (
        supabase.table("garments")
        .select("id, display_image_url, thumbnail_url")
        .eq("id", garment_id)
        .eq("user_id", user["user_id"])
        .maybe_single()
        .execute()
    )
    if not garment_result.data:
        raise NotFoundError("Garment")

    garment = garment_result.data

    # Already fully processed — nothing to do
    if garment.get("thumbnail_url"):
        return format_success({"status": "already_processed"})

    # Derive storage paths from the display URL
    # URL shape: .../dresser-display/USER_ID/BASE_NAME_display.jpg
    display_url = garment.get("display_image_url", "")
    match = re.search(r"dresser-display/(.+?)_display\.jpg", display_url)
    if not match:
        raise AppError("Cannot determine storage path from display URL.", status_code=500, error_code="STORAGE_PATH_ERROR")

    storage_prefix = match.group(1)          # "USER_ID/BASE_NAME"
    base_name = storage_prefix.split("/")[-1]  # "BASE_NAME"
    user_id = user["user_id"]

    if skip:
        # Fast path: just generate thumbnail from the current display (no Gemini image gen)
        async def _thumbnail_only() -> None:
            try:
                raw = supabase.storage.from_("dresser-display").download(f"{storage_prefix}_display.jpg")
                thumb_bytes = generate_thumbnail(raw)
                thumb_path = f"{user_id}/{base_name}_thumb.png"
                supabase.storage.from_("dresser-thumbnails").upload(thumb_path, thumb_bytes, {"content-type": "image/png"})
                thumb_url = supabase.storage.from_("dresser-thumbnails").get_public_url(thumb_path)
                supabase.table("garments").update({"thumbnail_url": thumb_url}).eq("id", garment_id).execute()
                log.info("enhance_thumbnail_only_done", garment_id=garment_id)
            except Exception as exc:
                log.error("enhance_thumbnail_only_failed", garment_id=garment_id, error=str(exc))

        background_tasks.add_task(_thumbnail_only)
        log.info("enhance_skip_queued", garment_id=garment_id)
        return format_success({"status": "queued", "mode": "thumbnail_only"})

    # Full path: download original → generate product photo → update
    async def _full_enhance() -> None:
        try:
            original_path = f"{user_id}/{base_name}_original.jpg"
            image_bytes = await asyncio.to_thread(
                supabase.storage.from_("dresser-originals").download, original_path
            )
            await _background_photo_job(image_bytes, user_id, garment_id, base_name)
        except Exception as exc:
            log.error("enhance_full_failed", garment_id=garment_id, error=str(exc))

    background_tasks.add_task(_full_enhance)
    log.info("enhance_full_queued", garment_id=garment_id)
    return format_success({"status": "queued", "mode": "full_enhancement"})


@router.post("/{garment_id}/worn")
async def log_worn(garment_id: str, user=Depends(get_current_user)):
    result = (
        supabase.table("garments")
        .select("times_worn")
        .eq("id", garment_id)
        .eq("user_id", user["user_id"])
        .single()
        .execute()
    )
    if not result.data:
        raise NotFoundError("Garment")

    times_worn = (result.data.get("times_worn") or 0) + 1
    supabase.table("garments").update(
        {"times_worn": times_worn, "last_worn_date": str(date.today())}
    ).eq("id", garment_id).execute()
    return format_success({"times_worn": times_worn})
