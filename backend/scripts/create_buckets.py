"""
Creates the required Supabase storage buckets for Dresser.
Run from the backend folder:
    python scripts/create_buckets.py
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from services.supabase_client import supabase

BUCKETS = [
    {"name": "dresser-originals",   "public": False},   # Compressed originals (private)
    {"name": "dresser-display",     "public": True},    # Gemini-generated product photos (CDN)
    {"name": "dresser-thumbnails",  "public": True},    # 300x300 thumbnails (CDN)
]

def main():
    existing = {b.name for b in supabase.storage.list_buckets()}

    for bucket in BUCKETS:
        name = bucket["name"]
        if name in existing:
            print(f"  skip  {name}  (already exists)")
            continue
        supabase.storage.create_bucket(name, options={"public": bucket["public"]})
        visibility = "public" if bucket["public"] else "private"
        print(f"created  {name}  ({visibility})")

    print("\nDone.")

if __name__ == "__main__":
    main()
