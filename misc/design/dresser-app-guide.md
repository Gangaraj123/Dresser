# Dresser — AI Wardrobe Manager

## Complete Product & Development Guide

> This document is the single source of truth for building the Dresser app. It covers product requirements, design system, architecture, database schema, AI pipeline, API contracts, and implementation details. Feed this to Claude CLI to begin building.

---

## 1. Product Overview

### 1.1 What is Dresser?

Dresser is a mobile-first AI-powered wardrobe management app that helps users catalog their clothing, receive personalized outfit recommendations based on events and skin tone analysis, and discover new items that complement their existing wardrobe.

### 1.2 Core Value Propositions

- **Catalog**: Upload garment photos → AI auto-tags category, color, fabric, formality, season. Background is removed automatically, producing clean e-commerce-style product images.
- **Recommend**: Describe an event (or pick a preset) → AI composes 3–5 complete outfit suggestions from the user's wardrobe, ranked by match quality.
- **Personalize**: Upload a selfie → AI determines skin undertone, contrast level, and seasonal color type → all recommendations factor in color harmony with the user's appearance.
- **Discover**: AI identifies wardrobe gaps and suggests purchasable items from external retailers, filtered by the user's color profile and existing wardrobe.

### 1.3 Target Platform

- **Primary**: Flutter mobile app (iOS + Android)
- **Backend**: Python FastAPI
- **Database**: Supabase (PostgreSQL + Auth + Storage)
- **AI**: Google Gemini API (free tier for MVP)
- **Image Processing**: rembg (self-hosted background removal)

---

## 2. Design System — "Dresser"

### 2.1 Design Philosophy

Warm, premium, gender-neutral. The aesthetic draws from high-end fashion retail — clean surfaces, generous whitespace, warm earth tones. It should feel like a personal stylist's studio, not a tech product. Typography pairs an elegant serif display font with a clean sans-serif body font.

### 2.2 Color Palette

#### Primary Colors
```
Accent Primary:    #C67D4A  (Warm copper/terracotta — used for CTAs, active states, highlights)
Accent Dark:       #A85D2E  (Darker copper — used for pressed states, accent text)
Accent Light:      #F5E6D8  (Light peach — used for subtle backgrounds, tags, badges)
```

#### Light Theme
```
Background Primary:     #FDFAF6  (Warm off-white — main screen background)
Background Secondary:   #F5F0E8  (Warm cream — cards, input fields, stat cards)
Background Tertiary:    #EDE7DB  (Warm sand — borders, toggles off-state, dividers)
Card Background:        #FFFFFF  (Pure white — elevated cards, outfit cards)
```

#### Dark Theme
```
Background Primary:     #1A1815  (Very dark warm brown — main background)
Background Secondary:   #242120  (Dark brown — cards, input fields)
Background Tertiary:    #2E2B28  (Medium dark brown — borders, dividers)
Card Background:        #242120  (Same as secondary — elevated cards)
```

#### Text Colors (Light Theme)
```
Text Primary:       #1A1815  (Near black — headings, body text)
Text Secondary:     #6B6560  (Medium warm grey — labels, descriptions)
Text Tertiary:      #9B9590  (Light warm grey — placeholders, hints, timestamps)
```

#### Text Colors (Dark Theme)
```
Text Primary:       #F5F0E8  (Warm off-white)
Text Secondary:     #A09A94  (Medium warm grey)
Text Tertiary:      #6B6560  (Darker warm grey)
```

#### Semantic Colors
```
Success:     #4A8C6F  (Forest green — match scores, positive indicators)
Info:        #5B7FA5  (Steel blue — informational badges, links)
Danger:      #B85450  (Muted red — warnings, delete actions, avoid-colors)
Warning:     #D4935E  (Warm amber — caution states)
```

#### Border
```
Light theme:  rgba(26, 24, 21, 0.08)   (Very subtle warm border)
Dark theme:   rgba(245, 240, 232, 0.08) (Very subtle light border)
```

### 2.3 Typography

#### Font Families
```
Display / Headings:  'Playfair Display'  (serif, weights: 500, 600, 700)
Body / UI:           'DM Sans'           (sans-serif, weights: 400, 500, 600, 700)
```

#### Type Scale
```
Screen Title:        Playfair Display, 26px, weight 600, line-height 1.2
Section Title:       Playfair Display, 22px, weight 600, line-height 1.3
Card Title:          DM Sans, 14–15px, weight 600, line-height 1.4
Body Text:           DM Sans, 13–14px, weight 400, line-height 1.5
Caption / Label:     DM Sans, 12px, weight 500, line-height 1.4
Small / Hint:        DM Sans, 10–11px, weight 400–500, line-height 1.3
Stat Number:         Playfair Display, 22px, weight 600
```

### 2.4 Spacing System

```
Base unit:   4px
xs:          4px
sm:          8px
md:          12px
lg:          16px
xl:          20px
2xl:         24px
3xl:         32px
4xl:         40px
5xl:         48px
```

### 2.5 Border Radius

```
Small (tags, badges):          12px
Medium (input fields, chips):  14px
Large (cards, buttons):        16px
XLarge (upload area, modals):  20px
Full (avatars, dots):          50% / 9999px
```

