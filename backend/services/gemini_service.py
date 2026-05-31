from __future__ import annotations

import io
import json
import time

from google import genai
from google.genai import types
from PIL import Image

from config import settings
from logger import logger

client = genai.Client(api_key=settings.gemini_api_key)

_MODEL = settings.gemini_model  # set via GEMINI_MODEL in .env

_log = logger.bind(module="gemini_service")


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _pil_from_bytes(image_bytes: bytes) -> Image.Image:
    return Image.open(io.BytesIO(image_bytes))


# AFC disabled — we never define tools, so the default 10-round AFC loop
# is pure wasted latency.
_NO_AFC = types.AutomaticFunctionCallingConfig(disable=True)

# Thinking budget for stylist calls: enough for outfit reasoning without
# the uncapped default that can burn 8k+ thinking tokens on long prompts.
_STYLIST_THINKING_BUDGET = 512


def _make_config(*, thinking_budget: int | None = None) -> types.GenerateContentConfig:
    cfg: dict = {"automatic_function_calling": _NO_AFC}
    if thinking_budget is not None:
        cfg["thinking_config"] = types.ThinkingConfig(thinkingBudget=thinking_budget)
    return types.GenerateContentConfig(**cfg)


def _call_vision(contents: list, label: str, *, thinking_budget: int | None = None) -> str:
    """Call the vision model (sync), log latency, return response text."""
    start = time.monotonic()
    response = client.models.generate_content(
        model=_MODEL,
        contents=contents,
        config=_make_config(thinking_budget=thinking_budget),
    )
    latency_ms = round((time.monotonic() - start) * 1000, 2)
    _log.info("gemini_vision_call", operation=label, latency_ms=latency_ms)
    return response.text


async def _call_vision_async(contents: list, label: str, *, thinking_budget: int | None = None) -> str:
    """Non-blocking wrapper — runs the sync Gemini call in a thread pool."""
    import asyncio
    return await asyncio.to_thread(_call_vision, contents, label, thinking_budget=thinking_budget)


