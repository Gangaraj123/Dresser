from __future__ import annotations

from calendar import monthrange

from fastapi import APIRouter, Depends, Query

from dependencies import get_current_user
from models.schemas import EventCreate
from services.supabase_client import supabase
from utils.response_formatter import format_success

router = APIRouter(prefix="/api/v1/events", tags=["events"])


@router.get("")
async def list_events(
    month: str | None = Query(None, description="Format: 2026-03"),
    user=Depends(get_current_user),
):
    query = (
        supabase.table("events")
        .select("*")
        .eq("user_id", user["user_id"])
    )
    if month:
        year, mon = month.split("-")
        _, last_day = monthrange(int(year), int(mon))
        query = query.gte("event_date", f"{month}-01").lte(
            "event_date", f"{month}-{last_day:02d}"
        )
    result = query.order("event_date", desc=True).execute()
    return format_success(result.data)


@router.post("")
async def create_event(body: EventCreate, user=Depends(get_current_user)):
    record = {"user_id": user["user_id"], **body.model_dump(mode="json")}
    result = supabase.table("events").insert(record).execute()
    return format_success(result.data[0])