### 2.6 Elevation & Shadows

No drop shadows. Elevation is communicated through:
- Background color differences (secondary bg vs primary bg)
- Subtle 0.5px borders
- White card on cream background (light mode)

### 2.7 Component Library

#### Buttons
```
Primary Button:
  - Background: Accent Primary (#C67D4A)
  - Text: White (#FFFFFF)
  - Border Radius: 14px
  - Padding: 14px vertical, full width
  - Font: DM Sans 14px, weight 600
  - Pressed: Accent Dark (#A85D2E)

Secondary Button:
  - Background: Card Background
  - Text: Text Primary
  - Border: 0.5px solid Border color
  - Border Radius: 14px
  - Padding: 14px vertical

Icon Button:
  - Size: 36x36px
  - Border Radius: 12px
  - Background: Accent Primary (for add/create actions)
  - Icon: White, 18px
```

#### Input Fields
```
Search Bar:
  - Background: Background Secondary
  - Border Radius: 14px
  - Padding: 10px 14px
  - Font: DM Sans 14px
  - Icon: 16px, Text Tertiary color
  - No border

Text Input:
  - Background: Background Secondary
  - Border: 0.5px solid Border color
  - Border Radius: 14px
  - Padding: 14px 16px
  - Font: DM Sans 14px
```

#### Filter Chips
```
Inactive:
  - Background: Background Secondary
  - Text: Text Secondary, DM Sans 12px weight 500
  - Border: 0.5px solid Border color
  - Border Radius: 20px (pill shape)
  - Padding: 6px 14px

Active:
  - Background: Accent Primary
  - Text: White
  - Border: none
```

#### Cards
```
Garment Card:
  - Aspect ratio: 3:4
  - Border Radius: 14px
  - Background: Background Secondary
  - Tag badge: White bg, 8px radius, positioned bottom-left, 10px font
  - Color dot: 14px circle, positioned top-right, 1.5px white border

Outfit Card:
  - Background: Card Background
  - Border: 0.5px solid Border color
  - Border Radius: 16px
  - Padding: 14px
  - Outfit items row: horizontal scroll, 64x80px thumbnails, 10px radius

Stat Card:
  - Background: Background Secondary
  - Border Radius: 14px
  - Padding: 14px 12px
  - Number: Playfair Display 22px weight 600, Accent color
  - Label: DM Sans 10px, Text Tertiary

Discover/Shopping Card:
  - Background: Card Background
  - Border: 0.5px solid Border color
  - Border Radius: 16px
  - Image area: 160px height, Background Secondary
  - Info padding: 12px 14px
  - Match badge: Success bg (#E8F5E9), Success text, 10px font, 8px radius
```

#### Tags / Badges
```
Category tag:   bg Accent Light,  text Accent Dark
Color tag:      bg Background Primary, border 1px Border, text Text Secondary (includes color dot)
Season tag:     bg #E8F5E9, text #2E7D32
Formality tag:  bg #E3F2FD, text #1565C0
Fabric tag:     bg #F3E5F5, text #7B1FA2
Pattern tag:    bg #FFF3E0, text #E65100
Match score:    bg Accent Light, text Accent Dark, 11px font weight 600, 10px radius
```

#### Toggle Switch
```
Track:
  - Width: 44px, Height: 26px
  - Border Radius: 13px
  - Off: Background Tertiary
  - On: Accent Primary

Knob:
  - Size: 22px
  - Color: White
  - Border Radius: 50%
  - Position: 2px from edge
  - Transition: 0.2s transform
```

#### Bottom Navigation
```
Container:
  - Background: Background Primary
  - Border Top: 0.5px solid Border color
  - Padding: 10px 0 28px (28px for safe area)

Nav Item:
  - Icon: 22px line icons, stroke-width 1.5
  - Label: 10px, DM Sans
  - Inactive: Text Tertiary
  - Active: Accent Primary
  - Layout: column, center, 3px gap between icon and label

Tabs: Closet | Outfits | Stylist | Discover | Profile
```

#### Color Palette Swatches (Profile screen)
```
Swatch:
  - Height: 48px
  - Border Radius: 10px
  - Flex: equal width in row
  - Label: 8px font, white with text-shadow, positioned bottom-center
  - "Avoid" colors: 0.6 opacity
```

#### Chat Interface
```
User Message:
  - Background: Accent Primary
  - Text: White, 13px
  - Border Radius: 18px (bottom-right: 6px)
  - Max Width: 85%
  - Align: right

AI Message:
  - Background: Background Secondary
  - Text: Text Primary, 13px
  - Border Radius: 18px (bottom-left: 6px)
  - Max Width: 85%
  - Align: left
  - AI Label: 10px weight 600, Accent color

Chat Input:
  - Border: 0.5px solid Border color
  - Border Radius: 22px
  - Padding: 10px 16px
  - Background: Background Secondary

Send Button:
  - Size: 38px circle
  - Background: Accent Primary
  - Icon: White, 16px
```

#### Calendar
```
Day Cell:
  - Aspect ratio: 1:1
  - Font: 12px
  - Color: Text Secondary
  - Border Radius: 10px

Has Outfit:
  - Background: Accent Light
  - Text: Accent Dark, weight 600

Today:
  - Border: 1.5px solid Accent Primary
  - Text: Accent Primary, weight 600
```

