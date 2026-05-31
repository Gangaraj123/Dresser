-- =============================================================
-- Dresser App — Database Initialization Script
-- Run once against your Supabase / PostgreSQL instance.
-- =============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- =============================================================
-- TABLES
-- =============================================================

-- Profiles (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id                          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name                TEXT,
  avatar_url                  TEXT,
  style_preferences           TEXT[],
  skin_undertone              TEXT,
  skin_depth                  TEXT,
  hair_tone                   TEXT,
  eye_color                   TEXT,
  contrast_level              TEXT,
  seasonal_type               TEXT,
  power_colors                JSONB,
  neutral_colors              JSONB,
  avoid_colors                JSONB,
  color_aware_recommendations BOOLEAN     DEFAULT true,
  weather_aware_styling       BOOLEAN     DEFAULT true,
  repeat_detection            BOOLEAN     DEFAULT false,
  created_at                  TIMESTAMPTZ DEFAULT now(),
  updated_at                  TIMESTAMPTZ DEFAULT now()
);

-- Garments
CREATE TABLE IF NOT EXISTS public.garments (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  original_image_url      TEXT,
  processed_image_url     TEXT,
  display_image_url       TEXT,
  thumbnail_url           TEXT,
  category                TEXT        NOT NULL,
  sub_category            TEXT,
  colors                  JSONB       NOT NULL DEFAULT '[]',
  dominant_color_hex      TEXT,
  dominant_color_name     TEXT,
  color_family            TEXT,
  color_brightness        FLOAT,
  pattern                 TEXT,
  fabric                  TEXT,
  formality_score         INTEGER     CHECK (formality_score BETWEEN 1 AND 5),
  season_suitability      TEXT[],
  user_name               TEXT,
  brand                   TEXT,
  purchase_price          DECIMAL(10,2),
  size                    TEXT,
  notes                   TEXT,
  custom_tags             TEXT[],
  skin_compatibility_score INTEGER    CHECK (skin_compatibility_score BETWEEN 1 AND 5),
  versatility_score       FLOAT,
  status                  TEXT        DEFAULT 'active' CHECK (status IN ('active','laundry','retired','donated')),
  times_worn              INTEGER     DEFAULT 0,
  last_worn_date          DATE,
  ai_confidence           FLOAT,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

-- Outfits
CREATE TABLE IF NOT EXISTS public.outfits (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name           TEXT        NOT NULL,
  occasion       TEXT,
  garment_ids    UUID[]      NOT NULL,
  ai_generated   BOOLEAN     DEFAULT false,
  ai_reasoning   TEXT,
  match_score    INTEGER     CHECK (match_score BETWEEN 0 AND 100),
  times_worn     INTEGER     DEFAULT 0,
  last_worn_date DATE,
  is_favorite    BOOLEAN     DEFAULT false,
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now()
);

-- Events (wear log)
CREATE TABLE IF NOT EXISTS public.events (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_date       DATE        NOT NULL,
  description      TEXT,
  dress_code       TEXT,
  location         TEXT,
  weather_snapshot JSONB,
  outfit_id        UUID        REFERENCES public.outfits(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Recommendations log
CREATE TABLE IF NOT EXISTS public.recommendations (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_description    TEXT,
  suggested_outfit_ids UUID[],
  reasoning            TEXT,
  match_score          INTEGER,
  user_action          TEXT        CHECK (user_action IN ('accepted','rejected','modified','ignored')),
  created_at           TIMESTAMPTZ DEFAULT now()
);


-- =============================================================
-- INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_garments_user     ON public.garments(user_id);
CREATE INDEX IF NOT EXISTS idx_garments_category ON public.garments(user_id, category);
CREATE INDEX IF NOT EXISTS idx_garments_status   ON public.garments(user_id, status);
CREATE INDEX IF NOT EXISTS idx_garments_formality ON public.garments(user_id, formality_score);
CREATE INDEX IF NOT EXISTS idx_outfits_user      ON public.outfits(user_id);
CREATE INDEX IF NOT EXISTS idx_events_user_date  ON public.events(user_id, event_date);


-- =============================================================
-- ROW LEVEL SECURITY
-- =============================================================

-- ---- profiles -----------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own" ON public.profiles FOR DELETE USING (auth.uid() = id);

-- ---- garments -----------------------------------------------
ALTER TABLE public.garments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "garments_select_own" ON public.garments;
CREATE POLICY "garments_select_own" ON public.garments FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "garments_insert_own" ON public.garments;
CREATE POLICY "garments_insert_own" ON public.garments FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "garments_update_own" ON public.garments;
CREATE POLICY "garments_update_own" ON public.garments FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "garments_delete_own" ON public.garments;
CREATE POLICY "garments_delete_own" ON public.garments FOR DELETE USING (auth.uid() = user_id);

-- ---- outfits ------------------------------------------------
ALTER TABLE public.outfits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "outfits_select_own" ON public.outfits;
CREATE POLICY "outfits_select_own" ON public.outfits FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "outfits_insert_own" ON public.outfits;
CREATE POLICY "outfits_insert_own" ON public.outfits FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "outfits_update_own" ON public.outfits;
CREATE POLICY "outfits_update_own" ON public.outfits FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "outfits_delete_own" ON public.outfits;
CREATE POLICY "outfits_delete_own" ON public.outfits FOR DELETE USING (auth.uid() = user_id);

-- ---- events -------------------------------------------------
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events_select_own" ON public.events;
CREATE POLICY "events_select_own" ON public.events FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "events_insert_own" ON public.events;
CREATE POLICY "events_insert_own" ON public.events FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "events_update_own" ON public.events;
CREATE POLICY "events_update_own" ON public.events FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "events_delete_own" ON public.events;
CREATE POLICY "events_delete_own" ON public.events FOR DELETE USING (auth.uid() = user_id);

-- ---- recommendations ----------------------------------------
ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recommendations_select_own" ON public.recommendations;
CREATE POLICY "recommendations_select_own" ON public.recommendations FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "recommendations_insert_own" ON public.recommendations;
CREATE POLICY "recommendations_insert_own" ON public.recommendations FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "recommendations_update_own" ON public.recommendations;
CREATE POLICY "recommendations_update_own" ON public.recommendations FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "recommendations_delete_own" ON public.recommendations;
CREATE POLICY "recommendations_delete_own" ON public.recommendations FOR DELETE USING (auth.uid() = user_id);


-- =============================================================
-- TRIGGER — auto-create profile on new Supabase auth sign-up
-- =============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
