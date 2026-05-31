import math
import colorsys

# ---------------------------------------------------------------------------
# Seasonal colour palettes
# ---------------------------------------------------------------------------

SEASONAL_PALETTES = {
    "spring": {
        "power": [
            "#FF6B6B", "#FFA07A", "#FFD700", "#98FB98",
            "#87CEEB", "#DDA0DD", "#FF69B4", "#FFA500",
        ],
        "neutral": ["#FFFFF0", "#F5DEB3", "#D2B48C", "#808080", "#FAEBD7"],
        "avoid": ["#000000", "#191970", "#800000", "#4B0082", "#2F4F4F"],
    },
    "summer": {
        "power": [
            "#E0B0FF", "#87CEEB", "#B0C4DE", "#DDA0DD",
            "#F08080", "#FFB6C1", "#ADD8E6", "#C8A2C8",
        ],
        "neutral": ["#F5F5F5", "#D3D3D3", "#C0C0C0", "#A9A9A9", "#DCDCDC"],
        "avoid": ["#FF4500", "#FF8C00", "#FFD700", "#ADFF2F", "#FF6347"],
    },
    "autumn": {
        "power": [
            "#8B4513", "#D2691E", "#CD853F", "#B8860B",
            "#556B2F", "#6B8E23", "#8B0000", "#A0522D",
        ],
        "neutral": ["#F5DEB3", "#DEB887", "#D2B48C", "#BC8F8F", "#C19A6B"],
        "avoid": ["#87CEEB", "#E0B0FF", "#FFB6C1", "#ADD8E6", "#00FFFF"],
    },
    "winter": {
        "power": [
            "#000000", "#FFFFFF", "#FF0000", "#0000FF",
            "#008000", "#800080", "#000080", "#DC143C",
        ],
        "neutral": ["#808080", "#A9A9A9", "#D3D3D3", "#2F4F4F", "#36454F"],
        "avoid": ["#F5DEB3", "#FAEBD7", "#FFE4C4", "#FFDAB9", "#D2B48C"],
    },
}


# ---------------------------------------------------------------------------
# Colour math helpers
# ---------------------------------------------------------------------------

def hex_to_rgb(hex_color: str) -> tuple:
    """Convert '#RRGGBB' (or 'RRGGBB') to (r, g, b) integers."""
    hex_color = hex_color.lstrip("#")
    if len(hex_color) != 6:
        return (128, 128, 128)
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return (r, g, b)


def color_distance(c1: tuple, c2: tuple) -> float:
    """Euclidean distance in RGB space."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))


# ---------------------------------------------------------------------------
# Seasonal compatibility scoring
# ---------------------------------------------------------------------------

def score_garment_compatibility(garment_hex: str, seasonal_type: str) -> int:
    """
    Returns a 1-5 compatibility score between a garment colour and a seasonal type.

    Scoring logic:
    - Find the minimum distance from the garment colour to each palette bucket.
    - Closest bucket (power / neutral / avoid) determines the base score.
    - Power match   → 5   (distance < 60) or 4 (distance < 100)
    - Neutral match → 3   (distance < 60) or 2 (distance < 100)
    - Avoid match   → 1
    - No close match → 3  (neutral default)
    """
    palette = SEASONAL_PALETTES.get(seasonal_type.lower())
    if palette is None:
        return 3  # unknown seasonal type → neutral score

    garment_rgb = hex_to_rgb(garment_hex)

    def min_distance_to_bucket(bucket_hexes: list) -> float:
        distances = [color_distance(garment_rgb, hex_to_rgb(h)) for h in bucket_hexes]
        return min(distances) if distances else float("inf")

    power_dist = min_distance_to_bucket(palette["power"])
    neutral_dist = min_distance_to_bucket(palette["neutral"])
    avoid_dist = min_distance_to_bucket(palette["avoid"])

    # Determine which bucket the colour is closest to
    closest_bucket = min(
        ("power", power_dist),
        ("neutral", neutral_dist),
        ("avoid", avoid_dist),
        key=lambda x: x[1],
    )
    bucket_name, bucket_dist = closest_bucket

    if bucket_name == "power":
        if bucket_dist < 60:
            return 5
        if bucket_dist < 100:
            return 4
        return 3
    elif bucket_name == "neutral":
        if bucket_dist < 60:
            return 3
        if bucket_dist < 100:
            return 2
        return 2
    else:  # avoid
        return 1


# ---------------------------------------------------------------------------
# Colour family classification
# ---------------------------------------------------------------------------

def classify_color_family(hex_color: str) -> str:
    """
    Classify a hex colour as 'warm', 'cool', or 'neutral'.

    Uses HSL hue angle and saturation:
    - Low saturation (≤ 15 %): neutral (grey / white / black)
    - Hue 0-60 and 300-360: warm (reds, oranges, yellows, magentas)
    - Hue 60-180: warm / yellow-greens treated as warm for fashion context
      Actually: 60-150 treated as warm (yellow, yellow-green)
    - Hue 150-300: cool (greens, cyans, blues, purples)
    """
    r, g, b = hex_to_rgb(hex_color)
    # Normalise to 0-1 for colorsys
    r_n, g_n, b_n = r / 255.0, g / 255.0, b / 255.0

    h, l, s = colorsys.rgb_to_hls(r_n, g_n, b_n)

    # Greyscale check — saturation too low to have a meaningful hue
    if s <= 0.15:
        return "neutral"

    hue_deg = h * 360  # 0-360

    # Warm: reds, oranges, yellows, and magentas/pinks
    if hue_deg <= 60 or hue_deg >= 300:
        return "warm"

    # Yellow-greens (chartreuse range) lean warm in fashion
    if 60 < hue_deg <= 150:
        return "warm"

    # Blues, blue-greens, purples → cool
    return "cool"
