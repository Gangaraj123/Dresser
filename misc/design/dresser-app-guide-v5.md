# Dresser — AI Wardrobe Manager
## Complete Product & Development Guide v5.0

> **This is the single source of truth** for building the Dresser app. It supersedes all previous versions. Feed this to Claude CLI / Claude Code alongside the UI HTML reference files.
>
> **What changed in v5:** Gemini handles ALL AI tasks. B&W monochrome theme with semantic accent colors. New killer features: daily outfit notifications, shopping companion, trip packing, wardrobe analytics, social sharing. Revised screens and information architecture.

---

## 1. Product Vision

### 1.1 The Problem

Everyone has stood in front of their closet feeling like they have nothing to wear — despite owning dozens of items. Most people regularly wear only a fraction of what they own, and the average garment is worn just 7 times before being discarded. Meanwhile, impulse purchases pile up because shoppers can't visualize how new items fit with what they already have.

### 1.2 The Solution

Dresser is a mobile AI wardrobe manager that catalogs your clothing, learns your style and skin tone, and tells you exactly what to wear — every morning, every event, every trip. It doesn't sell you more clothes; it helps you use what you have.

### 1.3 One-Line Pitch

**"You have more outfits than you think."**

### 1.4 Core Value Loop

```
Upload clothes → AI catalogs & generates product photos
                        ↓
              Get daily outfit suggestions (weather + calendar aware)
                        ↓
              Discover unused combinations from YOUR closet
                        ↓
              Before buying new: "Does this go with what I own?"
                        ↓
              Track spending, utilization, and style growth
```

### 1.5 What Makes Dresser Different

Every wardrobe app catalogs clothes and suggests outfits. Dresser's differentiators:

1. **Proactive daily styling** — push notification every morning with today's outfit based on weather, calendar, and wear history. No need to open the app and ask.
2. **Shopping companion** — snap a photo in a store or screenshot from Myntra, instantly see "this matches 8 items you own" or "you already have 2 similar ones."
3. **Skin tone color intelligence** — not just "these colors go together" but "these colors flatter YOUR complexion specifically."
4. **Wardrobe ROI tracking** — cost-per-wear, utilization %, spending trends. Makes fashion a smart financial decision, not just aesthetics.
5. **AI-generated product photos** — messy upload becomes a clean e-commerce photo. Your closet looks like a shopping catalog.

---

## 2. Tech Stack

```
Frontend:           Flutter 3.x + Dart
State Management:   Riverpod
Backend:            Python 3.11+ with FastAPI
Database:           Supabase (PostgreSQL + Auth + Storage)
AI (everything):    Google Gemini API (single billing-enabled API key)
Auth:               Supabase Auth with Google OAuth
Weather:            OpenWeatherMap API (free tier: 1,000 calls/day)
Calendar:           Google Calendar API (optional integration)
Hosting:            Railway / Render for backend
```

### 2.1 Gemini API Setup

Single billing-enabled API key handles ALL AI:
- Vision analysis (garment tagging, skin tone analysis, shopping companion)
- Image generation (product photos from messy uploads)
- Text reasoning (outfit recommendations, trip packing, gap analysis)

```
Setup steps:
1. Google AI Studio → create project
2. Enable "Generative Language API"
3. Link billing account
4. Prepay ~₹800 ($10) credits
5. Set auto-reload: "when below ₹400, add ₹1,600"
6. Set project spend cap: ₹2,000/month ($25) during development
7. Get API key → store as GEMINI_API_KEY in backend .env
```

### 2.2 Cost Per Action

```
Garment upload (classify + product photo + analyze):  ~₹1.8-3.3 ($0.022-0.042)
Skin tone analysis (one-time per user):               ~₹0.08 ($0.001)
Outfit recommendation:                                ~₹0.04 ($0.0005)
Shopping companion check:                              ~₹0.12 ($0.0015)
Daily outfit suggestion:                               ~₹0.04 ($0.0005)

Monthly projections (100 users × 20 garments):
  Uploads: 2,000 × ₹2.5 avg = ₹5,000 (~$60)
  Daily suggestions: 100 × 30 × ₹0.04 = ₹120 (~$1.5)
  Recommendations: 500 × ₹0.04 = ₹20 (~$0.25)
  Total: ~₹5,200/month (~$63)
```

---

## 3. Design System

### 3.1 Philosophy

B&W monochrome foundation. Black is the primary accent — clean, high-contrast, fashion-forward. Accent colors appear only where they carry semantic meaning. Shopping-app aesthetic inspired by Etsy/premium marketplaces. Pill-shaped buttons, frosted glass overlays, editorial serif typography, 2-column product grid.

### 3.2 Color Palette

#### Foundation
```
Primary:         #1A1A1A   (buttons, headings, active states)
Background:      #FFFFFF   (screen backgrounds)
Surface:         #F5F5F5   (cards, inputs, stat pills)
Border:          #E8E8E8   (card/input borders)
Border Light:    #F0F0F0   (subtle dividers)
Text Primary:    #1A1A1A   (headings, body)
Text Secondary:  #666666   (labels, descriptions)
Text Tertiary:   #999999   (placeholders, hints)
Text Disabled:   #BBBBBB   (inactive icons)
```

#### Semantic Accent Colors
```
Sage Green  #5C8A6E  — success, match scores 4-5/5, "works for you," good pairings, most worn
Blush Red   #D4726A  — favorites, notification dots, "not worn" warnings, delete, alerts
Steel Blue  #6B89A8  — discover, wardrobe gaps, info states, shopping companion
Gold        #C4985A  — AI features, utilization %, medium scores 3/5, "new" badges, premium
Lavender    #9B8BB4  — fabric/pattern tags, color analysis, profile/style features
```