def _parse_json(text: str) -> dict:
    """
    Parse JSON from a Gemini response robustly:
    1. Strip markdown fences (```json ... ```)
    2. If that still fails, find the first { ... } block in the text
       (handles thinking-model preamble or trailing commentary)
    """
    original = text
    text = text.strip()

    # Strip markdown fences
    if text.startswith("```"):
        lines = text.splitlines()[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    # Fast path — clean JSON
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Fallback: extract the outermost { } block from the raw text
    # (covers thinking-model preamble, trailing "Hope that helps!", etc.)
    start = original.find("{")
    end   = original.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(original[start : end + 1])
        except json.JSONDecodeError:
            pass

    # Nothing worked — log the raw response so we can diagnose it
    _log.warning("parse_json_failed", raw_length=len(original), raw_preview=original[:300])
    raise json.JSONDecodeError("No valid JSON found in response", original, 0)


# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

_CLASSIFICATION_PROMPT = """Analyze this photo of a garment. Return ONLY a JSON object:
{
  "garment_visible": true,
  "photo_type": "flat_lay",
  "background_complexity": "simple",
  "lighting_quality": "good",
  "can_process": true,
  "retake_reason": null
}

photo_type values: "flat_lay" | "on_hanger" | "worn_by_person" | "folded" | "unclear"
background_complexity values: "simple" | "moderate" | "complex"
lighting_quality values: "good" | "fair" | "poor"
retake_reason values: null | "too_blurry" | "garment_not_visible" | "too_dark" | "multiple_items"
can_process: false only if garment_visible is false or lighting_quality is "poor"

Return ONLY valid JSON. No markdown, no explanation, no backticks."""

_GARMENT_ANALYSIS_PROMPT = """Analyze this garment product photo and return ONLY a JSON object:
{
  "category": "topwear",
  "sub_category": "specific type, e.g. oxford shirt, slim jeans, chelsea boots",
  "colors": [
    {"hex": "#5B8DBE", "name": "light blue", "percentage": 70},
    {"hex": "#FFFFFF", "name": "white", "percentage": 30}
  ],
  "dominant_color_hex": "#5B8DBE",
  "dominant_color_name": "light blue",
  "color_family": "cool",
  "pattern": "solid",
  "fabric": "cotton",
  "formality_score": 2,
  "season_suitability": ["spring", "summer"],
  "brand": null,
  "confidence": 0.95
}

category values: "topwear" | "bottomwear" | "footwear" | "outerwear" | "accessory"
color_family values: "cool" | "warm" | "neutral"
pattern values: "solid" | "striped" | "floral" | "plaid" | "abstract" | "geometric" | "checkered" | "polka_dot"
fabric values: "cotton" | "silk" | "denim" | "wool" | "synthetic" | "linen" | "leather" | "knit" | "chiffon" | "velvet"
formality_score: integer 1-5 (1=very casual, 5=black tie formal)
season_suitability: array of one or more: "spring" | "summer" | "autumn" | "winter" | "all-season"

IMPORTANT: Return ONLY valid JSON. No markdown, no explanation, no backticks."""

SKIN_TONE_PROMPT = """You are an expert personal colour analyst trained in seasonal colour theory.

Analyse the person's skin tone, hair colour, and eye colour in this selfie image and return a JSON object:

{
  "skin_undertone": "<warm, cool, or neutral>",
  "skin_depth": "<one of: fair, light, medium, tan, deep>",
  "hair_tone": "<e.g. warm blonde, ash brown, jet black, silver, auburn>",
  "eye_color": "<e.g. blue, hazel, dark brown, green, grey>",
  "contrast_level": "<one of: low, medium, high>",
  "seasonal_type": "<one of: spring, summer, autumn, winter>",
  "power_colors": [{"hex": "#XXXXXX", "name": "<colour name>"}],
  "neutral_colors": [{"hex": "#XXXXXX", "name": "<colour name>"}],
  "avoid_colors": [{"hex": "#XXXXXX", "name": "<colour name>"}]
}

Power colours: 4-6 hex values. Neutral colours: 3-5 basics. Avoid colours: 3-5 hex values.

Return ONLY valid JSON. No markdown, no explanation, no backticks."""


# ---------------------------------------------------------------------------
# Step 1: Classify input photo
# ---------------------------------------------------------------------------

async def classify_input(image_bytes: bytes) -> dict:
    """Classify the uploaded photo: photo type, quality, can_process."""
    _log.info("classify_input_started", image_size_bytes=len(image_bytes))
    image = _pil_from_bytes(image_bytes)
    try:
        text = await _call_vision_async([_CLASSIFICATION_PROMPT, image], "classify_input")
        result = _parse_json(text)
        _log.info(
            "classify_input_completed",
            photo_type=result.get("photo_type"),
            can_process=result.get("can_process"),
        )
        return result
    except (json.JSONDecodeError, AttributeError) as exc:
        _log.warning("classify_input_parse_failed", error=str(exc))
        return {
            "garment_visible": True,
            "photo_type": "flat_lay",
            "background_complexity": "moderate",
            "lighting_quality": "fair",
            "can_process": True,
            "retake_reason": None,
        }


# ---------------------------------------------------------------------------
# Step 2: Product photo generation (3-tier fallback)
# ---------------------------------------------------------------------------

_PRODUCT_PHOTO_PROMPT = (
    "Using the attached image as a fixed reference for colour, fabric texture, stitching, "
    "branding, and unique design elements, generate a professional marketplace product photo. "
    "Virtually steam and press the garment to remove all wrinkles, folds, and creases. "
    "Ensure the silhouette is symmetrical and presented flat-lay or on a ghost mannequin "
    "as seen on professional e-commerce listings such as Myntra. "
    "Place the garment centred on a pure #FFFFFF studio-white background with soft "
    "3-point studio lighting and a natural contact shadow on the bottom edge. "
    "Crucially: do NOT alter the branding, patterns, colour, or any unique design elements — "
    "only correct the physical state of the fabric."
)


async def generate_product_photo(image_bytes: bytes, **_) -> bytes:
    """
    Generate a clean, pressed e-commerce product photo.

    Tier 1 — Gemini 3.1 Flash Image (gemini-3.1-flash-image-preview):
        Selective-elasticity prompt: fabric type (colour, texture, pattern,
        stitching) treated as a constant; fabric state (wrinkles, folds,
        creases) treated as a variable to correct. Ghost-mannequin framing
        naturally resolves ambiguous folds by inferring 3-D geometry.

    Fallback — compressed original:
        If Gemini is unavailable the raw upload is returned as a compressed
        JPEG. A wrinkled image on a white background (rembg) is worse than
        the original in context, so we skip that step entirely.
    """
    _log.info("generate_product_photo_started", image_size_bytes=len(image_bytes))

    # ── Tier 1: Gemini 3.1 Flash Image ───────────────────────────────────────
    try:
        def _run_image_gen() -> object:
            return client.models.generate_content(
                model="gemini-3.1-flash-image-preview",
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                    _PRODUCT_PHOTO_PROMPT,
                ],
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
                ),
            )

        import asyncio as _asyncio
        start = time.monotonic()
        response = await _asyncio.to_thread(_run_image_gen)
        latency_ms = round((time.monotonic() - start) * 1000, 2)  # noqa: E501

        for part in response.candidates[0].content.parts:
            if part.inline_data is not None:
                result = part.inline_data.data
                _log.info(
                    "generate_product_photo_completed",
                    method="gemini-3.1-flash-image",
                    latency_ms=latency_ms,
                    output_bytes=len(result),
                )
                return result

        _log.warning("gemini_image_no_inline_data")
    except Exception as exc:
        _log.warning("gemini_image_gen_failed", error=str(exc), model="gemini-3.1-flash-image-preview")

    # ── Fallback: compressed original ────────────────────────────────────────
    # rembg is intentionally skipped: a wrinkled garment on a plain white
    # background looks worse than the original photo in context. Return the
    # upload compressed to the storage quality target instead.
    _log.info("generate_product_photo_falling_back", method="compressed_original")
    return compress_for_storage(image_bytes, quality=85)


