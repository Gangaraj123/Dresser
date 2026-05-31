from fastapi import APIRouter, Depends, UploadFile, File

from dependencies import get_current_user
from errors import NotFoundError
from logger import logger
from models.schemas import ProfileUpdate
from services.gemini_service import analyze_skin_tone
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/profile", tags=["profile"])


@router.get("")
async def get_profile(user=Depends(get_current_user)):
    result = supabase.table("profiles").select("*").eq("id", user["user_id"]).maybe_single().execute()
    if not result.data:
        raise NotFoundError("Profile")
    return format_success(result.data)


@router.put("")
async def update_profile(body: ProfileUpdate, user=Depends(get_current_user)):
    update_data = body.model_dump(exclude_none=True)
    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", user["user_id"])
        .execute()
    )
    if not result.data:
        raise NotFoundError("Profile")
    return format_success(result.data[0])


@router.post("/analyze-color")
async def analyze_color(file: UploadFile = File(...), user=Depends(get_current_user)):
    log = logger.bind(module="profile", user_id=user["user_id"])
    log.info("analyze_color_started")

    image_bytes = await file.read()
    color_data = await analyze_skin_tone(image_bytes)
    supabase.table("profiles").update(color_data).eq("id", user["user_id"]).execute()

    log.info("analyze_color_completed", seasonal_type=color_data.get("seasonal_type"))
    return format_success(color_data)


@router.delete("/color-data")
async def delete_color_data(user=Depends(get_current_user)):
    fields = {
        "skin_undertone": None,
        "skin_depth": None,
        "hair_tone": None,
        "eye_color": None,
        "contrast_level": None,
        "seasonal_type": None,
        "power_colors": None,
        "neutral_colors": None,
        "avoid_colors": None,
    }
    supabase.table("profiles").update(fields).eq("id", user["user_id"]).execute()
    return format_success({"status": "deleted"})
