"""
daily_outfit.py — Runs every minute; sends daily outfit push notifications
to users whose local time matches their chosen notification time.
"""
from __future__ import annotations

import asyncio
import json
from datetime import datetime, timedelta

import pytz

from logger import logger
from services.firebase_service import send_push
from services.gemini_service import recommend_outfits
from services.supabase_client import supabase

_log = logger.bind(module="daily_outfit")


async def _send_to_user(user: dict) -> None:
    user_id = user["id"]
    log = _log.bind(user_id=user_id)

    try:
        # 1. Fetch active garments
        garments = (
            supabase.table("garments")
            .select(
                "id,category,sub_category,dominant_color_hex,dominant_color_name,"
                "formality_score,season_suitability,fabric,pattern,"
                "skin_compatibility_score,times_worn,last_worn_date"
            )
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
        ).data

        if len(garments) < 3:
            log.debug("daily_outfit_skipped", reason="too_few_garments", count=len(garments))
            return

        # 2. Fetch profile
        profile_result = (
            supabase.table("profiles")
            .select(
                "seasonal_type,skin_undertone,contrast_level,style_preferences,"
                "power_colors,neutral_colors,avoid_colors,"
                "color_aware_recommendations,weather_aware_styling,repeat_detection"
            )
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        profile = profile_result.data or {}

        # 3. Generate outfit recommendation
        today = datetime.now().strftime("%A, %B %d")
        result = await recommend_outfits(
            event_description=f"Regular day — {today}. Suggest a stylish, comfortable everyday outfit.",
            dress_code=None,
            location=None,
            date=today,
            garments=garments,
            user_profile=profile,
        )

        outfits = result.get("outfits", [])
        if not outfits:
            log.info("daily_outfit_no_suggestion")
            return

        top = outfits[0]
        garment_ids_str = ",".join(top.get("garment_ids", []))

        # 4. Send push
        push_result = await send_push(
            fcm_token=user["fcm_token"],
            title="Your outfit for today",
            body=top.get("reasoning", top["name"])[:100],
            data={
                "type": "daily_outfit",
                "outfit_name": top["name"],
                "outfit_garment_ids": garment_ids_str,
                "match_score": str(top.get("match_score", 0)),
            },
        )

        # 5. Clear invalid token so we don't retry
        if push_result.get("should_delete_token"):
            supabase.table("profiles").update({"fcm_token": None}).eq("id", user_id).execute()

        log.info("daily_outfit_sent", outfit_name=top["name"])

    except Exception as exc:
        log.error("daily_outfit_failed", error=str(exc))


async def run_daily_notifications() -> None:
    """
    Called every minute by the scheduler.
    Finds users whose local HH:MM matches their chosen notification time
    and fires outfit recommendations for them.
    """
    now_utc = datetime.now(pytz.utc)

    resp = (
        supabase.table("profiles")
        .select("id,fcm_token,daily_notification_time,notification_timezone")
        .eq("daily_notification_enabled", True)
        .not_.is_("fcm_token", "null")
        .not_.is_("daily_notification_time", "null")
        .execute()
    )

    due: list[dict] = []
    for user in resp.data:
        tz_name = user.get("notification_timezone") or "Asia/Kolkata"
        try:
            tz = pytz.timezone(tz_name)
        except Exception:
            tz = pytz.timezone("Asia/Kolkata")

        user_now = now_utc.astimezone(tz)
        target = str(user["daily_notification_time"])[:5]  # "HH:MM"
        if user_now.strftime("%H:%M") == target:
            due.append(user)

    if due:
        _log.info("daily_outfit_batch_started", user_count=len(due))
        await asyncio.gather(*[_send_to_user(u) for u in due], return_exceptions=True)
