"""
wardrobe_nudges.py
==================
Two scheduled tasks:

  forgotten_garment_nudge — daily at 10:00 local time
    Picks one garment the user hasn't worn in 30+ days (or never) and
    surfaces it with a styling suggestion.

  weekly_insight_nudge — every Sunday at 18:00 local time
    Sends a short wardrobe summary: outfits worn this week + a tip.
"""
from __future__ import annotations

import asyncio
import random
from datetime import datetime, timedelta

import pytz

from logger import logger
from services.firebase_service import send_push
from services.supabase_client import supabase

_log = logger.bind(module="wardrobe_nudges")

_FORGOTTEN_NUDGE_TIME  = "10:00"
_WEEKLY_INSIGHT_TIME   = "18:00"
_FORGOTTEN_THRESHOLD   = 30   # days without wear


# ---------------------------------------------------------------------------
# Forgotten garment nudge
# ---------------------------------------------------------------------------

async def _forgotten_nudge_for_user(user: dict) -> None:
    user_id = user["id"]
    log = _log.bind(user_id=user_id)

    try:
        cutoff = (datetime.now() - timedelta(days=_FORGOTTEN_THRESHOLD)).date().isoformat()

        garments = (
            supabase.table("garments")
            .select("id,sub_category,category,last_worn_date,dominant_color_name")
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
        ).data

        forgotten = [
            g for g in garments
            if not g.get("last_worn_date") or str(g["last_worn_date"]) < cutoff
        ]
        if not forgotten:
            return

        pick = random.choice(forgotten)
        name = pick.get("sub_category") or pick.get("category", "garment")
        color = pick.get("dominant_color_name", "")
        label = f"{color} {name}".strip().capitalize()

        days = None
        if pick.get("last_worn_date"):
            last = datetime.fromisoformat(str(pick["last_worn_date"]))
            days = (datetime.now() - last).days

        body = (
            f"Your {label} hasn't been worn in {days} days. Time to bring it back?"
            if days else
            f"Your {label} has never been worn. Style it today?"
        )

        result = await send_push(
            fcm_token=user["fcm_token"],
            title="Forgotten in your wardrobe",
            body=body,
            data={
                "type": "forgotten_garment",
                "garment_id": pick["id"],
            },
        )
        if result.get("should_delete_token"):
            supabase.table("profiles").update({"fcm_token": None}).eq("id", user_id).execute()

        log.info("forgotten_nudge_sent", garment_id=pick["id"])

    except Exception as exc:
        log.error("forgotten_nudge_failed", error=str(exc))


async def run_forgotten_garment_nudges() -> None:
    """Called every minute by the scheduler. Fires for users whose local time is 10:00."""
    now_utc = datetime.now(pytz.utc)

    resp = (
        supabase.table("profiles")
        .select("id,fcm_token,notification_timezone")
        .eq("daily_notification_enabled", True)
        .not_.is_("fcm_token", "null")
        .execute()
    )

    due = _users_at_local_time(resp.data, now_utc, _FORGOTTEN_NUDGE_TIME)
    if due:
        _log.info("forgotten_nudge_batch", user_count=len(due))
        await asyncio.gather(*[_forgotten_nudge_for_user(u) for u in due], return_exceptions=True)


# ---------------------------------------------------------------------------
# Weekly wardrobe insight
# ---------------------------------------------------------------------------

async def _weekly_insight_for_user(user: dict) -> None:
    user_id = user["id"]
    log = _log.bind(user_id=user_id)

    try:
        week_ago = (datetime.now() - timedelta(days=7)).date().isoformat()

        # Outfits worn this week
        outfits = (
            supabase.table("outfits")
            .select("name,times_worn")
            .eq("user_id", user_id)
            .gte("last_worn_date", week_ago)
            .execute()
        ).data

        # Total active garments
        garment_count = len(
            supabase.table("garments")
            .select("id")
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
            .data
        )

        worn_count = len(outfits)
        if worn_count == 0:
            body = (
                f"You haven't logged any outfits this week. "
                f"Try your AI stylist to find a look from your {garment_count} pieces."
            )
        else:
            top = max(outfits, key=lambda o: o.get("times_worn", 0))
            body = (
                f"{worn_count} outfit{'s' if worn_count > 1 else ''} this week. "
                f"Most worn: {top['name']}. See your full wardrobe insights."
            )

        result = await send_push(
            fcm_token=user["fcm_token"],
            title="Your weekly wardrobe recap",
            body=body,
            data={
                "type": "weekly_insight",
                "outfits_worn": str(worn_count),
            },
        )
        if result.get("should_delete_token"):
            supabase.table("profiles").update({"fcm_token": None}).eq("id", user_id).execute()

        log.info("weekly_insight_sent", outfits_worn=worn_count)

    except Exception as exc:
        log.error("weekly_insight_failed", error=str(exc))


async def run_weekly_insight_nudges() -> None:
    """Called every minute. Fires on Sunday at 18:00 local time."""
    now_utc = datetime.now(pytz.utc)

    resp = (
        supabase.table("profiles")
        .select("id,fcm_token,notification_timezone")
        .eq("daily_notification_enabled", True)
        .not_.is_("fcm_token", "null")
        .execute()
    )

    due = [
        u for u in _users_at_local_time(resp.data, now_utc, _WEEKLY_INSIGHT_TIME)
        if _is_sunday_for_user(u, now_utc)
    ]

    if due:
        _log.info("weekly_insight_batch", user_count=len(due))
        await asyncio.gather(*[_weekly_insight_for_user(u) for u in due], return_exceptions=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _users_at_local_time(users: list[dict], now_utc: datetime, target_hhmm: str) -> list[dict]:
    result = []
    for user in users:
        tz_name = user.get("notification_timezone") or "Asia/Kolkata"
        try:
            tz = pytz.timezone(tz_name)
        except Exception:
            tz = pytz.timezone("Asia/Kolkata")
        if now_utc.astimezone(tz).strftime("%H:%M") == target_hhmm:
            result.append(user)
    return result


def _is_sunday_for_user(user: dict, now_utc: datetime) -> bool:
    tz_name = user.get("notification_timezone") or "Asia/Kolkata"
    try:
        tz = pytz.timezone(tz_name)
    except Exception:
        tz = pytz.timezone("Asia/Kolkata")
    return now_utc.astimezone(tz).weekday() == 6  # 6 = Sunday