# ---------------------------------------------------------------------------
# Step 3: Analyze garment metadata (run on the generated product photo)
# ---------------------------------------------------------------------------

async def analyze_garment(image_bytes: bytes) -> dict:
    """Extract structured garment metadata from the product photo."""
    _log.info("analyze_garment_started", image_size_bytes=len(image_bytes))
    image = _pil_from_bytes(image_bytes)
    try:
        text = await _call_vision_async([_GARMENT_ANALYSIS_PROMPT, image], "analyze_garment")
        result = _parse_json(text)
        if isinstance(result.get("formality_score"), (int, float)):
            result["formality_score"] = max(1, min(5, int(result["formality_score"])))
        _log.info(
            "analyze_garment_completed",
            category=result.get("category"),
            dominant_color=result.get("dominant_color_hex"),
        )
        return result
    except (json.JSONDecodeError, AttributeError) as exc:
        _log.warning("analyze_garment_parse_failed", error=str(exc))
        return {
            "category": "topwear",
            "sub_category": None,
            "colors": [],
            "dominant_color_hex": None,
            "dominant_color_name": None,
            "color_family": "neutral",
            "pattern": None,
            "fabric": None,
            "formality_score": 3,
            "season_suitability": ["spring", "summer", "autumn", "winter"],
            "brand": None,
            "confidence": 0.1,
        }


# ---------------------------------------------------------------------------
# Pillow utilities (only Pillow usage in the entire pipeline)
# ---------------------------------------------------------------------------

