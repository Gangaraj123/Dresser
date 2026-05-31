# Dresser — Project Setup Guide

Dresser is an AI-powered wardrobe management app. You photograph your clothes, and the app builds a structured digital closet — automatically tagging each item with category, color, fabric, pattern, formality, and season. A built-in AI stylist then uses your wardrobe and personal color profile to suggest outfits for any occasion, answer styling questions in natural language, and flag gaps in your wardrobe.

---

## Core Features

**Smart Closet**
Upload a photo of any garment — flat-lay, on a hanger, or worn. Gemini classifies the photo, generates a clean product-style image on a white background, and extracts all metadata (category, sub-category, colors, fabric, pattern, formality score, season suitability) automatically.

**Personal Color Profile**
During onboarding, take a selfie. Gemini analyzes your skin undertone, seasonal color type (spring / summer / autumn / winter), and builds a palette of power colors, neutral colors, and shades to avoid. Every garment in your closet is then scored for compatibility with your personal palette.

**AI Stylist Chat**
A conversational stylist that knows your wardrobe. Ask it anything — "What should I wear to a garden wedding?", "Show me my blue tops", "What am I missing for autumn?" — and it responds with outfit suggestions backed by your actual garments, rendered as visual cards.

**Outfit Builder**
Create and save named outfits from any combination of garments. AI-generated outfits come with a match score and reasoning. Log when you wear an outfit, track wear counts, and mark favorites.

**Event Planner**
Attach an outfit to a calendar event with a dress code, location, and date. The stylist uses that context to make more relevant recommendations.

**Wardrobe Analytics**
Stats across your closet — total items by category, most/least worn pieces, total wardrobe value, and AI-identified gaps.

---

## Architecture Overview

```
Flutter App (mobile + web)
        │
        │  REST API (HTTP/JSON)
        ▼
FastAPI Backend (Python)
        │
        ├── Supabase (PostgreSQL + Auth + Storage)
        └── Google Gemini API (all AI + image generation)
```

The Gemini API key lives only in the backend. The Flutter app never calls Gemini directly — all AI goes through FastAPI.

---

## Repository Structure

```
Dresser/
├── backend/                  FastAPI Python backend
│   ├── config.py             Pydantic settings (reads .env)
│   ├── main.py               App entry point, middleware, routes
│   ├── dependencies.py       JWT auth dependency
│   ├── logger.py             structlog setup
│   ├── models/
│   │   └── schemas.py        Pydantic request/response models
│   ├── routers/
│   │   ├── garments.py       Garment CRUD + upload pipeline
│   │   ├── outfits.py        Outfit management
│   │   ├── profile.py        User profile + skin tone analysis
│   │   ├── stylist.py        AI chat + outfit recommendations
│   │   ├── discover.py       Discovery / inspiration feed
│   │   └── events.py         Event planning
│   ├── services/
│   │   ├── gemini_service.py All Gemini calls (vision + image gen)
│   │   ├── color_scoring.py  Seasonal palette compatibility math
│   │   └── supabase_client.py Supabase SDK client singleton
│   ├── errors/               Typed error classes (AppError, NotFoundError, …)
│   ├── middlewares/          RequestId + RequestLogger middleware
│   ├── utils/                Response formatter, request context
│   └── scripts/
│       ├── init_db.sql       Full database schema (run once)
│       └── create_buckets.py Creates Supabase storage buckets
│
├── dresser_app/              Flutter app
│   ├── lib/
│   │   ├── config/
│   │   │   └── supabase_config.dart  URLs and keys
│   │   ├── screens/
│   │   │   ├── auth/          Login, onboarding steps 1–3
│   │   │   └── main/
│   │   │       ├── closet/    Closet list, garment detail, add garment
│   │   │       ├── outfits/   Outfit list and builder
│   │   │       ├── stylist/   AI chat screen, outfit preview
│   │   │       ├── discover/  Inspiration feed
│   │   │       └── profile/   User settings and color profile
│   │   ├── models/            Dart data models
│   │   ├── widgets/           Shared UI components
│   │   └── theme/             Dark/light theme, color tokens
│   └── pubspec.yaml
│
├── design/                   UI reference HTML files and guides
└── SETUP.md                  This file
```

---

## 1. Google Gemini API

Gemini handles every AI task in the app. One API key, one billing account.

### What Gemini does

| Task | Model | Triggered by |
|---|---|---|
| Classify uploaded garment photo | gemini-2.5-flash | Every garment upload |
| Generate clean product photo (white bg) | gemini-2.0-flash-preview-image-generation | Every garment upload |
| Extract garment metadata (tags, colors, fabric) | gemini-2.5-flash | Every garment upload |
| Analyze selfie for skin tone + seasonal type | gemini-2.5-flash | Onboarding (once) |
| Wardrobe gap analysis | gemini-2.5-flash | Discover tab |
| Outfit recommendations for an event | gemini-2.5-flash | Stylist / Events |
| Free-form stylist chat | gemini-2.5-flash | Stylist tab |

### Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project (or use an existing one)
3. Enable the **Generative Language API** under APIs & Services → Library
4. Create an API key under APIs & Services → Credentials
5. Link a **billing account** to the project (required for image generation)
6. Set a budget alert at $10/month — Cloud Console → Billing → Budgets & Alerts
7. Add the key to `backend/.env`:

```
GEMINI_API_KEY=your-key-here
```

### Cost estimate

| Action | Cost |
|---|---|
| Garment upload (classify + generate photo + analyze) | ~$0.022–0.042 |
| Skin tone analysis (one-time per user) | ~$0.001 |
| Outfit recommendation or chat message | ~$0.0005 |
| 100 users × 20 garments each | ~$44–84/month |

---

## 2. Supabase

Supabase provides the PostgreSQL database, authentication, and file storage.

### Project details

- **Project URL:** `https://iwvzrmgundoijrxhvvea.supabase.co`
- **Dashboard:** [app.supabase.com](https://app.supabase.com) → sign in → select the Dresser project

### Setup steps

**Step 1 — Create a Supabase project**
Go to [app.supabase.com](https://app.supabase.com), create a new project, choose a region close to your users.

**Step 2 — Initialize the database**
Open the Supabase SQL Editor and run the contents of `backend/scripts/init_db.sql`. This creates all tables, indexes, RLS policies, and the auth trigger.

**Step 3 — Create storage buckets**
```bash
cd backend
python scripts/create_buckets.py
```
This creates three buckets:

| Bucket | Access | Contents |
|---|---|---|
| `dresser-originals` | Private | Compressed original uploads (~150–300 KB each) |
| `dresser-display` | Public (CDN) | Gemini-generated product photos, JPEG 85% |
| `dresser-thumbnails` | Public (CDN) | 300×300 thumbnails for grid browsing |

**Step 4 — Get your keys**
From the Supabase Dashboard → Settings → API:

- **URL** → `SUPABASE_URL`
- **service_role key** (secret, never expose to client) → `SUPABASE_SERVICE_KEY`
- **anon/public key** → used in Flutter `supabase_config.dart`
- **JWT Secret** → Settings → API → JWT Settings → `SUPABASE_JWT_SECRET`

**Step 5 — Enable Google OAuth (optional)**
Dashboard → Authentication → Providers → Google → enable, add your Google OAuth Client ID and Secret. Add `io.supabase.dresser://login-callback` to Redirect URLs.

**Step 6 — Database connection string**
Dashboard → Settings → Database → Connection string → URI mode → copy into `DATABASE_URL`.

### Database schema

```
profiles          One row per user. Stores display name, avatar, style preferences,
                  skin undertone, seasonal type, and full color palette (JSONB).

garments          One row per garment. Stores all AI-generated metadata, image URLs,
                  wear tracking (times_worn, last_worn_date), and status
                  (active / laundry / retired / donated).

outfits           Named collections of garment_ids (UUID array). Tracks AI reasoning,
                  match score, wear count, and favorite flag.

events            Calendar events with a date, dress code, location, and an attached outfit.

recommendations   Log of every AI recommendation — what was suggested, which outfit
                  the user picked, and their response (accepted/rejected/modified).
```

All tables have Row Level Security (RLS) enabled. Users can only read and write their own rows — enforced at the database level.

---

## 3. Backend (FastAPI)

### Requirements

- Python 3.11+
- Packages: see `backend/requirements.txt`

### Local setup

```bash
cd backend
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Environment variables

Create `backend/.env`:

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-supabase-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret

# Database (for migration scripts only)
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres

# Gemini
GEMINI_API_KEY=your-gemini-api-key

# App
APP_ENV=development
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
PORT=3005
```

### Run locally

```bash
cd backend
uvicorn main:app --reload --port 3005
```

API docs available at `http://localhost:3005/docs` (Swagger UI).

### Expose to Flutter during development

Flutter on a physical device cannot reach `localhost`. Use a tunnel:

```bash
# Option A: zrok (used in this project)
zrok share public http://localhost:3005

# Option B: ngrok
ngrok http 3005
```

Copy the tunnel URL into `dresser_app/lib/config/supabase_config.dart` → `apiBaseUrl`.

### API endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Basic health check |
| GET | `/health/deep` | Health check with DB ping |
| GET/PUT | `/api/v1/profile` | Get or update user profile |
| POST | `/api/v1/profile/skin-tone` | Analyze selfie, save color profile |
| GET/POST | `/api/v1/garments` | List garments / upload new garment |
| GET/PUT/DELETE | `/api/v1/garments/{id}` | Get, update, or delete a garment |
| POST | `/api/v1/garments/{id}/worn` | Log a wear event |
| GET/POST | `/api/v1/outfits` | List outfits / create outfit |
| GET/PUT/DELETE | `/api/v1/outfits/{id}` | Get, update, or delete an outfit |
| POST | `/api/v1/stylist/recommend` | Get outfit recommendations for an event |
| POST | `/api/v1/stylist/chat` | Free-form stylist chat |
| GET | `/api/v1/discover` | Discovery / inspiration feed |
| GET/POST | `/api/v1/events` | List events / create event |

---

## 4. Flutter App

### Requirements

- Flutter SDK 3.10.4+
- Dart 3.x
- Android Studio or VS Code with Flutter extension

### Key dependencies

| Package | Purpose |
|---|---|
| `supabase_flutter` | Auth (email + Google OAuth) and database access |
| `google_sign_in` | Google OAuth login flow |
| `go_router` | Declarative navigation |
| `image_picker` | Camera and gallery access |
| `flutter_image_compress` | Client-side compression before upload (1024px, JPEG 90%) |
| `cached_network_image` | CDN image caching — thumbnails load once and cache on device |
| `google_fonts` | Typography (Plus Jakarta Sans, Cormorant Garamond) |
| `shared_preferences` | Local key-value storage |

### Configuration

Open `dresser_app/lib/config/supabase_config.dart` and fill in:

```dart
class SupabaseConfig {
  static const String url      = 'https://your-project.supabase.co';
  static const String anonKey  = 'your-supabase-anon-key';
  static const String apiBaseUrl = 'https://your-backend-url';
}
```

`anonKey` is the public/anon key from Supabase — safe to include in the app.
`apiBaseUrl` is your FastAPI server URL (tunnel URL during development, deployed URL in production).

### Run

```bash
cd dresser_app
flutter pub get
flutter run
```

---

## 5. Garment Upload Pipeline

Understanding this flow is useful for debugging:

```
User picks photo (Flutter)
  └── flutter_image_compress: resize to 1024px max, JPEG 90% (~150-300 KB)
  └── Send to backend as multipart/form-data

Backend receives image
  └── Store original in dresser-originals/ (private)
  └── Gemini classify_input: is the garment visible? what type of photo?
      └── If can_process=false → return 422 with retake tip to user
  └── Gemini generate_product_photo: white-background product photo
  └── compress_for_storage: JPEG 85% (~150-300 KB)
  └── Store in dresser-display/ (public CDN)
  └── generate_thumbnail: 300×300 JPEG 85% (~20-40 KB)
  └── Store in dresser-thumbnails/ (public CDN)
  └── Gemini analyze_garment: extract all metadata from the product photo
  └── score_garment_compatibility: compare dominant color to user's seasonal palette
  └── Insert garment row in database
  └── Return complete garment object to Flutter
```

---

## 6. Image Storage Strategy

| File | Size target | Format | Bucket | Access |
|---|---|---|---|---|
| Original (compressed by Flutter) | 150–300 KB | JPEG | `dresser-originals` | Private |
| Display photo (Gemini output, JPEG 85%) | 150–300 KB | JPEG | `dresser-display` | Public CDN |
| Thumbnail | 20–40 KB | JPEG | `dresser-thumbnails` | Public CDN |
| **Total per garment** | **~320–640 KB** | | | |

Storage capacity:
- **Free tier (1 GB):** ~1,500–3,000 garments — enough for 40–75 beta users
- **Pro tier (100 GB, $25/month):** ~150,000–300,000 garments — comfortable past 5,000 users

---

## 7. Auth Flow

1. User opens the app → Supabase checks for an existing session
2. If no session → Login screen (email/password or Google OAuth)
3. On sign-up → Supabase trigger fires → `profiles` row auto-created
4. First login → Onboarding (3 steps: style preferences → selfie for skin tone → color results)
5. All subsequent API calls include the Supabase JWT as `Authorization: Bearer <token>`
6. Backend validates the JWT against `SUPABASE_JWT_SECRET` in the `get_current_user` dependency

---

## 8. Development Checklist

- [ ] Supabase project created
- [ ] `init_db.sql` run in Supabase SQL Editor
- [ ] Storage buckets created (`python scripts/create_buckets.py`)
- [ ] Google Cloud project created, Generative Language API enabled
- [ ] Billing account linked to Google Cloud project
- [ ] `backend/.env` filled in with all keys
- [ ] `dresser_app/lib/config/supabase_config.dart` updated with URL, anon key, and API URL
- [ ] Backend running (`uvicorn main:app --reload --port 3005`)
- [ ] Tunnel running and URL copied into `supabase_config.dart`
- [ ] `flutter pub get` run
- [ ] App running on device or emulator
