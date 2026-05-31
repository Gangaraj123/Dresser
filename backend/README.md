# Dresser Backend

FastAPI backend for the Dresser AI wardrobe manager app.

## Setup

### 1. Create and activate a virtual environment

```bash
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS / Linux
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

> Note: `rembg` downloads a background-removal model (~170 MB) on first use. This is automatic and only happens once.

### 3. Configure environment variables

```bash
copy .env.example .env
```

Open `.env` and fill in the required values:

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (from Project Settings > API) |
| `SUPABASE_JWT_SECRET` | JWT secret (from Project Settings > API > JWT Settings) |
| `GEMINI_API_KEY` | Google AI Studio API key |
| `APP_ENV` | `development` or `production` |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins |

### 4. Run the development server

```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`.

Interactive docs: `http://localhost:8000/docs`

## Project Structure

```
backend/
  main.py                  # FastAPI application entrypoint
  config.py                # Settings loaded from environment
  dependencies.py          # JWT auth middleware
  requirements.txt
  .env.example
  routers/
    profile.py             # GET/PUT /api/v1/profile, POST /analyze-color
    garments.py            # CRUD + upload pipeline for wardrobe items
    outfits.py             # Outfit management + worn tracking
    stylist.py             # AI outfit recommendations + free-form chat
    discover.py            # Wardrobe gap analysis + shopping suggestions
    events.py              # Calendar event management
  services/
    supabase_client.py     # Supabase client singleton
    gemini_service.py      # Gemini 1.5 Flash integration
    image_pipeline.py      # Background removal, colour extraction, compositing
    color_scoring.py       # Seasonal colour palette scoring
  models/
    schemas.py             # All Pydantic request/response models
```

## Supabase Storage Buckets

The image pipeline expects the following buckets to exist in your Supabase project:

| Bucket | Contents |
|---|---|
| `dresser-originals` | Original uploaded images |
| `dresser-processed` | Transparent PNGs (background removed) |
| `dresser-display` | Product-style display images (1000x1000, white bg) |
| `dresser-thumbnails` | 300x300 JPEG thumbnails |

Create these via the Supabase dashboard (Storage > New bucket). Set `dresser-display` and `dresser-thumbnails` to public.

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/api/v1/profile` | Get current user's profile |
| PUT | `/api/v1/profile` | Update profile preferences |
| POST | `/api/v1/profile/analyze-color` | Upload selfie for AI colour analysis |
| DELETE | `/api/v1/profile/color-data` | Clear colour analysis data |
| GET | `/api/v1/garments` | List garments (filterable) |
| POST | `/api/v1/garments` | Upload new garment (triggers AI pipeline) |
| GET | `/api/v1/garments/stats` | Wardrobe statistics |
| GET | `/api/v1/garments/{id}` | Get single garment |
| PUT | `/api/v1/garments/{id}` | Update garment metadata |
| DELETE | `/api/v1/garments/{id}` | Delete garment |
| POST | `/api/v1/garments/{id}/worn` | Log a wear |
| GET | `/api/v1/outfits` | List outfits |
| POST | `/api/v1/outfits` | Create outfit |
| PUT | `/api/v1/outfits/{id}` | Update outfit |
| DELETE | `/api/v1/outfits/{id}` | Delete outfit |
| POST | `/api/v1/outfits/{id}/worn` | Log outfit worn (updates all garments) |
| POST | `/api/v1/stylist/recommend` | Get AI outfit recommendations for an event |
| POST | `/api/v1/stylist/chat` | Free-form stylist chat |
| GET | `/api/v1/discover/gaps` | Wardrobe gap analysis |
| GET | `/api/v1/discover/suggestions` | Shopping suggestions |
| GET | `/api/v1/events` | List events (filter by month) |
| POST | `/api/v1/events` | Create calendar event |

All endpoints except `/health` require a `Authorization: Bearer <supabase-jwt>` header.