#### Dark Theme
```
Background:   #121212       Text Primary:    #F0F0F0
Surface:      #1E1E1E       Text Secondary:  #A0A0A0
Card:         #252525       Text Tertiary:   #666666
Border:       #333333

Primary button inverts: bg #F0F0F0, text #121212
AI banner inverts: light on dark
Toggle ON inverts: bg #F0F0F0, knob #121212

Accents brighten ~15%:
Sage #6DAF8A · Blush #E0877F · Steel #85A3C0 · Gold #D4AD6A · Lavender #B4A3CC
```

### 3.3 Typography

```
Display:  'Cormorant Garamond' (serif) — screen titles, stat numbers, brand
Body:     'Plus Jakarta Sans' (sans-serif) — everything else
```

### 3.4 Component Rules

```
Buttons:     All pill-shaped (StadiumBorder / borderRadius 50px)
Cards:       borderRadius 18-20px, border 1px #F0F0F0
Inputs:      borderRadius 14px (text) or 50px (search)
Chips:       Pill-shaped, active = black fill, inactive = white + border
Tags:        Pill-shaped, color-coded by type
Bottom Nav:  Frosted glass (backdrop-filter blur 24px), active tab = #F5F5F5 pill
Garment Grid: 2 columns, 3:4 aspect ratio images
Overlays:    Frosted glass (rgba(255,255,255,0.9) + blur 8px)
Shadows:     Cards only, very subtle: 0 1px 4px rgba(0,0,0,0.03)
Icons:       Lucide Icons, stroke 1.5px, 22px nav / 18px inline
```

---

## 4. Features & Screens

### 4.1 Information Architecture

```
Tab 1: HOME (Closet + Dashboard)
  ├── Greeting + stats (items, outfits, utilization%)
  ├── Daily outfit suggestion card (weather-aware)
  ├── Search + filter chips
  ├── 2-column garment grid
  ├── Recently worn (story-style circles)
  ├── Wardrobe by color (swatch bar)
  ├── Quick actions (Ask AI, Discover, Pack Trip)
  └── Wardrobe insights (not worn, most worn, gaps)

Tab 2: OUTFITS
  ├── Saved outfit cards with scores
  ├── Wear calendar (month view)
  └── Top pairings (most-worn combinations)

Tab 3: STYLIST (AI Chat)
  ├── Conversational AI interface
  ├── Event preset chips
  ├── Outfit suggestion cards inline
  └── Style explanations ("this works because...")

Tab 4: DISCOVER
  ├── Wardrobe gap alerts
  ├── Shopping recommendations (match %)
  ├── Shopping companion (snap-to-check)
  └── Trending in your style

Tab 5: PROFILE
  ├── Avatar + seasonal color type
  ├── Color palettes (power, neutral, avoid)
  ├── Wardrobe analytics (spending, utilization, cost-per-wear)
  ├── Settings (notifications, weather, repeat detection)
  └── Trip packing history
```

### 4.2 Screen-by-Screen Specification

---