### 2.8 Iconography

Use line-style icons throughout. Stroke width: 1.5px. Size: 22px for nav, 16–18px for inline. Source: Lucide Icons (available as a Flutter package) or equivalent line icon set.

Navigation icons:
- Closet: 2x2 grid of rounded squares
- Outfits: stacked layers / cube
- Stylist: AI/magic sparkle or shirt+hanger
- Discover: magnifying glass with plus
- Profile: person circle

### 2.9 App Icon & Branding

App name: **Dresser**
Tagline: "Your AI-powered personal stylist"
Logo style: The word "Dresser" in Playfair Display, weight 700, Accent Primary color. Clean, no symbol needed for MVP.

---

## 3. Screen-by-Screen Specification

### 3.1 Authentication Screens

#### 3.1.1 Login / Sign Up
- Centered layout
- App logo: "Dresser" in Playfair Display 36px weight 700, Accent color
- Tagline below logo
- **"Continue with Google" button** (primary auth method)
  - Full width, Card bg, 0.5px border, 14px radius
  - Google "G" icon (multicolor SVG) + "Continue with Google" text
  - Uses Supabase Google OAuth
- Divider: "or" with horizontal lines
- Email + Password inputs (secondary method)
- "Sign in" primary button
- "Don't have an account? Sign up" link at bottom

#### 3.1.2 Onboarding — Style Quiz (3 steps)
- Progress indicator: 3 horizontal bars at top (filled = completed)
- Step 1: "What's your style?" — 2x2 grid of style options (Minimalist, Classic, Streetwear, Bohemian). Each is a square card with an icon and label. Tappable, supports multi-select. Selected state: 2px Accent border.
- Step 2: "Upload a selfie" — for color analysis. Camera button + gallery picker. Can skip.
- Step 3: "Add your first items" — camera prompt to start photographing garments. Can skip.
- "Continue" primary button on each step

### 3.2 Main Screens (Tab Navigation)

#### 3.2.1 Closet (Home Tab)
- Header: "My closet" (screen title) + Add button (icon button, top right)
- Subtitle: "47 items" (dynamic count)
- Stats row: 3 stat cards showing counts by category (Tops, Bottoms, Others)
- Search bar
- Filter chips row: horizontal scroll — All, Tops, Bottoms, Outerwear, Footwear, Accessories
- Garment grid: 3 columns, garment cards with category tag and color dot
- FAB or top-right button: opens "Add garment" flow

#### 3.2.2 Add Garment Flow
- Screen title: "Add garment"
- Upload area: dashed 2px border, 20px radius, centered camera icon in Accent Light circle
- "Tap to upload photo" text + "Use a plain background for best results" hint
- After upload: shows processing states
  - "Removing background..." with spinner
  - "Analyzing garment..." with spinner
  - Results appear as AI-detected tags section
- Tag results card: shows garment thumbnail (processed), name, confidence %, and tag chips (category, color with dot, season, formality, fabric, pattern)
- Tags are editable — tap to change
- "Save to wardrobe" primary button

#### 3.2.3 Outfits Tab
- Screen title: "Saved outfits"
- Outfit cards: each shows garment thumbnails in a row (64x80px), outfit name, occasion, match score badge
- Wear calendar section below:
  - "Wear calendar" section title
  - Day headers row (M T W T F S S)
  - Calendar grid: days with outfit indicator highlighting

#### 3.2.4 Stylist Tab (AI Chat)
- Header: AI avatar (gradient circle) + "Dresser stylist" + "Online" status
- Chat interface: scrollable message list
- AI greeting message on first open
- User types event description → AI responds with outfit suggestions embedded as cards within chat bubbles
- AI outfit suggestion card (inside chat): garment thumbnails row, outfit name, reasoning text, match score
- Quick event presets: horizontal chips above input ("Work meeting", "Date night", "Casual outing", "Wedding", "Vacation")
- Chat input bar with send button

#### 3.2.5 Discover Tab
- Screen title: "Discover"
- Wardrobe gap alert banner: Accent Light bg, accent border-left, explains detected gap
- Shopping recommendation cards: product image area, product name, brand, price (in INR ₹), match percentage badge
- Filter by: price range, category, color compatibility

#### 3.2.6 Profile Tab
- Profile header: avatar circle (gradient bg, initial letter), name, seasonal color type badge ("Warm Autumn")
- Color palette sections:
  - "Your power colors" — row of 6 color swatches with labels
  - "Safe neutrals" — row of 4 swatches
  - "Colors to avoid" — row of 4 swatches at reduced opacity
- Settings toggles:
  - "Color-aware recommendations" — on/off
  - "Weather-aware styling" — on/off
  - "Repeat detection" — on/off
- "Update my photos" primary button
- Sign out link

---

## 4. System Architecture

### 4.1 High-Level Architecture

