from __future__ import annotations

from fastapi import APIRouter, Depends

from dependencies import get_current_user
from errors import AppError
from services.firebase_service import send_push
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


@router.post("/token")
async def save_fcm_token(body: dict, user=Depends(get_current_user)):
    """Called by Flutter on startup / token refresh to store the FCM token."""
    token = body.get("token")
    if not token:
        raise AppError("token is required", status_code=422, error_code="MISSING_TOKEN")
    supabase.table("profiles").update({"fcm_token": token}).eq("id", user["user_id"]).execute()
    return format_success({"status": "saved"})


@router.delete("/token")
async def clear_fcm_token(user=Depends(get_current_user)):
    """Called on logout to stop notifications."""
    supabase.table("profiles").update({"fcm_token": None}).eq("id", user["user_id"]).execute()
    return format_success({"status": "cleared"})


@router.post("/settings")
async def update_notification_settings(body: dict, user=Depends(get_current_user)):
    """Update daily notification preferences."""
    update: dict = {}
    if "enabled" in body:
        update["daily_notification_enabled"] = bool(body["enabled"])
    if "time" in body:
        update["daily_notification_time"] = body["time"]   # "HH:MM"
    if "timezone" in body:
        update["notification_timezone"] = body["timezone"]
    if update:
        supabase.table("profiles").update(update).eq("id", user["user_id"]).execute()
    return format_success({"status": "updated"})


@router.post("/test")
async def send_test_notification(user=Depends(get_current_user)):
    """Dev helper — sends a test push to the current user's device."""
    profile = (
        supabase.table("profiles")
        .select("fcm_token")
        .eq("id", user["user_id"])
        .maybe_single()
        .execute()
    )
    token = (profile.data or {}).get("fcm_token")
    if not token:
        raise AppError(
            "No FCM token found. Open the app and allow notifications first.",
            status_code=404,
            error_code="NO_TOKEN",
        )
    result = await send_push(
        fcm_token=token,
        title="Dresser notification test",
        body="Notifications are working correctly.",
        data={"type": "test"},
    )
    return format_success(result)