def compress_for_storage(image_bytes: bytes, quality: int = 85) -> bytes:
    """Convert to JPEG and compress before storing in Supabase (~150-300 KB)."""
    image = _pil_from_bytes(image_bytes).convert("RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=quality, optimize=True)
    return buffer.getvalue()


def generate_thumbnail(image_bytes: bytes, size: tuple = (300, 300)) -> bytes:
    """Resize to a 300x300 JPEG thumbnail."""
    image = _pil_from_bytes(image_bytes).convert("RGB")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=85, optimize=True)
    return buffer.getvalue()


# ---------------------------------------------------------------------------
# Skin tone analysis
# ---------------------------------------------------------------------------

async def analyze_skin_tone(image_bytes: bytes) -> dict:
    """Send selfie to Gemini, return colour profile JSON."""
    _log.info("analyze_skin_tone_started")
    image = _pil_from_bytes(image_bytes)
    try:
        text = await _call_vision_async([SKIN_TONE_PROMPT, image], "analyze_skin_tone")
        result = _parse_json(text)
        _log.info("analyze_skin_tone_completed", seasonal_type=result.get("seasonal_type"))
        return result
    except (json.JSONDecodeError, AttributeError) as exc:
        _log.warning("analyze_skin_tone_parse_failed", error=str(exc))
        return {
            "skin_undertone": None, "skin_depth": None, "hair_tone": None,
            "eye_color": None, "contrast_level": None, "seasonal_type": None,
            "power_colors": [], "neutral_colors": [], "avoid_colors": [],
        }


# ---------------------------------------------------------------------------
# Wardrobe intelligence (Discover tab — Phase 1)
# ---------------------------------------------------------------------------

async def analyze_wardrobe_insights(
    garments: list[dict],
    profile: dict,
    forgotten_ids: list[str],
    color_breakdown: list[dict],
) -> dict:
    """
    Single Gemini call that powers the entire Discover tab.
    Returns gaps, forgotten-item suggestions, untried combinations,
    a color-balance recommendation, and a weekly style tip.
    """
    garments_summary = json.dumps([
        {
            "id": g.get("id"),
            "category": g.get("category"),
            "sub_category": g.get("sub_category"),
            "dominant_color_name": g.get("dominant_color_name"),
            "color_family": g.get("color_family"),
            "dominant_color_hex": g.get("dominant_color_hex"),
            "formality_score": g.get("formality_score"),
            "season_suitability": g.get("season_suitability"),
            "times_worn": g.get("times_worn", 0),
            "last_worn_date": str(g.get("last_worn_date") or "never"),
        }
        for g in garments
    ], indent=2)

    prompt = f"""You are a wardrobe intelligence analyst. Analyse this person's wardrobe and return actionable insights.

Wardrobe ({len(garments)} active items):
{garments_summary}

User profile:
- Seasonal colour type: {profile.get("seasonal_type") or "unknown"}
- Style preferences: {profile.get("style_preferences") or "not set"}

Forgotten items (not worn in 30+ days — their IDs): {json.dumps(forgotten_ids)}
Current colour family breakdown: {json.dumps(color_breakdown)}

Return a JSON object with exactly these keys:

{{
  "gaps": [
    {{
      "category": "bottomwear",
      "description": "You have 8 tops but only 2 formal bottoms.",
      "action": "Adding dark chinos would unlock 6 new outfit combinations.",
      "priority": "high",
      "outfits_unlocked": 6
    }}
  ],
  "forgotten_suggestions": [
    {{
      "garment_id": "<id from forgotten_ids>",
      "suggestion": "Pair with your navy chinos for a smart-casual Monday look."
    }}
  ],
  "untried_combinations": [
    {{
      "garment_ids": ["<id1>", "<id2>"],
      "reasoning": "The earthy tones of both pieces complement each other perfectly.",
      "occasion": "Weekend brunch"
    }}
  ],
  "color_recommendation": "Your wardrobe leans heavily cool — one warm-toned piece like camel or terracotta would add versatility.",
  "weekly_tip": {{
    "title": "The rule of three",
    "body": "Your most-worn outfits all follow the same pattern: one neutral base, one statement piece, one grounding element. Apply this deliberately.",
    "based_on": "Your wearing patterns this month"
  }}
}}

Rules:
- gaps: 1-3 items, ordered by priority (high/medium/low)
- forgotten_suggestions: only use IDs from the provided forgotten_ids list, max 4
- untried_combinations: 2-3 pairings using actual garment IDs from the wardrobe
- color_recommendation: one sentence, specific and actionable
- weekly_tip: personalised to their actual wardrobe patterns, not generic advice

Return ONLY valid JSON. No markdown, no backticks."""

    _log.info("analyze_wardrobe_insights_started", garment_count=len(garments))
    try:
        result = _parse_json(
            await _call_vision_async([prompt], "analyze_wardrobe_insights")
        )
        _log.info(
            "analyze_wardrobe_insights_completed",
            gap_count=len(result.get("gaps", [])),
            forgotten_count=len(result.get("forgotten_suggestions", [])),
            combo_count=len(result.get("untried_combinations", [])),
        )
        return result
    except (json.JSONDecodeError, AttributeError) as exc:
        _log.warning("analyze_wardrobe_insights_parse_failed", error=str(exc))
        return {
            "gaps": [],
            "forgotten_suggestions": [],
            "untried_combinations": [],
            "color_recommendation": None,
            "weekly_tip": None,
        }