```
┌─────────────────────┐
│  Flutter Mobile App  │
│  (iOS + Android)     │
└──────────┬──────────┘
           │ REST API (HTTPS)
           ▼
┌─────────────────────┐
│  Python FastAPI      │
│  Backend Server      │
│                      │
│  ┌─────────────────┐ │
│  │ Image Pipeline  │ │
│  │ - rembg         │ │
│  │ - Pillow        │ │
│  │ - scikit-learn  │ │
│  └─────────────────┘ │
└──────────┬──────────┘
           │
     ┌─────┼──────┐
     ▼     ▼      ▼
┌────────┐┌─────┐┌──────────┐
│Supabase││Gemi-││Supabase  │
│Postgres││ni   ││Storage   │
│  + Auth││API  ││(S3-comp) │
└────────┘└─────┘└──────────┘
```

### 4.2 Technology Stack

```
Frontend:           Flutter 3.x + Dart
State Management:   Riverpod (recommended) or BLoC
HTTP Client:        Dio
Local Storage:      SharedPreferences (settings), sqflite (offline garment cache)
Image Picker:       image_picker package
Auth:               supabase_flutter package

Backend:            Python 3.11+ with FastAPI
ASGI Server:        Uvicorn
Image Processing:   rembg, Pillow, scikit-learn (KMeans)
AI:                 google-generativeai (Gemini SDK)
ORM:                SQLAlchemy or raw asyncpg
Task Queue:         Celery + Redis (for async image processing at scale)
                    For MVP: synchronous processing is fine

Database:           Supabase (PostgreSQL 15)
Auth:               Supabase Auth (Google OAuth provider)
File Storage:       Supabase Storage (S3-compatible buckets)
Hosting:            Railway / Render / AWS EC2 for backend
```

### 4.3 Supabase Configuration

#### Auth Setup
- Enable Google OAuth provider in Supabase Dashboard → Authentication → Providers
- Create OAuth credentials in Google Cloud Console
- Configure redirect URL: `io.supabase.dresser://login-callback`
- Flutter uses `supabase_flutter` package with `signInWithOAuth(OAuthProvider.google)`

#### Storage Buckets
```
dresser-originals/     — Raw uploaded photos (private, user-scoped)
dresser-processed/     — Background-removed transparent PNGs (private, user-scoped)
dresser-display/       — Final product-style images with white bg + shadow (public, CDN-served)
dresser-thumbnails/    — 300x300 grid thumbnails (public, CDN-served)
dresser-profiles/      — User selfies for color analysis (private, processed and deleted)
```

#### Row Level Security (RLS)
All tables enforce RLS. Users can only read/write their own data. Policies:
```sql
-- Example for garments table
CREATE POLICY "Users can view own garments"
  ON garments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own garments"
  ON garments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own garments"
  ON garments FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own garments"
  ON garments FOR DELETE
  USING (auth.uid() = user_id);
```

---

## 5. Database Schema

### 5.1 Tables

```sql
-- Users (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  
  -- Style preferences (from onboarding)
  style_preferences TEXT[],           -- ['minimalist', 'classic']
  
  -- Color analysis results
  skin_undertone TEXT,                -- 'warm', 'cool', 'neutral'
  skin_depth TEXT,                    -- 'fair', 'light', 'medium', 'tan', 'deep'
  hair_tone TEXT,                     -- 'warm brown', 'cool black', etc.
  eye_color TEXT,
  contrast_level TEXT,                -- 'low', 'medium', 'high'
  seasonal_type TEXT,                 -- 'spring', 'summer', 'autumn', 'winter'
  power_colors JSONB,                -- [{"hex": "#8B4513", "name": "Saddle brown"}]
  neutral_colors JSONB,
  avoid_colors JSONB,
  
  -- Settings
  color_aware_recommendations BOOLEAN DEFAULT true,
  weather_aware_styling BOOLEAN DEFAULT true,
  repeat_detection BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Garments
CREATE TABLE public.garments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Images
  original_image_url TEXT NOT NULL,
  processed_image_url TEXT,          -- transparent PNG
  display_image_url TEXT,            -- product-style with white bg
  thumbnail_url TEXT,                -- 300x300
  
  -- AI-generated tags
  category TEXT NOT NULL,            -- 'topwear', 'bottomwear', 'footwear', 'outerwear', 'accessory'
  sub_category TEXT,                 -- 'shirt', 'jeans', 'blazer', 'sneakers', etc.
  
  -- Color data (extracted via KMeans)
  colors JSONB NOT NULL,             -- [{"hex":"#2C3E50","percentage":65,"name":"dark navy"}]
  dominant_color_hex TEXT,
  dominant_color_name TEXT,
  color_family TEXT,                 -- 'cool', 'warm', 'neutral'
  color_brightness FLOAT,           -- 0.0 to 1.0
  
  -- Classification
  pattern TEXT,                      -- 'solid', 'striped', 'floral', 'plaid', 'abstract'
  fabric TEXT,                       -- 'cotton', 'silk', 'denim', 'wool', 'synthetic', 'linen'
  formality_score INTEGER CHECK (formality_score BETWEEN 1 AND 5),
  season_suitability TEXT[],         -- ['summer', 'all-season']
  
  -- User overrides
  user_name TEXT,                    -- user's custom name for the item
  brand TEXT,
  purchase_price DECIMAL(10,2),
  size TEXT,
  notes TEXT,
  custom_tags TEXT[],
  
  -- Computed scores
  skin_compatibility_score INTEGER CHECK (skin_compatibility_score BETWEEN 1 AND 5),
  versatility_score FLOAT,
  
  -- Status & usage
  status TEXT DEFAULT 'active',      -- 'active', 'laundry', 'retired', 'donated'
  times_worn INTEGER DEFAULT 0,
  last_worn_date DATE,
  ai_confidence FLOAT,              -- 0.0 to 1.0, how confident AI was in tagging
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Outfits (saved outfit compositions)
CREATE TABLE public.outfits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL,
  occasion TEXT,                     -- 'beach wedding', 'board meeting', etc.
  garment_ids UUID[] NOT NULL,       -- ordered array of garment IDs
  
  -- AI metadata
  ai_generated BOOLEAN DEFAULT false,
  ai_reasoning TEXT,                 -- why AI suggested this combination
  match_score INTEGER,               -- 0-100 overall match score
  
  -- Usage
  times_worn INTEGER DEFAULT 0,
  last_worn_date DATE,
  is_favorite BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Events (wear log)
CREATE TABLE public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  event_date DATE NOT NULL,
  description TEXT,
  dress_code TEXT,
  location TEXT,
  weather_snapshot JSONB,            -- {"temp": 32, "condition": "sunny", "humidity": 65}
  
  outfit_id UUID REFERENCES public.outfits(id) ON DELETE SET NULL,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Recommendations log (for feedback loop)
CREATE TABLE public.recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  event_description TEXT,
  suggested_outfit_ids UUID[],       -- garment IDs in the suggestion
  reasoning TEXT,
  match_score INTEGER,
  
  user_action TEXT,                  -- 'accepted', 'rejected', 'modified', 'ignored'
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_garments_user ON garments(user_id);
CREATE INDEX idx_garments_category ON garments(user_id, category);
CREATE INDEX idx_garments_status ON garments(user_id, status);
CREATE INDEX idx_garments_formality ON garments(user_id, formality_score);
CREATE INDEX idx_outfits_user ON outfits(user_id);
CREATE INDEX idx_events_user_date ON events(user_id, event_date);
```