#### SCREEN: Login
- Black app icon (rounded square, white heart inside)
- "Dresser" in Cormorant Garamond 38px
- "Your AI personal stylist" subtitle
- "Continue with Google" — black pill button (primary)
- "Continue with Apple" — outlined pill button
- Divider: "or"
- Email + password inputs (rounded, #FAFAFA bg)
- Password has eye toggle icon
- "Forgot password?" right-aligned
- "Sign in" black pill button
- "Don't have an account? Create one" with underline

---

#### SCREEN: Onboarding Step 1 — Style Quiz
- Progress bar: 3 segments, first filled (black)
- "Discover your style" — Cormorant Garamond 28px
- "Select aesthetics that speak to you"
- 2×2 grid of style cards (4/5 aspect ratio):
  - Minimalist, Classic, Streetwear, Bohemian
  - Each: #F5F5F5 background, white circle icon, name + description
  - Selected state: 2.5px black border + black checkmark circle top-right
  - Unselected: 1px #E8E8E8 border
- "Continue" black pill button

---

#### SCREEN: Onboarding Step 2 — Color Analysis
- Progress bar: 2 of 3 filled
- "Find your colors" heading
- "A selfie helps us recommend your best colors"
- Upload area: dashed 1.5px #DDD border, 28px radius, #FAFAFA bg
  - Camera icon in grey circle
  - "Take a selfie" + tips (natural lighting, face forward, no filters)
- Privacy notice: #F5F5F5 card with lock icon
  - "Your photo is analyzed instantly and never stored"
- "Upload photo" black pill button
- "Skip for now" text link

---

#### SCREEN: Onboarding Step 3 — First Garment
- Progress bar: 3 of 3 filled
- "Build your closet" heading
- Three option cards (white, 1px border, 20px radius):
  - "Take a photo" — camera icon, "Lay flat on a contrasting surface"
  - "Upload from gallery" — image icon, "Select existing photos"
  - "Bulk upload" — upload icon, "Select multiple items at once"
- "Add your first item" black pill button
- "I'll do this later" text link

---

#### SCREEN: Home / Closet (Main Tab)
- **Header:**
  - "Good morning, Rahul" (13px, #999)
  - "My Closet" (Cormorant Garamond 30px)
  - Notification bell (circle, #F5F5F5, with blush dot if unread)
  - Add button (black circle, white + icon)

- **Stats row:** 3 pills (#F5F5F5 bg, 16px radius)
  - Items count (black text)
  - Outfits count (sage text)
  - Utilization % (gold text)

- **Daily outfit card:** (NEW — most important feature)
  - Black background card, 20px radius
  - Star icon in translucent circle
  - "Your look for today" title (white)
  - Weather info: "28°C, Sunny in Bengaluru"
  - Mini outfit preview: 3 small garment thumbnails inline
  - "View outfit →" link
  - Tap opens the outfit detail with full garment images

- **Search bar:** pill-shaped, #F5F5F5, search icon + filter icon right

- **Category chips:** horizontal scroll
  - "All" (active, black fill), "Tops 18", "Bottoms 12", "Outerwear", "Shoes", "Accessories"

- **Garment grid:** 2 columns, 14px gap
  - Each card: 18px radius, 1px #F0F0F0 border
  - Image area: 3:4 ratio, #F5F5F5 placeholder
  - Frosted heart button top-right (filled blush = favorited, outline grey = not)
  - Frosted category pill bottom-left ("Shirt", "Jeans", etc.)
  - Frosted match score bottom-right (sage 5/5, 4/5; gold 3/5; blush 2/5, 1/5)
  - Below image: garment name (13px, 600 weight), color dot + color name + fabric (11px, #999)

---

#### SCREEN: Add Garment
- Back arrow (circle, #F5F5F5) + "Add to closet" heading
- Upload area: dashed border, #FAFAFA bg, upload icon, "Upload a photo" + tip
- After upload shows processing states:
  - "Removing background..." spinner
  - "Generating product photo..." spinner
  - "Analyzing garment..." spinner
  - Green dot + "AI Analysis Complete"
- Results card (white, 1px border, 20px radius):
  - Garment thumbnail (from Gemini product photo) + name + confidence %
  - Edit pencil icon top-right
  - Tag chips (pill-shaped, color-coded):
    - Category: #F5F5F5 bg, #1A1A1A text
    - Color: white bg, border, includes color dot
    - Season: #E7F4ED bg, #2D6B47 text
    - Formality: #E5EFF8 bg, #3A6B8C text
    - Fabric: #F0E5F5 bg, #7B4D8E text
    - Pattern: #FAF0E0 bg, #9E7A3C text
  - "Tap any tag to edit" hint
- "Save to wardrobe" black pill button

---

#### SCREEN: Garment Detail
- Back arrow + favorite heart + more menu (3 dots)
- Full garment image (product photo, 3:4, 20px radius)
- Garment name (Cormorant Garamond 22px)
- "Added 2 weeks ago · Worn 5 times"
- All tag chips
- Stats row: 3 mini cards
  - Times worn (number)
  - Cost per wear (₹ amount, calculated from purchase price / times worn)
  - Color match (score out of 5, colored by sage/gold/blush)
- "Pairs well with" section: horizontal scroll of matching garment thumbnails
- "Mark as worn today" outlined pill button
- "Edit details" / "Move to laundry" / "Remove from closet" actions

---

#### SCREEN: Outfits Tab
- "Outfits" (Cormorant Garamond 30px)
- "Your curated looks"
- Outfit cards (white, 1px border, 20px radius, 16px padding):
  - Garment thumbnails row (64×80px, 14px radius, #F5F5F5)
  - Outfit name (15px, 600 weight)
  - Occasion (12px, #999)
  - Match score pill (sage bg for 90%+, gold for 80-89%)
- **Wear calendar section:**
  - Month name (Cormorant Garamond 20px) + left/right arrows (circles)
  - Calendar grid in a white card (20px radius)
  - Day headers: M T W T F S S
  - Days with outfits: sage bg at 8% opacity, sage text
  - Today: black bg, white text
  - Regular days: #999 text
- **Top pairings section:**
  - "Top pairings" + "See all"
  - Pairing cards: two garment thumbnails with "+" between, name, times paired, badge ("Great pair" sage, "New pair" gold)

---

#### SCREEN: AI Stylist Chat
- Header: black circle avatar with star icon, "Dresser Stylist", green dot "Ready to style"
- Border bottom separator
- Chat messages:
  - AI messages: #F5F5F5 bg, 1px border, 20px radius (bottom-left: 6px)
    - Gold star icon + "STYLIST" label (10px, uppercase, gold color)
    - Message text
    - Outfit suggestion card embedded (if applicable):
      - #F5F5F5 bg, 1px border, 16px radius
      - 3 garment thumbnails in a row
      - Outfit name + description
      - Match score pill
      - **Style explanation** (NEW): "This works because the linen is breathable for Goa's humidity, and the earth tones complement your warm autumn palette."
  - User messages: #1A1A1A bg, white text, 20px radius (bottom-right: 6px)
- **Event preset chips** (above input): ghost buttons — "Work meeting", "Date night", "Wedding", "Casual", "Party"
- Chat input: pill-shaped, 1px border, #FFF bg + send button (black circle, white arrow)

---

#### SCREEN: Shopping Companion (NEW — accessed from Discover tab or camera FAB)
- "Check before you buy" heading
- Camera viewfinder OR image upload area
- After snap/upload, Gemini analyzes and returns:
  - Product photo of the scanned item
  - **"Match report" card:**
    - "Matches X items in your wardrobe" with thumbnail grid of matching garments
    - "Pairs with these outfits" — outfit cards it would work with
    - Color compatibility score against user's skin tone
    - Duplicate warning if similar item exists: "You own 2 similar items" with photos
    - Price comparison if available
  - **Verdict badge:** "Great addition" (sage) / "Think twice" (gold) / "Skip it" (blush)
  - "Save to wishlist" button

---

#### SCREEN: Discover Tab
- "Discover" (Cormorant Garamond 30px)
- "Curated for your wardrobe"
- **Shopping companion button** (prominent, top):
  - "Check an item" with camera icon — opens shopping companion screen
- **Wardrobe gap alert** (#F5F5F5 card, steel blue icon):
  - "Wardrobe gap found" + description of what's missing
- **Shopping recommendation cards** (white, 20px radius):
  - Product image (180px height)
  - Frosted bookmark button top-right
  - Frosted match badge bottom-left ("98% match" in sage)
  - Below: product name, brand, price (₹), "View item" ghost button
- **"Trending in your style"** section: horizontal scroll of items matching user's preferences

---

#### SCREEN: Trip Packing (NEW — accessed from home quick actions or profile)
- "Pack for a trip" heading
- Trip details form:
  - Destination (text input)
  - Dates (date range picker)
  - Activities (multi-select chips: "Hiking", "Dining", "Business", "Beach", "Sightseeing", "Party")
  - "Pack my bag" black pill button
- **Results screen:**
  - Weather forecast for destination/dates
  - "X pieces → Y outfits" summary
  - Capsule wardrobe grid: selected garments organized by category
  - Day-by-day outfit plan with activity labels
  - "Missing for this trip" — items you don't own but would need
  - "Save packing list" button
  - Share button (send list to WhatsApp/Notes)

---

#### SCREEN: Profile Tab
- **Profile header:**
  - Avatar: 88px circle, black bg, white initial (or user photo)
  - Name (Cormorant Garamond 24px)
  - Seasonal color type badge: #F5F5F5 pill, gold text, uppercase

- **Color palettes:**
  - "Power colors" — 6 swatches (48px height, 12px radius, subtle shadow)
  - "Safe neutrals" — 4 swatches
  - "Colors to avoid" — 4 swatches at reduced opacity

- **Wardrobe Analytics section** (NEW):
  - "Your wardrobe in numbers" heading
  - Stat cards:
    - Total items + total value (₹)
    - Average cost-per-wear
    - Most worn item (with photo)
    - Least worn items count (blush colored)
    - Monthly spending trend (mini line chart)
    - "Dresser saved you ₹X" — sum of avoided duplicates + better utilization
  - "View full analytics" link → expanded analytics screen

- **Settings:**
  - Toggle: "Daily outfit notification" (time picker)
  - Toggle: "Color-aware styling"
  - Toggle: "Weather-aware suggestions"
  - Toggle: "Repeat detection" (avoid wearing same outfit within X days)
  - "Connected accounts" — Google Calendar status
  - "Update my photos" outlined pill button
  - "Sign out" (blush text)

---

#### SCREEN: Wardrobe Analytics (NEW — from profile)
- "Wardrobe Analytics" heading
- **Overview cards:** total items, total value, avg cost-per-wear, utilization %
- **Most worn items:** top 5 with photos, wear count, cost-per-wear
- **Least worn items:** items not worn in 30+ days (blush accent)
  - "Wear it or donate it?" prompt
  - Quick action: "Suggest an outfit with this item"
- **Category breakdown:** visual bar showing tops/bottoms/outerwear/shoes/accessories split
- **Color distribution:** swatch bar showing actual wardrobe colors with counts
- **Spending trend:** monthly spending line chart (last 6 months)
- **Savings counter:** "Since joining Dresser, you've avoided X duplicate purchases (₹Y saved)"

---

#### SCREEN: Daily Outfit Notification (NEW)
- Push notification at user-set time each morning:
  - "Good morning! Here's your look for today ☀️ 28°C"
  - Tap opens a dedicated outfit view:
    - Weather bar: temperature, condition, location
    - Calendar peek: "You have: Team standup 10am, Client dinner 7pm" (if calendar connected)
    - **Morning outfit:** casual/work appropriate look
    - **Evening outfit** (if calendar shows evening event): separate dressier suggestion
    - Each outfit: full garment photos, name, reasoning
    - "Wear this" button (logs it to calendar)
    - "Show alternatives" button (swipe through 2-3 more options)
    - "Not today" dismiss

---

## 5. Database Schema

```sql
-- Profiles (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  
  -- Style
  style_preferences TEXT[],
  
  -- Color analysis
  skin_undertone TEXT,          -- warm, cool, neutral
  skin_depth TEXT,              -- fair, light, medium, tan, deep
  hair_tone TEXT,
  eye_color TEXT,
  contrast_level TEXT,          -- low, medium, high
  seasonal_type TEXT,           -- spring, summer, autumn, winter
  power_colors JSONB,
  neutral_colors JSONB,
  avoid_colors JSONB,
  
  -- Settings
  daily_notification_enabled BOOLEAN DEFAULT true,
  daily_notification_time TIME DEFAULT '07:30',
  color_aware_recommendations BOOLEAN DEFAULT true,
  weather_aware_styling BOOLEAN DEFAULT true,
  repeat_detection_enabled BOOLEAN DEFAULT false,
  repeat_detection_days INTEGER DEFAULT 14,
  
  -- Location (for weather)
  location_city TEXT,
  location_lat DECIMAL(10,7),
  location_lng DECIMAL(10,7),
  
  -- Subscription
  subscription_tier TEXT DEFAULT 'free',  -- free, premium
  subscription_expires_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Garments
CREATE TABLE public.garments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Images (all compressed, stored in Supabase Storage)
  original_image_url TEXT NOT NULL,
  display_image_url TEXT,        -- Gemini-generated product photo
  thumbnail_url TEXT,            -- 300x300
  
  -- AI tags
  category TEXT NOT NULL,
  sub_category TEXT,
  colors JSONB NOT NULL,
  dominant_color_hex TEXT,
  dominant_color_name TEXT,
  color_family TEXT,
  pattern TEXT,
  fabric TEXT,
  formality_score INTEGER CHECK (formality_score BETWEEN 1 AND 5),
  season_suitability TEXT[],
  
  -- User data
  user_name TEXT,
  brand TEXT,
  purchase_price DECIMAL(10,2),
  purchase_date DATE,
  size TEXT,
  notes TEXT,
  custom_tags TEXT[],
  
  -- Computed
  skin_compatibility_score INTEGER CHECK (skin_compatibility_score BETWEEN 1 AND 5),
  ai_confidence FLOAT,
  
  -- Status
  status TEXT DEFAULT 'active',  -- active, laundry, retired, donated
  is_favorite BOOLEAN DEFAULT false,
  times_worn INTEGER DEFAULT 0,
  last_worn_date DATE,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Outfits
CREATE TABLE public.outfits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  occasion TEXT,
  garment_ids UUID[] NOT NULL,
  ai_generated BOOLEAN DEFAULT false,
  ai_reasoning TEXT,
  match_score INTEGER,
  times_worn INTEGER DEFAULT 0,
  last_worn_date DATE,
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Wear Log (replaces events table — simpler)
CREATE TABLE public.wear_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  outfit_id UUID REFERENCES public.outfits(id),
  garment_ids UUID[] NOT NULL,
  worn_date DATE NOT NULL DEFAULT CURRENT_DATE,
  occasion TEXT,
  weather_snapshot JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Shopping Companion Log (NEW)
CREATE TABLE public.shopping_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scanned_image_url TEXT,
  product_photo_url TEXT,
  detected_category TEXT,
  detected_colors JSONB,
  matching_garment_ids UUID[],
  matching_outfit_ids UUID[],
  skin_compatibility_score INTEGER,
  duplicate_garment_ids UUID[],
  verdict TEXT,               -- great_addition, think_twice, skip_it
  saved_to_wishlist BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Trip Packing Lists (NEW)
CREATE TABLE public.packing_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  destination TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  activities TEXT[],
  weather_forecast JSONB,
  garment_ids UUID[] NOT NULL,
  daily_outfits JSONB,        -- [{day: 1, activity: "hiking", outfit_garment_ids: [...]}]
  missing_items JSONB,        -- [{category: "outerwear", suggestion: "light windbreaker"}]
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Wishlist (NEW — items user wants to buy)
CREATE TABLE public.wishlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  brand TEXT,
  price DECIMAL(10,2),
  image_url TEXT,
  product_url TEXT,
  detected_colors JSONB,
  skin_compatibility_score INTEGER,
  matching_garment_count INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_garments_user ON garments(user_id);
CREATE INDEX idx_garments_user_status ON garments(user_id, status);
CREATE INDEX idx_garments_user_category ON garments(user_id, category);
CREATE INDEX idx_outfits_user ON outfits(user_id);
CREATE INDEX idx_wear_log_user_date ON wear_log(user_id, worn_date);
CREATE INDEX idx_shopping_checks_user ON shopping_checks(user_id);
CREATE INDEX idx_packing_lists_user ON packing_lists(user_id);
```

---

## 6. API Endpoints

### Auth
```
POST   /api/v1/auth/callback          — Handle Supabase OAuth callback
GET    /api/v1/auth/me                 — Get current user
```

### Profile
```
GET    /api/v1/profile                 — Get profile
PUT    /api/v1/profile                 — Update profile
POST   /api/v1/profile/analyze-color   — Upload selfie → color analysis
DELETE /api/v1/profile/color-data      — Delete color profile
PUT    /api/v1/profile/settings        — Update settings (notifications, etc.)
PUT    /api/v1/profile/location        — Update location (for weather)
```

### Garments
```
GET    /api/v1/garments                — List (filterable: ?category=&status=&favorite=)
POST   /api/v1/garments               — Upload new garment (multipart)
GET    /api/v1/garments/:id            — Detail
PUT    /api/v1/garments/:id            — Update (edit tags, status, etc.)
DELETE /api/v1/garments/:id            — Delete
POST   /api/v1/garments/:id/favorite   — Toggle favorite
POST   /api/v1/garments/:id/worn       — Mark as worn today
GET    /api/v1/garments/stats          — Wardrobe statistics
GET    /api/v1/garments/colors         — Color distribution
```

### Outfits
```
GET    /api/v1/outfits                 — List saved outfits
POST   /api/v1/outfits                 — Save outfit
PUT    /api/v1/outfits/:id             — Update
DELETE /api/v1/outfits/:id             — Delete
POST   /api/v1/outfits/:id/worn        — Log as worn
```

### AI Stylist
```
POST   /api/v1/stylist/recommend       — Event-based recommendations
POST   /api/v1/stylist/daily           — Get daily outfit suggestion
POST   /api/v1/stylist/chat            — Conversational styling
```

### Shopping Companion (NEW)
```
POST   /api/v1/shopping/check          — Scan item → get match report
POST   /api/v1/shopping/wishlist       — Save to wishlist
GET    /api/v1/shopping/wishlist        — Get wishlist
DELETE /api/v1/shopping/wishlist/:id    — Remove from wishlist
```

### Discover
```
GET    /api/v1/discover/gaps           — Wardrobe gap analysis
GET    /api/v1/discover/suggestions    — Shopping recommendations
```

### Trip Packing (NEW)
```
POST   /api/v1/trips/pack              — Generate packing list
GET    /api/v1/trips                    — List past trips
GET    /api/v1/trips/:id               — Trip detail
```

### Analytics (NEW)
```
GET    /api/v1/analytics/overview      — Dashboard stats
GET    /api/v1/analytics/spending      — Spending trends
GET    /api/v1/analytics/utilization   — Wear frequency data
GET    /api/v1/analytics/savings       — Money saved estimate
```

### Wear Log
```
GET    /api/v1/wearlog                 — Get wear history (?month=2026-03)
POST   /api/v1/wearlog                 — Log what was worn
```

---

## 7. AI Pipeline (Gemini-Powered)

### 7.1 Garment Upload Flow

```
User uploads photo (compressed to 1024px, JPEG 90% on client)
  ↓
Backend receives → stores original in Supabase
  ↓
Gemini call 1: Classify input
  → Is it flat-lay, hanger, worn, unclear?
  → Can it be processed? If no → ask retake with tips
  ↓
Gemini call 2: Generate product photo
  → Clean e-commerce flat-lay on white background
  → Store as PNG in Supabase
  ↓
Generate thumbnail (Pillow resize to 300x300)
  ↓
Gemini call 3: Analyze garment (from product photo)
  → Returns: category, colors, pattern, fabric, formality, season
  ↓
Compute skin compatibility score (server-side math, no AI)
  ↓
Store everything in database → return to Flutter
```

### 7.2 Daily Outfit Suggestion

```
Cron job runs at user's notification time
  ↓
Fetch: weather forecast, calendar events (if connected), recent wear log
  ↓
Pre-filter garments: active status, not in laundry, season-appropriate,
  not worn in last N days (if repeat detection on)
  ↓
Gemini call: recommend outfit from filtered garments
  → Considers: weather, formality of calendar events, color profile
  → Returns: outfit with reasoning
  ↓
Send push notification with outfit preview
```

### 7.3 Shopping Companion

```
User snaps photo in store or screenshots product page
  ↓
Gemini call 1: Analyze the scanned item
  → Category, colors, fabric, formality
  ↓
Server: query user's garment database
  → Find matching items (compatible colors, same formality range)
  → Find existing outfits it would extend
  → Check for duplicates (same category + similar colors)
  → Compute skin compatibility score
  ↓
Gemini call 2: Generate verdict
  → "Great addition" / "Think twice" / "Skip it" with reasoning
  ↓
Return match report to Flutter
```

### 7.4 Trip Packing

```
User enters: destination, dates, activities
  ↓
Fetch weather forecast for destination + dates
  ↓
Pre-filter garments by season suitability + status
  ↓
Gemini call: build capsule wardrobe
  → Maximize outfit combinations from minimum items
  → Cover all specified activities
  → Consider weather
  → Identify gaps (items user doesn't own but would need)
  ↓
Return: selected garments, day-by-day outfit plan, missing items
```

### 7.5 Gemini Prompts

#### Input Classification
```
Analyze this photo of a garment. Return ONLY JSON:
{
  "garment_visible": true/false,
  "photo_type": "flat_lay" | "on_hanger" | "worn_by_person" | "folded" | "unclear",
  "background_complexity": "simple" | "moderate" | "complex",
  "lighting_quality": "good" | "fair" | "poor",
  "can_process": true/false,
  "retake_reason": null | "too_blurry" | "garment_not_visible" | "too_dark" | "multiple_items"
}
```

#### Product Photo Generation
```
Look at the garment in this photo. Generate a clean e-commerce product photo:
- Flat-lay on pure white background (#FFFFFF)
- Neatly laid out, no wrinkles, centered with even padding
- Soft, even studio lighting with subtle drop shadow
- Preserve EXACT color, pattern, buttons, stitching, all details
- No mannequin, no person, just the garment on white
- 1024x1024 resolution
Do NOT alter the garment's color or design in any way.
```

#### Garment Analysis (send the generated product photo)
```
Analyze this garment photo. Return ONLY JSON:
{
  "category": "topwear"|"bottomwear"|"footwear"|"outerwear"|"accessory",
  "sub_category": "specific type",
  "colors": [{"hex":"#5B8DBE","name":"light blue","percentage":70}],
  "dominant_color_hex": "#5B8DBE",
  "dominant_color_name": "light blue",
  "color_family": "cool"|"warm"|"neutral",
  "pattern": "solid"|"striped"|"floral"|"plaid"|"abstract"|"geometric"|"checkered",
  "fabric": "cotton"|"silk"|"denim"|"wool"|"synthetic"|"linen"|"leather"|"knit",
  "formality_score": 1-5,
  "season_suitability": ["summer","winter","monsoon","spring","autumn","all-season"],
  "confidence": 0.0-1.0
}
```

#### Skin Tone Analysis
```
Analyze this person's photo for color analysis. Return ONLY JSON:
{
  "skin_undertone": "warm"|"cool"|"neutral",
  "skin_depth": "fair"|"light"|"medium"|"tan"|"deep",
  "hair_tone": "description",
  "eye_color": "description",
  "contrast_level": "low"|"medium"|"high",
  "seasonal_type": "spring"|"summer"|"autumn"|"winter",
  "power_colors": [{"hex":"#...","name":"color name"}],
  "neutral_colors": [{"hex":"#...","name":"color name"}],
  "avoid_colors": [{"hex":"#...","name":"color name"}]
}
```

#### Outfit Recommendation
```
You are a professional stylist. Given the wardrobe and context, suggest 3 outfits.

USER: {seasonal_type} type, {undertone} undertone, {contrast_level} contrast
EVENT: {event_description}
WEATHER: {weather_info}
RECENTLY WORN (avoid): {recent_garment_ids}

AVAILABLE GARMENTS:
{garments_json}

Each outfit needs: 1 top + 1 bottom (or full-body piece) + 1 footwear minimum.
Prioritize: high skin_compatibility_score, unworn items, season-appropriate, color harmony.
Include a STYLE EXPLANATION for each outfit — explain WHY it works.

Return JSON:
{
  "outfits": [{
    "name": "creative name",
    "garment_ids": ["id1","id2","id3"],
    "match_score": 0-100,
    "reasoning": "2-3 sentences why this works",
    "style_tip": "one actionable styling tip for wearing this"
  }]
}
```

#### Shopping Companion Verdict
```
A user is considering buying this item:
{scanned_item_analysis}

Their wardrobe contains:
- {matching_count} items that pair well with it
- {duplicate_count} similar items they already own
- Skin compatibility score: {score}/5

Their seasonal type is {seasonal_type}.

Return JSON:
{
  "verdict": "great_addition"|"think_twice"|"skip_it",
  "reasoning": "2-3 sentences explaining the verdict",
  "suggested_pairings": ["brief description of how to style it with existing items"],
  "savings_note": null | "You own X similar items worth ₹Y — do you really need another?"
}
```

#### Trip Packing
```
Build a capsule wardrobe for this trip:
Destination: {destination}
Dates: {start_date} to {end_date} ({num_days} days)
Activities: {activities}
Weather: {forecast}

Available garments:
{garments_json}

Rules:
- Maximize outfit combinations from minimum items
- Each activity type needs at least 1 appropriate outfit
- Include basics: enough underwear/socks for the trip
- Consider re-wearing items across days
- Flag items the user doesn't own but would need

Return JSON:
{
  "selected_garment_ids": ["id1","id2",...],
  "total_pieces": N,
  "total_outfits_possible": N,
  "daily_plan": [
    {"day": 1, "date": "2026-12-15", "activity": "sightseeing",
     "outfit_garment_ids": ["id1","id2","id3"],
     "weather": "28°C sunny"}
  ],
  "missing_items": [
    {"category": "outerwear", "suggestion": "light windbreaker for evening breeze"}
  ]
}
```

---

## 8. Image Handling

### 8.1 Client-Side Compression (Flutter)

```dart
// Use flutter_image_compress package
Future<Uint8List> compressForUpload(Uint8List imageBytes) async {
  return await FlutterImageCompress.compressWithList(
    imageBytes,
    minWidth: 1024,
    minHeight: 1024,
    quality: 90,           // JPEG 90% — visually lossless
    format: CompressFormat.jpeg,
  );
}
// Result: 12MP photo (5MB) → 1024px JPEG 90% (~300KB)
```

### 8.2 Storage Strategy

```
dresser-originals/{user_id}/{uuid}.jpg    — Compressed upload (~300KB)
dresser-display/{user_id}/{uuid}.png      — Gemini product photo (~300KB)
dresser-thumbnails/{user_id}/{uuid}.jpg   — 300x300 thumbnail (~30KB)

Total per garment: ~630KB
Free tier (1GB): ~1,500 garments → ~35-40 users
Pro tier (100GB): ~150,000 garments → ~3,500+ users
```

### 8.3 Bandwidth Optimization

- Use `cached_network_image` in Flutter — caches images locally after first load
- Serve display/thumbnail images from public Supabase buckets (CDN)
- Load thumbnails in grid, full images only on detail screen
- Lazy load grid items as user scrolls

---

## 9. Flutter Project Structure

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── theme.dart              # DresserColors, DresserTextStyles, DresserTheme
│   ├── routes.dart             # GoRouter configuration
│   └── constants.dart          # API URLs, storage keys
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── onboarding_screen.dart    # 3-step (style, color, first garment)
│   │   └── providers/
│   │       └── auth_provider.dart
│   ├── home/
│   │   ├── screens/
│   │   │   ├── home_screen.dart          # Main closet + dashboard
│   │   │   ├── add_garment_screen.dart
│   │   │   └── garment_detail_screen.dart
│   │   ├── widgets/
│   │   │   ├── daily_outfit_card.dart    # The black AI suggestion card
│   │   │   ├── garment_card.dart         # 2-col grid card with overlays
│   │   │   ├── stat_pill.dart
│   │   │   ├── category_chips.dart
│   │   │   └── color_bar.dart            # Wardrobe by color
│   │   └── providers/
│   │       └── garments_provider.dart
│   ├── outfits/
│   │   ├── screens/
│   │   │   ├── outfits_screen.dart       # List + calendar
│   │   │   └── outfit_detail_screen.dart
│   │   ├── widgets/
│   │   │   ├── outfit_card.dart
│   │   │   ├── wear_calendar.dart
│   │   │   └── pairing_card.dart
│   │   └── providers/
│   │       └── outfits_provider.dart
│   ├── stylist/
│   │   ├── screens/
│   │   │   └── stylist_chat_screen.dart
│   │   ├── widgets/
│   │   │   ├── chat_bubble.dart
│   │   │   ├── outfit_suggestion_card.dart
│   │   │   └── event_presets.dart
│   │   └── providers/
│   │       └── stylist_provider.dart
│   ├── discover/
│   │   ├── screens/
│   │   │   ├── discover_screen.dart
│   │   │   └── shopping_companion_screen.dart   # NEW
│   │   ├── widgets/
│   │   │   ├── product_card.dart
│   │   │   ├── gap_alert.dart
│   │   │   └── match_report_card.dart           # NEW
│   │   └── providers/
│   │       └── discover_provider.dart
│   ├── profile/
│   │   ├── screens/
│   │   │   ├── profile_screen.dart
│   │   │   ├── analytics_screen.dart            # NEW
│   │   │   └── trip_packing_screen.dart          # NEW
│   │   ├── widgets/
│   │   │   ├── color_palette_row.dart
│   │   │   ├── analytics_card.dart               # NEW
│   │   │   └── settings_toggle.dart
│   │   └── providers/
│   │       └── profile_provider.dart
│   └── notifications/                            # NEW
│       ├── services/
│       │   └── notification_service.dart
│       └── screens/
│           └── daily_outfit_screen.dart
├── shared/
│   ├── widgets/
│   │   ├── pill_button.dart
│   │   ├── frosted_overlay.dart
│   │   ├── search_bar.dart
│   │   ├── bottom_nav.dart
│   │   ├── tag_chip.dart
│   │   └── loading_shimmer.dart
│   ├── models/
│   │   ├── garment.dart
│   │   ├── outfit.dart
│   │   ├── wear_log_entry.dart
│   │   ├── shopping_check.dart
│   │   ├── packing_list.dart
│   │   └── user_profile.dart
│   └── services/
│       ├── api_service.dart          # Dio HTTP client
│       ├── storage_service.dart      # Supabase storage
│       ├── camera_service.dart       # Image picker + compression
│       └── weather_service.dart      # OpenWeatherMap
└── utils/
    ├── color_utils.dart
    ├── date_utils.dart
    └── image_utils.dart              # Compression helpers
```

---

## 10. Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter

  # UI
  google_fonts: ^6.0.0
  cached_network_image: ^3.0.0
  shimmer: ^3.0.0
  flutter_staggered_grid_view: ^0.7.0
  flutter_animate: ^4.0.0
  smooth_page_indicator: ^1.1.0
  lucide_icons: ^0.257.0
  fl_chart: ^0.68.0                # For analytics charts

  # State & Routing
  flutter_riverpod: ^2.0.0
  go_router: ^14.0.0

  # Auth & Backend
  supabase_flutter: ^2.0.0
  google_sign_in: ^6.0.0
  dio: ^5.0.0

  # Camera & Images
  image_picker: ^1.0.0
  flutter_image_compress: ^2.1.0

  # Notifications
  flutter_local_notifications: ^17.0.0
  firebase_messaging: ^15.0.0       # For push notifications

  # Utilities
  intl: ^0.19.0
  shared_preferences: ^2.0.0
  flutter_dotenv: ^5.0.0
  permission_handler: ^11.0.0       # Camera, notifications permissions
```

---

## 11. Backend Structure

```
backend/
├── main.py                         # FastAPI app, CORS, middleware
├── config.py                       # Env vars, Supabase client init
├── requirements.txt
├── routers/
│   ├── garments.py
│   ├── outfits.py
│   ├── stylist.py
│   ├── profile.py
│   ├── discover.py
│   ├── shopping.py                 # NEW: shopping companion
│   ├── trips.py                    # NEW: trip packing
│   ├── analytics.py                # NEW: wardrobe analytics
│   ├── wearlog.py
│   └── notifications.py            # NEW: daily outfit generation
├── services/
│   ├── gemini_service.py           # ALL AI calls (see Section 7)
│   ├── weather_service.py          # OpenWeatherMap integration
│   ├── storage_service.py          # Supabase Storage helpers
│   └── notification_service.py     # Push notification dispatch
├── models/                         # Pydantic models
│   ├── garment.py
│   ├── outfit.py
│   ├── profile.py
│   ├── shopping.py
│   ├── trip.py
│   └── analytics.py
├── tasks/
│   └── daily_outfit.py             # Cron job: generate daily suggestions
└── utils/
    ├── auth.py                     # Supabase JWT verification
    ├── color_scoring.py            # Skin compatibility math
    └── image_utils.py              # Thumbnail generation
```

### requirements.txt
```
fastapi==0.115.0
uvicorn==0.30.0
python-multipart==0.0.12
pydantic==2.9.0
supabase==2.10.0
google-generativeai==0.8.0
Pillow==11.0.0
python-dotenv==1.0.1
httpx==0.28.0
apscheduler==3.10.0              # For daily notification cron
firebase-admin==6.5.0            # For push notifications
```

---

## 12. Monetization

### 12.1 Freemium Model

```
FREE TIER:
  - Up to 30 garments
  - 5 AI styling requests / month
  - Basic garment tagging
  - Manual outfit creation
  - Wear calendar

PREMIUM (₹149/month or ₹999/year):
  - Unlimited garments
  - Unlimited AI styling
  - Daily outfit notifications (weather + calendar aware)
  - Shopping companion (scan-to-check)
  - Trip packing assistant
  - Full wardrobe analytics
  - Color profile analysis
  - Social sharing
  - Priority AI processing
```

### 12.2 Affiliate Revenue

Shopping recommendations in Discover tab link to retailers. Earn commission on purchases. User pays nothing extra. Potential partners: Myntra, Ajio, Amazon Fashion, Flipkart Fashion.

### 12.3 The Upgrade Trigger

Don't gate features upfront. Let users:
1. Upload 30 garments (invest effort)
2. See how good the AI is (experience value)
3. Hit the limit: "Add more clothes! Upgrade to unlimited"

By this point they've invested time photographing items — they won't abandon that investment. Conversion happens naturally.

---

## 13. MVP Roadmap

### Phase 1: Foundation (Weeks 1-3)
- Supabase setup (database, auth, storage, RLS policies)
- Flutter scaffold (navigation, theme, routes)
- Google OAuth login
- FastAPI skeleton with auth middleware

### Phase 2: Core Catalog (Weeks 4-6)
- Image upload with compression
- Gemini pipeline: classify → generate product photo → analyze
- Closet grid view with filters and favorites
- Garment detail screen
- Add garment flow with tag review

### Phase 3: AI Stylist (Weeks 7-8)
- Chat interface
- Outfit recommendation with style explanations
- Event presets
- Save/manage outfits
- Wear calendar and logging

### Phase 4: Daily Habit (Weeks 9-10)
- Weather API integration
- Daily outfit suggestion generation (cron job)
- Push notifications
- "Wear this" logging flow

### Phase 5: Shopping Companion (Weeks 11-12)
- Scan/upload item check
- Match report with verdict
- Wishlist
- Duplicate detection

### Phase 6: Intelligence (Weeks 13-14)
- Color profile analysis (selfie)
- Skin compatibility scoring
- Wardrobe analytics (spending, utilization, cost-per-wear)
- Color distribution visualization

### Phase 7: Trip & Social (Weeks 15-16)
- Trip packing assistant
- Social outfit sharing
- Onboarding polish
- App store preparation

---

## 14. Environment Variables

### Backend (.env)
```
GEMINI_API_KEY=your-billing-enabled-key
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
OPENWEATHER_API_KEY=your-openweather-key
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

### Flutter (.env)
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=https://your-backend-url.com
```

---

*End of Dresser Product & Development Guide v5.0*
*Feed this alongside UI reference HTML files to Claude CLI to begin building.*
