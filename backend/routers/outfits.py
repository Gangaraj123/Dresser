from __future__ import annotations

import asyncio
from datetime import date

from fastapi import APIRouter, Depends

from dependencies import get_current_user
from errors import NotFoundError
from logger import logger
from models.schemas import OutfitCreate, OutfitUpdate
from services.firebase_service import send_push
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/outfits", tags=["outfits"])


@router.get("")
async def list_outfits(user=Depends(get_current_user)):
    result = (
        supabase.table("outfits")
        .select("*")
        .eq("user_id", user["user_id"])
        .order("created_at", desc=True)
        .execute()
    )
    return format_success(result.data)


@router.post("")
async def create_outfit(body: OutfitCreate, user=Depends(get_current_user)):
    record = {"user_id": user["user_id"], **body.model_dump()}
    result = supabase.table("outfits").insert(record).execute()
    outfit = result.data[0]
    log = logger.bind(module="outfits", user_id=user["user_id"])
    log.info("outfit_created", outfit_id=outfit.get("id"))

    # Fire-and-forget confirmation push
    asyncio.create_task(_notify_outfit_saved(user["user_id"], outfit["name"]))
    return format_success(outfit)


async def _notify_outfit_saved(user_id: str, outfit_name: str) -> None:
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
        result = await send_push(
            fcm_token=token,
            title="Outfit saved",
            body=f'"{outfit_name}" has been added to your outfits.',
            data={"type": "outfit_saved"},
        )
        if result.get("should_delete_token"):
            supabase.table("profiles").update({"fcm_token": None}).eq("id", user_id).execute()
    except Exception as exc:
        logger.warning("notify_outfit_saved_failed", error=str(exc))


@router.put("/{outfit_id}")
async def update_outfit(
    outfit_id: str, body: OutfitUpdate, user=Depends(get_current_user)
):
    update_data = body.model_dump(exclude_none=True)
    result = (
        supabase.table("outfits")
        .update(update_data)
        .eq("id", outfit_id)
        .eq("user_id", user["user_id"])
        .execute()
    )
    if not result.data:
        raise NotFoundError("Outfit")
    return format_success(result.data[0])


@router.delete("/{outfit_id}")
async def delete_outfit(outfit_id: str, user=Depends(get_current_user)):
    supabase.table("outfits").delete().eq("id", outfit_id).eq(
        "user_id", user["user_id"]
    ).execute()
    return format_success({"status": "deleted"})


@router.post("/{outfit_id}/worn")
async def log_outfit_worn(outfit_id: str, user=Depends(get_current_user)):
    result = (
        supabase.table("outfits")
        .select("times_worn, garment_ids")
        .eq("id", outfit_id)
        .eq("user_id", user["user_id"])
        .single()
        .execute()
    )
    if not result.data:
        raise NotFoundError("Outfit")

    times_worn = (result.data.get("times_worn") or 0) + 1
    today = str(date.today())

    supabase.table("outfits").update(
        {"times_worn": times_worn, "last_worn_date": today}
    ).eq("id", outfit_id).execute()

    for gid in result.data.get("garment_ids") or []:
        g = (
            supabase.table("garments")
            .select("times_worn")
            .eq("id", gid)
            .single()
            .execute()
        )
        if g.data:
            supabase.table("garments").update(
                {
                    "times_worn": (g.data.get("times_worn") or 0) + 1,
                    "last_worn_date": today,
                }
            ).eq("id", gid).execute()

    return format_success({"times_worn": times_worn})