---

## 6. API Specification

### 6.1 Authentication

All endpoints require `Authorization: Bearer <supabase_jwt>` header. Backend validates JWT with Supabase.

### 6.2 Endpoints

#### Profile
```
GET    /api/v1/profile                    — Get current user profile
PUT    /api/v1/profile                    — Update profile
POST   /api/v1/profile/analyze-color      — Upload selfie, run color analysis
DELETE /api/v1/profile/color-data          — Delete color analysis data
```

#### Garments
```
GET    /api/v1/garments                   — List all garments (filterable)
  Query params: ?category=topwear&status=active&formality_min=3&season=summer
POST   /api/v1/garments                   — Upload new garment (multipart form)
GET    /api/v1/garments/:id               — Get garment detail
PUT    /api/v1/garments/:id               — Update garment (edit tags, status, etc.)
DELETE /api/v1/garments/:id               — Delete garment
POST   /api/v1/garments/:id/worn          — Log garment as worn today
GET    /api/v1/garments/stats             — Wardrobe statistics
```

#### Outfits
```
GET    /api/v1/outfits                    — List saved outfits
POST   /api/v1/outfits                    — Save a new outfit
PUT    /api/v1/outfits/:id               — Update outfit
DELETE /api/v1/outfits/:id               — Delete outfit
POST   /api/v1/outfits/:id/worn          — Log outfit as worn
```

#### AI Stylist
```
POST   /api/v1/stylist/recommend          — Get outfit recommendations
  Body: { "event_description": "beach wedding in Goa, December evening",
          "dress_code": "semi-formal",
          "location": "Goa, India",
          "date": "2026-12-15" }
  Response: { "outfits": [...], "reasoning": "..." }

POST   /api/v1/stylist/chat               — Conversational styling (free text)
  Body: { "message": "What should I wear to a job interview tomorrow?" }
```

#### Discover
```
GET    /api/v1/discover/gaps              — Wardrobe gap analysis
GET    /api/v1/discover/suggestions       — Shopping recommendations
  Query params: ?budget_max=5000&category=outerwear
```

#### Events
```
GET    /api/v1/events                     — List events/wear log
  Query params: ?month=2026-03
POST   /api/v1/events                     — Log an event
```

---

## 7. Image Processing Pipeline

### 7.1 Upload Flow (Server-Side)

