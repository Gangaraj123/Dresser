-- Run this once in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Adds FCM push notification columns to the profiles table.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token                  TEXT,
  ADD COLUMN IF NOT EXISTS daily_notification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS daily_notification_time    TIME    NOT NULL DEFAULT '08:00:00',
  ADD COLUMN IF NOT EXISTS notification_timezone      TEXT    NOT NULL DEFAULT 'Asia/Kolkata';
