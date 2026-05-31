from __future__ import annotations

from collections import Counter
from datetime import date, timedelta

from fastapi import APIRouter, Depends

from dependencies import get_current_user
from logger import logger
from services.gemini_service import analyze_wardrobe_insights
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/discover", tags=["discover"])


@router.get("/insights")
async def get_insights(user=Depends(get_current_user)):
    """
    Single endpoint that powers the entire Discover tab.
    Fetches garment + profile data, pre-computes forgotten items and colour
    breakdown in Python, then delegates narrative/suggestion work to Gemini.
    """
    log = logger.bind(module="discover", user_id=user["user_id"])

    garments_result = (
        supabase.table("garments")
        .select(
            "id,category,sub_category,dominant_color_hex,dominant_color_name,"
            "color_family,formality_score,season_suitability,"
            "times_worn,last_worn_date,thumbnail_url,display_image_url"
        )
        .eq("user_id", user["user_id"])
        .eq("status", "active")
        .order("created_at", desc=True)
        .execute()
    )

    profile_result = (
        supabase.table("profiles")
        .select("seasonal_type,style_preferences")
        .eq("id", user["user_id"])
        .maybe_single()
        .execute()
    )

    garments = garments_result.data or []
    profile = profile_result.data or {}
    log.info("discover_insights_started", garment_count=len(garments))

    # ── Pre-compute forgotten items (Python, not Gemini) ──────────────────
    cutoff = date.today() - timedelta(days=30)
    forgotten_ids = [
        g["id"]
        for g in garments
        if (
            g.get("last_worn_date") is None
            or (
                isinstance(g["last_worn_date"], str)
                and g["last_worn_date"] < str(cutoff)
            )
        )
        and (g.get("times_worn") or 0) == 0
        or (
            g.get("last_worn_date")
            and isinstance(g["last_worn_date"], str)
            and g["last_worn_date"] < str(cutoff)
        )
    ]

    # ── Pre-compute colour family breakdown (Python, not Gemini) ─────────
    family_counts = Counter(
        g.get("color_family") or "unknown" for g in garments
    )
    total = len(garments) or 1
    color_breakdown = [
        {
            "color_family": family,
            "count": count,
            "percentage": round(count / total * 100),
        }
        for family, count in family_counts.most_common()
    ]

    if not garments:
        return format_success({
            "gaps": [],
            "forgotten_items": [],
            "untried_combinations": [],
            "color_balance": {"breakdown": color_breakdown, "recommendation": None},
            "weekly_tip": None,
            "garment_thumbnails": {},
        })

    # ── Single Gemini call for all narrative/suggestion work ──────────────
    insights = await analyze_wardrobe_insights(
        garments=garments,
        profile=profile,
        forgotten_ids=forgotten_ids[:10],   # cap to avoid huge prompts
        color_breakdown=color_breakdown,
    )

    # Build thumbnail map so the Flutter client can show images without extra calls
    thumbnail_map = {
        g["id"]: g.get("thumbnail_url") or g.get("display_image_url")
        for g in garments
    }

    # Attach days_since_worn to forgotten items for the Flutter side
    forgotten_details = []
    for item in insights.get("forgotten_suggestions", []):
        gid = item.get("garment_id")
        garment = next((g for g in garments if g["id"] == gid), None)
        if not garment:
            continue
        lwd = garment.get("last_worn_date")
        if lwd:
            try:
                days = (date.today() - date.fromisoformat(str(lwd))).days
            except ValueError:
                days = None
        else:
            days = None
        forgotten_details.append({
            **item,
            "days_since_worn": days,
            "times_worn": garment.get("times_worn", 0),
            "category": garment.get("category"),
            "sub_category": garment.get("sub_category"),
        })

    log.info("discover_insights_completed")
    return format_success({
        "gaps": insights.get("gaps", []),
        "forgotten_items": forgotten_details,
        "untried_combinations": insights.get("untried_combinations", []),
        "color_balance": {
            "breakdown": color_breakdown,
            "recommendation": insights.get("color_recommendation"),
        },
        "weekly_tip": insights.get("weekly_tip"),
        "garment_thumbnails": thumbnail_map,
    })