```
Step 1: Receive image from Flutter app
        └→ Validate (file type, size < 10MB)
        └→ Store original in dresser-originals/ bucket

Step 2: Background removal (rembg)
        └→ from rembg import remove
        └→ Input: original JPEG/PNG
        └→ Output: transparent PNG
        └→ Store in dresser-processed/ bucket

Step 3: Color extraction (scikit-learn KMeans)
        └→ Sample non-transparent pixels from Step 2 output
        └→ Run KMeans(k=3 to 5) on RGB values
        └→ Extract dominant colors as hex + percentage
        └→ Classify each into color family (warm/cool/neutral) via HSL
        └→ Store color data in garments table

Step 4: Product image compositing (Pillow)
        └→ Input: transparent PNG from Step 2
        └→ Auto-crop to content with 5% padding
        └→ Resize to fit 1000x1000 canvas (maintain aspect ratio)
        └→ Add subtle gaussian drop shadow (offset 0,4 / blur 8 / opacity 0.15)
        └→ Place on white (#FFFFFF) background
        └→ Store in dresser-display/ bucket
        └→ Generate 300x300 thumbnail → dresser-thumbnails/ bucket

Step 5: AI analysis (Gemini Vision API)
        └→ Send processed image to Gemini with structured prompt
        └→ Extract: category, sub-category, pattern, fabric, formality (1-5), season
        └→ Store all metadata in garments table

Step 6: Skin compatibility scoring
        └→ If user has color profile: compute score (1-5) based on
           garment dominant color vs user's seasonal palette
        └→ Store skin_compatibility_score in garments table
```

### 7.2 Gemini Prompt for Garment Analysis

```
Analyze this garment image and return a JSON object with these fields:
{
  "category": one of ["topwear", "bottomwear", "footwear", "outerwear", "accessory"],
  "sub_category": specific type (e.g., "oxford shirt", "slim jeans", "chelsea boots"),
  "pattern": one of ["solid", "striped", "floral", "plaid", "abstract", "geometric", "polka dot", "checkered"],
  "fabric": one of ["cotton", "silk", "denim", "wool", "synthetic", "linen", "leather", "knit", "chiffon", "velvet"],
  "formality_score": integer 1-5 (1=loungewear, 2=casual, 3=smart casual, 4=semi-formal, 5=formal/black-tie),
  "season_suitability": array from ["summer", "winter", "monsoon", "spring", "autumn", "all-season"],
  "confidence": float 0-1 indicating how confident you are in the analysis
}

Return ONLY the JSON object, no additional text.
```

### 7.3 Gemini Prompt for Skin Tone Analysis

```
Analyze this person's photo for personal color analysis. Return a JSON object:
{
  "skin_undertone": one of ["warm", "cool", "neutral"],
  "skin_depth": one of ["fair", "light", "medium", "tan", "deep"],
  "hair_tone": description (e.g., "dark brown, warm"),
  "eye_color": description,
  "contrast_level": one of ["low", "medium-low", "medium", "medium-high", "high"],
  "seasonal_type": one of ["spring", "summer", "autumn", "winter"],
  "power_colors": [{"hex": "#...", "name": "color name"}, ...] (6-8 best colors),
  "neutral_colors": [{"hex": "#...", "name": "color name"}, ...] (4-5 safe neutrals),
  "avoid_colors": [{"hex": "#...", "name": "color name"}, ...] (4-5 colors to avoid)
}

Base your analysis on established seasonal color analysis theory.
Return ONLY the JSON object, no additional text.
```

### 7.4 Gemini Prompt for Outfit Recommendation

```
You are a professional fashion stylist. Given the user's wardrobe and event details,
suggest 3 complete outfits.

USER PROFILE:
- Seasonal type: {seasonal_type}
- Undertone: {undertone}
- Contrast: {contrast_level}

EVENT:
- Description: {event_description}
- Dress code: {dress_code}
- Weather: {weather_info}
- Date: {date}

AVAILABLE GARMENTS:
{garments_json}
(Each garment has: id, category, sub_category, colors, formality_score, season_suitability, 
 fabric, pattern, skin_compatibility_score, times_worn, last_worn_date)

RULES:
- Each outfit must include at minimum: 1 top + 1 bottom (or 1 full-body piece) + 1 footwear
- Prioritize garments with high skin_compatibility_score
- Avoid suggesting recently worn items (check last_worn_date)
- Consider weather and season suitability
- Follow basic color theory: complementary or analogous pairings
- Match formality to the event's dress code

Return JSON:
{
  "outfits": [
    {
      "name": "creative outfit name",
      "garment_ids": ["uuid1", "uuid2", "uuid3"],
      "match_score": 0-100,
      "reasoning": "2-3 sentences explaining why this works"
    }
  ]
}
```

---

## 8. Color Scoring Algorithm

### 8.1 Seasonal Palette Lookup Table

```python
SEASONAL_PALETTES = {
    "spring": {
        "power": ["#FF6B6B", "#FFA07A", "#FFD700", "#98FB98", "#87CEEB", "#DDA0DD"],
        "neutral": ["#FFFFF0", "#F5DEB3", "#D2B48C", "#808080"],
        "avoid": ["#000000", "#191970", "#800000", "#4B0082"]
    },
    "summer": {
        "power": ["#B0C4DE", "#DDA0DD", "#BC8F8F", "#778899", "#87CEEB", "#D8BFD8"],
        "neutral": ["#F5F5F5", "#C0C0C0", "#A9A9A9", "#708090"],
        "avoid": ["#FF4500", "#FF8C00", "#FFD700", "#000000"]
    },
    "autumn": {
        "power": ["#8B4513", "#B8651A", "#CD853F", "#DAA520", "#6B8E23", "#2E8B57"],
        "neutral": ["#F5F5DC", "#D2B48C", "#808069", "#36454F"],
        "avoid": ["#FFB6C1", "#ADD8E6", "#E6E6FA", "#FF00FF"]
    },
    "winter": {
        "power": ["#DC143C", "#00008B", "#006400", "#4B0082", "#FF1493", "#000000"],
        "neutral": ["#FFFFFF", "#F5F5F5", "#808080", "#000000"],
        "avoid": ["#F0E68C", "#FAEBD7", "#FFA500", "#DEB887"]
    }
}
```