# ---------------------------------------------------------------------------
# Outfit recommendations
# ---------------------------------------------------------------------------

def _current_season() -> str:
    from datetime import datetime
    m = datetime.now().month
    if m in (3, 4, 5): return "spring"
    if m in (6, 7, 8): return "summer"
    if m in (9, 10, 11): return "autumn"
    return "winter"


async def recommend_outfits(
    event_description: str,
    dress_code: str | None,
    location: str | None,
    date: str | None,
    garments: list[dict],
    user_profile: dict,
) -> dict:
    color_aware  = user_profile.get("color_aware_recommendations", True)
    weather_aware = user_profile.get("weather_aware_styling", True)
    repeat_detect = user_profile.get("repeat_detection", False)

    from datetime import datetime as _dt, timedelta as _td
    recent_cutoff = str((_dt.now() - _td(days=7)).date())
    recently_worn = [
        g["id"] for g in garments
        if repeat_detect and g.get("last_worn_date") and str(g["last_worn_date"]) >= recent_cutoff
    ]

    garments_summary = json.dumps([
        {
            "id": g.get("id"),
            "category": g.get("category"),
            "sub_category": g.get("sub_category"),
            "dominant_color_hex": g.get("dominant_color_hex"),
            "dominant_color_name": g.get("dominant_color_name"),
            "pattern": g.get("pattern"),
            "fabric": g.get("fabric"),
            "formality_score": g.get("formality_score"),
            "season_suitability": g.get("season_suitability"),
            "skin_compatibility_score": g.get("skin_compatibility_score"),
            **( {"times_worn": g.get("times_worn", 0),
                 "last_worn_date": str(g.get("last_worn_date") or "")}
                if repeat_detect else {} ),
        }
        for g in garments
    ], separators=(",", ":"))

    profile_summary = json.dumps({
        "style_preferences": user_profile.get("style_preferences"),
        "skin_undertone": user_profile.get("skin_undertone"),
        "seasonal_type": user_profile.get("seasonal_type"),
        "contrast_level": user_profile.get("contrast_level"),
        "power_colors": user_profile.get("power_colors") or [],
        "neutral_colors": user_profile.get("neutral_colors") or [],
        "avoid_colors": user_profile.get("avoid_colors") or [],
    }, separators=(",", ":"))

    colour_rules = ""
    if color_aware and user_profile.get("seasonal_type"):
        colour_rules = """
Colour guidance (colour-aware mode ON):
- PREFER garments whose dominant_color_hex is close to any hex in power_colors
- ACCEPT garments whose dominant_color_hex is close to any hex in neutral_colors
- AVOID garments whose dominant_color_hex is close to any hex in avoid_colors unless no alternative exists
- PREFER garments with skin_compatibility_score >= 4 over those with score <= 2
"""
    else:
        colour_rules = "Colour guidance: OFF (user has not set up a colour profile or has disabled it). Choose by formality/occasion fit only.\n"

    weather_note = f"Current season: {_current_season()}. " if weather_aware else ""
    repeat_note = f"Repeat detection ON — avoid recommending these recently worn garment IDs unless explicitly asked: {recently_worn}\n" if repeat_detect and recently_worn else ""

    prompt = f"""You are Dresser, an AI personal stylist. A user needs outfit help.

Event: {event_description}
Dress code: {dress_code or "not specified"}
Location: {location or "not specified"}
Date: {date or "not specified"}
{weather_note}
User colour & style profile: {profile_summary}

Available wardrobe items (use their 'id' values in garment_ids):
{garments_summary}

{colour_rules}{repeat_note}
Task: Suggest 2-3 outfits using ONLY items from the wardrobe above.

Rules:
- Each outfit must span at least 2 different categories.
- Only suggest an outfit if you are genuinely confident it works for this occasion (match_score >= 60).
- If a combination is possible but not ideal, include it with an honest match_score (e.g. 62) and explain the caveat in reasoning.
- If NO combination in this wardrobe is suitable for this occasion, return "outfits": [] and write a helpful event_summary explaining why and what type of item is missing.
- Never invent or guess garment IDs — only use IDs from the list above.

Return a JSON object:
{{
  "event_summary": "<1-2 sentence summary, or explanation if no outfits found>",
  "outfits": [
    {{"name": "<name>", "garment_ids": ["<id1>", "<id2>"], "match_score": 85, "reasoning": "<2-3 sentences>"}}
  ]
}}

Return ONLY valid JSON. No markdown, no backticks."""

    _log.info("recommend_outfits_started", garment_count=len(garments))
    try:
        result = _parse_json(await _call_vision_async([prompt], "recommend_outfits",
                                                      thinking_budget=_STYLIST_THINKING_BUDGET))
        _log.info("recommend_outfits_completed", outfit_count=len(result.get("outfits", [])))
        return result
    except json.JSONDecodeError as exc:
        _log.warning("recommend_outfits_parse_failed", error=str(exc))
        return {"event_summary": "Unable to generate recommendations right now. Please try again.", "outfits": []}
    except Exception as exc:
        _log.error("recommend_outfits_failed", error=str(exc))
        return {"event_summary": "Unable to generate recommendations right now. Please try again.", "outfits": []}


