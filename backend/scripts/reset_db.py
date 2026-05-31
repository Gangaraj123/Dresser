#!/usr/bin/env python3
"""
reset_db.py — Wipe ALL app data including Supabase Auth users.

WARNING: This is destructive and irreversible. Use only in development.

Usage:
    python backend/scripts/reset_db.py
    python backend/scripts/reset_db.py --yes   # skip confirmation prompt
"""
import os
import sys
import argparse
from pathlib import Path

import psycopg2
import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")


def truncate_tables(conn):
    """Delete all rows from app tables in dependency order."""
    tables = [
        "public.recommendations",
        "public.events",
        "public.outfits",
        "public.garments",
        "public.profiles",
    ]
    cur = conn.cursor()
    for table in tables:
        cur.execute(f"TRUNCATE TABLE {table} CASCADE;")
        print(f"  ✓ Truncated {table}")
    conn.commit()
    cur.close()


_STORAGE_BUCKETS = ["dresser-originals", "dresser-display", "dresser-thumbnails"]


def delete_storage(supabase_url: str, service_key: str):
    """Empty all Dresser storage buckets via the Supabase Storage REST API."""
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/json",
    }

    for bucket in _STORAGE_BUCKETS:
        # List all objects (recursive, 1 000 at a time)
        offset = 0
        all_names: list[str] = []
        while True:
            res = requests.post(
                f"{supabase_url}/storage/v1/object/list/{bucket}",
                headers=headers,
                json={"prefix": "", "limit": 1000, "offset": offset, "sortBy": {"column": "name", "order": "asc"}},
            )
            if res.status_code == 404:
                print(f"  – Bucket '{bucket}' not found, skipping")
                break
            res.raise_for_status()
            objects = res.json()
            if not objects:
                break
            names = [o["name"] for o in objects if o.get("name")]
            all_names.extend(names)
            if len(objects) < 1000:
                break
            offset += 1000

        if not all_names:
            print(f"  ✓ {bucket}: empty")
            continue

        # Delete in batches of 100
        deleted = 0
        for i in range(0, len(all_names), 100):
            batch = all_names[i : i + 100]
            del_res = requests.delete(
                f"{supabase_url}/storage/v1/object/{bucket}",
                headers=headers,
                json={"prefixes": batch},
            )
            del_res.raise_for_status()
            deleted += len(batch)
        print(f"  ✓ {bucket}: deleted {deleted} file(s)")


_STORAGE_BUCKETS = ["dresser-originals", "dresser-display", "dresser-thumbnails"]


def delete_storage(supabase_url: str, service_key: str):
    """Empty all Dresser storage buckets via the Supabase Storage REST API."""
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/json",
    }

    for bucket in _STORAGE_BUCKETS:
        offset = 0
        all_names: list[str] = []
        while True:
            res = requests.post(
                f"{supabase_url}/storage/v1/object/list/{bucket}",
                headers=headers,
                json={"prefix": "", "limit": 1000, "offset": offset, "sortBy": {"column": "name", "order": "asc"}},
            )
            if res.status_code == 404:
                print(f"  - Bucket '{bucket}' not found, skipping")
                break
            res.raise_for_status()
            objects = res.json()
            if not objects:
                break
            names = [o["name"] for o in objects if o.get("name")]
            all_names.extend(names)
            if len(objects) < 1000:
                break
            offset += 1000

        if not all_names:
            print(f"  + {bucket}: empty")
            continue

        deleted = 0
        for i in range(0, len(all_names), 100):
            batch = all_names[i : i + 100]
            del_res = requests.delete(
                f"{supabase_url}/storage/v1/object/{bucket}",
                headers=headers,
                json={"prefixes": batch},
            )
            del_res.raise_for_status()
            deleted += len(batch)
        print(f"  + {bucket}: deleted {deleted} file(s)")


def delete_auth_users(supabase_url: str, service_key: str):
    """List and delete every user via the Supabase Admin Auth API."""
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
    }

    # Fetch all users (paginated, max 1000 per page)
    page = 1
    all_users = []
    while True:
        res = requests.get(
            f"{supabase_url}/auth/v1/admin/users",
            headers=headers,
            params={"page": page, "per_page": 1000},
        )
        res.raise_for_status()
        data = res.json()
        users = data.get("users", [])
        all_users.extend(users)
        if len(users) < 1000:
            break
        page += 1

    if not all_users:
        print("  No auth users found.")
        return

    for user in all_users:
        uid = user["id"]
        email = user.get("email", "<no email>")
        del_res = requests.delete(
            f"{supabase_url}/auth/v1/admin/users/{uid}",
            headers=headers,
        )
        if del_res.status_code in (200, 204):
            print(f"  ✓ Deleted user {email} ({uid})")
        else:
            print(f"  ✗ Failed to delete {email} ({uid}): {del_res.status_code} {del_res.text}")


def main():
    parser = argparse.ArgumentParser(description="Wipe all Dresser app data.")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    db_url = os.getenv("DATABASE_URL")
    supabase_url = os.getenv("SUPABASE_URL")
    service_key = os.getenv("SUPABASE_SERVICE_KEY")

    missing = [k for k, v in [("DATABASE_URL", db_url), ("SUPABASE_URL", supabase_url), ("SUPABASE_SERVICE_KEY", service_key)] if not v]
    if missing:
        print(f"ERROR: Missing env vars: {', '.join(missing)}")
        sys.exit(1)

    if not args.yes:
        print("⚠️  This will permanently delete ALL data and ALL auth users.")
        answer = input("Type 'yes' to continue: ")
        if answer.strip().lower() != "yes":
            print("Aborted.")
            sys.exit(0)

    print("\n── Truncating tables ────────────────────────────────")
    conn = psycopg2.connect(db_url)
    conn.autocommit = False
    try:
        truncate_tables(conn)
    except Exception as e:
        conn.rollback()
        print(f"ERROR truncating tables: {e}")
        conn.close()
        sys.exit(1)
    conn.close()

    print("\n── Deleting storage files ───────────────────────────")
    try:
        delete_storage(supabase_url, service_key)
    except Exception as e:
        print(f"ERROR deleting storage: {e}")
        sys.exit(1)

    print("\n── Deleting auth users ──────────────────────────────")
    try:
        delete_auth_users(supabase_url, service_key)
    except Exception as e:
        print(f"ERROR deleting auth users: {e}")
        sys.exit(1)

    print("\n✓ Reset complete.")


if __name__ == "__main__":
    main()