### 8.2 Scoring Function

```python
from colorsys import rgb_to_hls
import math

def hex_to_rgb(hex_color: str) -> tuple:
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def color_distance(c1: tuple, c2: tuple) -> float:
    """Euclidean distance in RGB space"""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))

def score_garment_compatibility(garment_hex: str, seasonal_type: str) -> int:
    """Returns 1-5 compatibility score"""
    palette = SEASONAL_PALETTES[seasonal_type]
    garment_rgb = hex_to_rgb(garment_hex)
    
    # Check against power colors (best match)
    min_power_dist = min(color_distance(garment_rgb, hex_to_rgb(c)) for c in palette["power"])
    
    # Check against avoid colors (worst match)
    min_avoid_dist = min(color_distance(garment_rgb, hex_to_rgb(c)) for c in palette["avoid"])
    
    # Check against neutrals
    min_neutral_dist = min(color_distance(garment_rgb, hex_to_rgb(c)) for c in palette["neutral"])
    
    if min_power_dist < 60:
        return 5  # Perfect match
    elif min_power_dist < 120:
        return 4  # Great match
    elif min_neutral_dist < 80:
        return 3  # Neutral (works for most)
    elif min_avoid_dist < 60:
        return 1  # Avoid
    else:
        return 2  # Suboptimal
```

---

## 9. Flutter App Structure

### 9.1 Project Structure

```
lib/
├── main.dart
├── app.dart                         # MaterialApp, theme, routing
├── config/
│   ├── theme.dart                   # DresserTheme class with all design tokens
│   ├── constants.dart               # API URLs, storage keys
│   └── routes.dart                  # Named routes
├── models/
│   ├── user_profile.dart
│   ├── garment.dart
│   ├── outfit.dart
│   ├── event.dart
│   └── recommendation.dart
├── services/
│   ├── auth_service.dart            # Supabase auth + Google OAuth
│   ├── api_service.dart             # HTTP client (Dio) for backend
│   ├── storage_service.dart         # Supabase storage for images
│   └── camera_service.dart          # Image picker + camera
├── providers/                       # Riverpod providers
│   ├── auth_provider.dart
│   ├── garments_provider.dart
│   ├── outfits_provider.dart
│   ├── profile_provider.dart
│   └── stylist_provider.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── onboarding_screen.dart
│   ├── closet/
│   │   ├── closet_screen.dart       # Main grid view
│   │   ├── add_garment_screen.dart  # Upload + tag review
│   │   └── garment_detail_screen.dart
│   ├── outfits/
│   │   ├── outfits_screen.dart      # Saved outfits + calendar
│   │   └── outfit_detail_screen.dart
│   ├── stylist/
│   │   └── stylist_chat_screen.dart # AI chat interface
│   ├── discover/
│   │   └── discover_screen.dart     # Shopping suggestions
│   └── profile/
│       ├── profile_screen.dart      # Color analysis + settings
│       └── color_analysis_screen.dart
├── widgets/
│   ├── garment_card.dart
│   ├── outfit_card.dart
│   ├── filter_chips.dart
│   ├── stat_card.dart
│   ├── color_swatch.dart
│   ├── chat_bubble.dart
│   ├── tag_chip.dart
│   ├── bottom_nav.dart
│   └── loading_shimmer.dart
└── utils/
    ├── color_utils.dart             # HSL conversion, color naming
    └── date_utils.dart
```

### 9.2 Theme Configuration (theme.dart)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DresserTheme {
  // Colors
  static const accentPrimary = Color(0xFFC67D4A);
  static const accentDark = Color(0xFFA85D2E);
  static const accentLight = Color(0xFFF5E6D8);
  static const success = Color(0xFF4A8C6F);
  static const info = Color(0xFF5B7FA5);
  static const danger = Color(0xFFB85450);

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFDFAF6),
      colorScheme: const ColorScheme.light(
        primary: accentPrimary,
        secondary: accentDark,
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFFDFAF6),
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 26, fontWeight: FontWeight.w600, color: const Color(0xFF1A1815),
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1A1815),
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1815),
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF1A1815),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w400, color: const Color(0xFF6B6560),
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF9B9590),
        ),
      ),
      // Add more theme configuration...
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1815),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD4935E),
        secondary: Color(0xFFE8A872),
        surface: Color(0xFF242120),
        background: Color(0xFF1A1815),
      ),
      // Mirror light theme structure with dark colors...
    );
  }
}
```

### 9.3 Key Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Auth & Backend
  supabase_flutter: ^2.0.0
  google_sign_in: ^6.0.0
  dio: ^5.0.0
  
  # State Management
  flutter_riverpod: ^2.0.0
  
  # UI
  google_fonts: ^6.0.0
  cached_network_image: ^3.0.0
  shimmer: ^3.0.0
  flutter_staggered_grid_view: ^0.7.0
  
  # Camera & Images
  image_picker: ^1.0.0
  
  # Local Storage
  shared_preferences: ^2.0.0
  sqflite: ^2.0.0
  
  # Utilities
  intl: ^0.19.0                    # Date formatting
  flutter_dotenv: ^5.0.0           # Environment variables
```