# ---------------------------------------------------------------------------
# Free-form stylist chat
# ---------------------------------------------------------------------------

async def chat_stylist(
    message: str,
    conversation_history: list[dict],
    garments: list[dict],
    user_profile: dict,
) -> dict:
    color_aware   = user_profile.get("color_aware_recommendations", True)
    weather_aware = user_profile.get("weather_aware_styling", True)
    repeat_detect = user_profile.get("repeat_detection", False)

    from datetime import datetime as _dt, timedelta as _td
    recent_cutoff = str((_dt.now() - _td(days=7)).date())
    recently_worn = [
        g["id"] for g in garments
        if repeat_detect and g.get("last_worn_date") and str(g["last_worn_date"]) >= recent_cutoff
    ]

    garments_summary = json.dumps([
        {
            "id": g.get("id"),
            "category": g.get("category"),
            "sub_category": g.get("sub_category"),
            "dominant_color_name": g.get("dominant_color_name"),
            "formality_score": g.get("formality_score"),
            "season_suitability": g.get("season_suitability"),
            "fabric": g.get("fabric"),
            "pattern": g.get("pattern"),
            "skin_compatibility_score": g.get("skin_compatibility_score"),
            **( {"times_worn": g.get("times_worn", 0),
                 "last_worn_date": str(g.get("last_worn_date") or "")}
                if repeat_detect else {} ),
        }
        for g in garments
    ], separators=(",", ":"))

    profile_summary = json.dumps({
        "seasonal_type": user_profile.get("seasonal_type"),
        "skin_undertone": user_profile.get("skin_undertone"),
        "contrast_level": user_profile.get("contrast_level"),
        "style_preferences": user_profile.get("style_preferences"),
        "power_colors": user_profile.get("power_colors") or [],
        "neutral_colors": user_profile.get("neutral_colors") or [],
        "avoid_colors": user_profile.get("avoid_colors") or [],
    }, separators=(",", ":"))

    history_text = ""
    for turn in conversation_history[-10:]:
        history_text += f"\n{turn.get('role', 'user').capitalize()}: {turn.get('content', '')}"

    colour_rule = (
        "6. Colour guidance ON: PREFER garments with skin_compatibility_score >= 4 and colours close to power_colors. "
        "AVOID colours close to avoid_colors unless no alternative exists."
        if (color_aware and user_profile.get("seasonal_type"))
        else "6. Colour guidance OFF (no colour profile set or disabled). Choose by style/occasion fit only."
    )
    weather_rule = f"7. Weather/season awareness ON — current season is {_current_season()}. Prefer season-appropriate fabrics and layers." if weather_aware else ""
    repeat_rule = f"8. Repeat detection ON — avoid suggesting these recently worn IDs unless user explicitly asks: {recently_worn}" if repeat_detect and recently_worn else ""

    prompt = f"""You are Dresser, an AI personal stylist. You are warm, knowledgeable, and concise.

The user's wardrobe ({len(garments)} active items):
{garments_summary}

Their colour & style profile: {profile_summary}

Previous conversation:{history_text if history_text else " (none)"}

User: {message}

Rules:
1. Only suggest outfits you are genuinely confident work together for the stated occasion (match_score >= 60).
2. If the wardrobe has no suitable combination, set outfit_suggestions to [] and explain what is missing in your reply.
3. If a combination is possible but imperfect, include it with an honest match_score and note the caveat in reasoning.
4. Complete outfits: pull from ALL available categories (3-5 pieces when possible).
5. Only use garment 'id' values from the wardrobe list above — never invent IDs.
{colour_rule}
{weather_rule}
{repeat_rule}

Return a JSON object:
{{
  "reply": "<conversational reply — do NOT list garment names in plain text>",
  "outfit_suggestions": [
    {{"name": "<name>", "garment_ids": ["<id1>", "<id2>"], "match_score": 85, "reasoning": "<1-2 sentences>"}}
  ]
}}

Set "outfit_suggestions" to null ONLY for pure small-talk with zero relation to clothes.
Return ONLY valid JSON. No markdown, no backticks."""

    _log.debug("chat_stylist_started", garment_count=len(garments))
    try:
        result = _parse_json(await _call_vision_async([prompt], "chat_stylist",
                                                      thinking_budget=_STYLIST_THINKING_BUDGET))
        _log.info("chat_stylist_completed",
                  suggestion_count=len(result.get("outfit_suggestions") or []))
        return result
    except json.JSONDecodeError as exc:
        _log.warning("chat_stylist_parse_failed", error=str(exc))
        return {
            "reply": "I had trouble formatting my response — please try rephrasing your request.",
            "outfit_suggestions": [],
        }
    except Exception as exc:
        _log.error("chat_stylist_failed", error=str(exc))
        return {
            "reply": "I couldn't reach my styling engine right now — please try again in a moment.",
            "outfit_suggestions": [],
        }
