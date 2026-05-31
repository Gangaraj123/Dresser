from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends

from dependencies import get_current_user
from logger import logger
from models.schemas import ChatRequest, StylistRecommendRequest
from services.gemini_service import chat_stylist, recommend_outfits
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/stylist", tags=["stylist"])


def _fetch_garments(user_id: str) -> list[dict]:
    return (
        supabase.table("garments")
        .select(
            "id,category,sub_category,dominant_color_hex,dominant_color_name,"
            "colors,formality_score,season_suitability,fabric,pattern,"
            "skin_compatibility_score,times_worn,last_worn_date"
        )
        .eq("user_id", user_id)
        .eq("status", "active")
        .execute()
    ).data


def _fetch_profile(user_id: str) -> dict:
    result = (
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
    return result.data or {}


@router.post("/recommend")
async def get_recommendations(
    body: StylistRecommendRequest, user=Depends(get_current_user)
):
    log = logger.bind(module="stylist", user_id=user["user_id"])
    log.info("recommend_outfits_started", event=body.event_description)

    garments, profile = await asyncio.gather(
        asyncio.to_thread(_fetch_garments, user["user_id"]),
        asyncio.to_thread(_fetch_profile, user["user_id"]),
    )

    result = await recommend_outfits(
        event_description=body.event_description,
        dress_code=body.dress_code,
        location=body.location,
        date=body.date,
        garments=garments,
        user_profile=profile,
    )
    log.info("recommend_outfits_completed", outfit_count=len(result.get("outfits", [])))
    return format_success(result)


@router.post("/chat")
async def stylist_chat(body: ChatRequest, user=Depends(get_current_user)):
    log = logger.bind(module="stylist", user_id=user["user_id"])
    log.debug("stylist_chat_started")

    garments, profile = await asyncio.gather(
        asyncio.to_thread(_fetch_garments, user["user_id"]),
        asyncio.to_thread(_fetch_profile, user["user_id"]),
    )

    result = await chat_stylist(
        message=body.message,
        conversation_history=body.conversation_history or [],
        garments=garments,
        user_profile=profile,
    )
    return format_success(result)
