from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Profile schemas
# ---------------------------------------------------------------------------

class StylePreference(str, Enum):
    minimalist = "minimalist"
    classic = "classic"
    streetwear = "streetwear"
    bohemian = "bohemian"
    sporty = "sporty"
    romantic = "romantic"


class ColorSwatch(BaseModel):
    hex: str
    name: str


class ProfileResponse(BaseModel):
    id: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    style_preferences: Optional[list[StylePreference]] = None
    skin_undertone: Optional[str] = None
    seasonal_type: Optional[str] = None
    power_colors: Optional[list[ColorSwatch]] = None
    neutral_colors: Optional[list[ColorSwatch]] = None
    avoid_colors: Optional[list[ColorSwatch]] = None
    color_aware_recommendations: bool = True
    weather_aware_styling: bool = True
    repeat_detection: bool = True
    created_at: datetime


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    style_preferences: Optional[list[StylePreference]] = None
    color_aware_recommendations: Optional[bool] = None
    weather_aware_styling: Optional[bool] = None
    repeat_detection: Optional[bool] = None


# ---------------------------------------------------------------------------
# Garment schemas
# ---------------------------------------------------------------------------

class GarmentCategory(str, Enum):
    topwear = "topwear"
    bottomwear = "bottomwear"
    footwear = "footwear"
    outerwear = "outerwear"
    accessory = "accessory"


class GarmentStatus(str, Enum):
    active = "active"
    laundry = "laundry"
    retired = "retired"
    donated = "donated"


class ColorData(BaseModel):
    hex: str
    percentage: float
    name: str


class GarmentResponse(BaseModel):
    id: str
    category: GarmentCategory
    sub_category: Optional[str] = None
    display_image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    colors: list[ColorData] = []
    dominant_color_hex: Optional[str] = None
    dominant_color_name: Optional[str] = None
    pattern: Optional[str] = None
    fabric: Optional[str] = None
    formality_score: Optional[int] = None
    season_suitability: Optional[list[str]] = None
    user_name: Optional[str] = None
    brand: Optional[str] = None
    purchase_price: Optional[float] = None
    status: GarmentStatus = GarmentStatus.active
    times_worn: int = 0
    last_worn_date: Optional[date] = None
    ai_confidence: Optional[float] = None
    skin_compatibility_score: Optional[int] = None
    created_at: datetime


class GarmentUpdate(BaseModel):
    category: Optional[GarmentCategory] = None
    sub_category: Optional[str] = None
    pattern: Optional[str] = None
    fabric: Optional[str] = None
    formality_score: Optional[int] = None
    season_suitability: Optional[list[str]] = None
    user_name: Optional[str] = None
    brand: Optional[str] = None
    purchase_price: Optional[float] = None
    status: Optional[GarmentStatus] = None
    notes: Optional[str] = None
    custom_tags: Optional[list[str]] = None


class WardrobeStats(BaseModel):
    total: int
    topwear: int
    bottomwear: int
    footwear: int
    outerwear: int
    accessory: int
    total_value: Optional[float] = None
    most_worn_id: Optional[str] = None
    least_worn_id: Optional[str] = None


# ---------------------------------------------------------------------------
# Outfit schemas
# ---------------------------------------------------------------------------

class OutfitResponse(BaseModel):
    id: str
    name: str
    occasion: Optional[str] = None
    garment_ids: list[str] = []
    garments: Optional[list[GarmentResponse]] = None
    ai_generated: bool = False
    ai_reasoning: Optional[str] = None
    match_score: Optional[int] = None
    times_worn: int = 0
    last_worn_date: Optional[date] = None
    is_favorite: bool = False
    created_at: datetime


class OutfitCreate(BaseModel):
    name: str
    occasion: Optional[str] = None
    garment_ids: list[str]
    is_favorite: bool = False


class OutfitUpdate(BaseModel):
    name: Optional[str] = None
    occasion: Optional[str] = None
    garment_ids: Optional[list[str]] = None
    is_favorite: Optional[bool] = None


# ---------------------------------------------------------------------------
# Stylist schemas
# ---------------------------------------------------------------------------

class StylistRecommendRequest(BaseModel):
    event_description: str
    dress_code: Optional[str] = None
    location: Optional[str] = None
    date: Optional[str] = None


class ChatRequest(BaseModel):
    message: str
    conversation_history: Optional[list[dict]] = []


class OutfitSuggestion(BaseModel):
    name: str
    garment_ids: list[str]
    match_score: int
    reasoning: str


class StylistRecommendResponse(BaseModel):
    outfits: list[OutfitSuggestion]
    event_summary: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    outfit_suggestions: Optional[list[OutfitSuggestion]] = None


# ---------------------------------------------------------------------------
# Event schemas
# ---------------------------------------------------------------------------

class EventCreate(BaseModel):
    event_date: date
    description: Optional[str] = None
    dress_code: Optional[str] = None
    location: Optional[str] = None
    outfit_id: Optional[str] = None


class EventResponse(BaseModel):
    id: str
    event_date: date
    description: Optional[str] = None
    dress_code: Optional[str] = None
    location: Optional[str] = None
    outfit_id: Optional[str] = None
    created_at: datetime