---

## 10. Backend Implementation

### 10.1 FastAPI Project Structure

```
backend/
├── main.py                          # FastAPI app, CORS, middleware
├── config.py                        # Environment variables, Supabase client
├── requirements.txt
├── routers/
│   ├── auth.py                      # JWT validation middleware
│   ├── garments.py                  # Garment CRUD + upload
│   ├── outfits.py                   # Outfit CRUD
│   ├── stylist.py                   # AI recommendation endpoints
│   ├── profile.py                   # User profile + color analysis
│   ├── discover.py                  # Shopping suggestions
│   └── events.py                    # Wear log
├── services/
│   ├── image_service.py             # rembg + Pillow + compositing
│   ├── color_service.py             # KMeans extraction + HSL classification + scoring
│   ├── ai_service.py                # Gemini API calls
│   └── weather_service.py           # Weather API integration
├── models/
│   ├── garment.py                   # Pydantic models
│   ├── outfit.py
│   ├── profile.py
│   └── recommendation.py
└── utils/
    ├── auth.py                      # Supabase JWT verification
    └── storage.py                   # Supabase Storage helpers
```

### 10.2 Core Dependencies (requirements.txt)

```
fastapi==0.110.0
uvicorn==0.27.0
python-multipart==0.0.9
pydantic==2.6.0
supabase==2.3.0
google-generativeai==0.4.0
rembg==2.0.50
Pillow==10.2.0
scikit-learn==1.4.0
numpy==1.26.0
python-dotenv==1.0.0
httpx==0.27.0
```

---

## 11. MVP Phased Roadmap

### Phase 1 — Foundation (Weeks 1-3)
- Supabase project setup (database, auth, storage)
- Flutter app scaffold with navigation, theme, auth screens
- Google OAuth login flow working end-to-end
- Backend FastAPI skeleton with auth middleware

### Phase 2 — Wardrobe Core (Weeks 4-6)
- Image upload flow (camera/gallery → backend)
- Background removal pipeline (rembg)
- Color extraction (KMeans)
- Product image compositing (Pillow)
- Gemini garment analysis integration
- Closet grid view with filters
- Garment detail screen with editable tags

### Phase 3 — AI Stylist (Weeks 7-8)
- Chat interface UI
- Outfit recommendation engine
- Event presets
- Save/manage outfits
- Wear calendar

### Phase 4 — Color Profiling (Weeks 9-10)
- Selfie upload + Gemini analysis
- Color palette display on profile
- Skin compatibility scoring for all garments
- Score integration into recommendations

### Phase 5 — Discovery & Polish (Weeks 11-12)
- Wardrobe gap analysis
- Shopping suggestions (mock data for MVP, real APIs later)
- Onboarding flow
- Loading states, error handling, edge cases
- Dark mode testing
- App store preparation

---

## 12. Key Implementation Notes

### 12.1 Image Upload Flow (Flutter → Backend → Storage)

1. Flutter picks image via `image_picker`
2. Flutter uploads multipart form to `POST /api/v1/garments`
3. Backend receives file, stores original in Supabase Storage
4. Backend runs rembg → stores processed in Supabase Storage
5. Backend runs KMeans → extracts colors
6. Backend runs Pillow compositing → stores display + thumbnail
7. Backend calls Gemini → gets tags
8. Backend computes skin compatibility score (if profile exists)
9. Backend inserts garment record with all metadata
10. Backend returns complete garment object to Flutter
11. Flutter displays result with tags for review

### 12.2 Offline Support Strategy (MVP)

- Cache garment metadata + thumbnail URLs in sqflite
- Closet grid works offline from cache
- Upload/recommend requires network (show clear offline indicators)
- Sync on reconnect

### 12.3 Error Handling

- Image too blurry / low confidence: prompt re-upload with tips
- Gemini rate limit: queue and retry with exponential backoff
- Network failure: cache locally, sync when available
- Background removal fails: fall back to original image with notice

### 12.4 Privacy & Security

- User selfies for color analysis: process immediately, store only derived attributes, delete raw image
- All storage buckets use RLS (user can only access own files)
- HTTPS everywhere
- JWT tokens verified on every backend request
- No user data shared with third parties
- GDPR-ready: user can delete all data from settings

---

## 13. Testing Strategy

### 13.1 Backend Tests
- Unit tests for color extraction, scoring algorithm, image processing
- Integration tests for full upload pipeline
- API endpoint tests with test JWT tokens

### 13.2 Flutter Tests
- Widget tests for all custom components
- Integration tests for auth flow, upload flow
- Golden tests for UI consistency

### 13.3 AI Quality Tests
- Benchmark garment tagging accuracy against manually labeled dataset
- Track recommendation acceptance rate over time
- A/B test different Gemini prompts for tagging accuracy

---

*End of Dresser App Guide*
