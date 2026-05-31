"""
upload_to_app.py — Dresser seed uploader
=========================================
Uploads all images from  data/seed_images/<gender>/  to a specific user's
wardrobe via the admin batch-import endpoint.

Gemini still analyses every garment for category, colours, formality, etc.
The image-cleanup pipeline (background removal / Gemini image generation) is
skipped because these are already clean product photos.

Auth uses the Supabase service role key from backend/.env — no user JWT needed.

Usage
-----
    python data/upload_to_app.py --gender male --user-id <UUID>

    # Point at staging instead of localhost
    python data/upload_to_app.py --gender male --user-id <UUID> \\
        --api-url https://your-backend.fly.dev

    # Dry-run: list files that would be uploaded
    python data/upload_to_app.py --gender male --user-id <UUID> --dry-run

    # Override the images directory (default: data/seed_images/<gender>/)
    python data/upload_to_app.py --gender male --user-id <UUID> \\
        --images-dir /path/to/my/photos

Options
-------
--gender       male | female           (required)
--user-id      Supabase auth user UUID (required)
--api-url      Dresser backend URL     (default: http://localhost:8000)
--images-dir   override image folder   (default: data/seed_images/<gender>/)
--batch-size   files per API call      (default: 10, max 50)
--dry-run      list files, no upload
--env-file     path to .env file       (default: backend/.env)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

ADMIN_BATCH_ENDPOINT = "/api/v1/admin/garments/import/batch"
REQUEST_TIMEOUT      = 300   # seconds — batch of 10 clean images through Gemini
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
DEFAULT_BATCH_SIZE   = 10
MAX_BATCH_SIZE       = 50


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_images(images_dir: Path) -> list[Path]:
    return sorted(
        p for p in images_dir.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def _mime(path: Path) -> str:
    return {
        ".jpg":  "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png":  "image/png",
        ".webp": "image/webp",
    }.get(path.suffix.lower(), "image/jpeg")


def _verify_user(supabase_url: str, service_key: str, user_id: str) -> None:
    """Confirm the user exists in Supabase Auth before we start uploading."""
    headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
    res = requests.get(
        f"{supabase_url}/auth/v1/admin/users/{user_id}",
        headers=headers,
        timeout=15,
    )
    if res.status_code == 404:
        print(f"\n  ERROR: User {user_id} not found in Supabase Auth.\n")
        sys.exit(1)
    if not res.ok:
        print(f"\n  ERROR: Supabase auth check failed ({res.status_code}): {res.text[:200]}\n")
        sys.exit(1)


def _upload_batch(
    paths: list[Path],
    user_id: str,
    batch_num: int,
    total_batches: int,
    api_url: str,
    service_key: str,
    dry_run: bool,
) -> tuple[int, int, list[str]]:
    """
    POST one batch to the admin import endpoint.
    Returns (succeeded, total_in_batch, list_of_error_messages).
    """
    if dry_run:
        for p in paths:
            print(f"    [dry-run] {p.name}")
        return len(paths), len(paths), []

    print(f"  Batch {batch_num}/{total_batches}: uploading {len(paths)} file(s)...", end="", flush=True)

    headers      = {"X-Service-Key": service_key}
    file_handles = [(p, open(p, "rb")) for p in paths]
    files        = [("files", (p.name, fh, _mime(p))) for p, fh in file_handles]
    data         = {"user_id": user_id, "clean": "true"}

    try:
        res = requests.post(
            f"{api_url.rstrip('/')}{ADMIN_BATCH_ENDPOINT}",
            headers=headers,
            files=files,
            data=data,
            timeout=REQUEST_TIMEOUT,
        )
    finally:
        for _, fh in file_handles:
            fh.close()

    if res.status_code == 403:
        print(f"\n\n  ERROR: Forbidden (403) — service key mismatch or wrong env.\n")
        sys.exit(1)

    if not res.ok:
        print(f" FAILED (HTTP {res.status_code})")
        return 0, len(paths), [f"HTTP {res.status_code}: {res.text[:200]}"]

    payload   = res.json().get("data", {})
    succeeded = payload.get("succeeded", 0)
    failed    = payload.get("failed", 0)
    results   = payload.get("results", [])

    errors = [
        f"{r['filename']}: {r.get('message', 'unknown error')}"
        for r in results if r.get("status") == "error"
    ]

    print(f"  {succeeded} ok, {failed} failed")
    for r in results:
        icon    = "OK" if r["status"] == "ok" else "!!"
        garment = r.get("garment") or {}
        cat     = garment.get("category") or "?"
        sub     = garment.get("sub_category") or "?"
        gid     = (garment.get("id") or "")[:8]
        msg     = r.get("message", "")
        if r["status"] == "ok":
            print(f"    {icon}  {r['filename']:<40} -> {cat}/{sub}  ({gid}...)")
        else:
            print(f"    {icon}  {r['filename']:<40}    {msg}")

    return succeeded, len(paths), errors


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Upload seed garment images to a Dresser user's wardrobe.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--gender",  required=True, choices=["male", "female"],
                        help="Gender of wardrobe (determines the source folder)")
    parser.add_argument("--user-id", required=True, dest="user_id",
                        help="Supabase auth user UUID to upload into")
    parser.add_argument("--api-url", default="http://localhost:8000",
                        help="Dresser backend URL (default: http://localhost:8000)")
    parser.add_argument("--images-dir", default=None, dest="images_dir",
                        help="Override image folder (default: data/seed_images/<gender>/)")
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE,
                        dest="batch_size",
                        help=f"Files per API call (default: {DEFAULT_BATCH_SIZE}, max: {MAX_BATCH_SIZE})")
    parser.add_argument("--env-file", default=None, dest="env_file",
                        help="Path to .env file (default: backend/.env)")
    parser.add_argument("--dry-run", action="store_true",
                        help="List files that would be uploaded without sending requests")
    args = parser.parse_args()

    # ── Load .env ────────────────────────────────────────────────────────────
    script_dir = Path(__file__).parent
    repo_root  = script_dir.parent
    env_file   = Path(args.env_file) if args.env_file else repo_root / "backend" / ".env"
    load_dotenv(env_file)

    supabase_url = os.getenv("SUPABASE_URL", "")
    service_key  = os.getenv("SUPABASE_SERVICE_KEY", "")

    if not args.dry_run and (not supabase_url or not service_key):
        print("\n  ERROR: SUPABASE_URL / SUPABASE_SERVICE_KEY not found in .env.\n")
        sys.exit(1)

    # ── Resolve images directory ─────────────────────────────────────────────
    images_dir = Path(args.images_dir) if args.images_dir else script_dir / "seed_images" / args.gender

    if not images_dir.exists():
        print(f"\n  ERROR: Images directory not found: {images_dir}")
        print(f"  Create the folder and place your clean product photos there.\n")
        sys.exit(1)

    images = _find_images(images_dir)
    if not images:
        print(f"\n  ERROR: No image files found in {images_dir}")
        print(f"  Supported formats: {', '.join(sorted(SUPPORTED_EXTENSIONS))}\n")
        sys.exit(1)

    # ── Verify user exists before uploading anything ──────────────────────────
    if not args.dry_run:
        print(f"  Verifying user {args.user_id}...", end="", flush=True)
        _verify_user(supabase_url, service_key, args.user_id)
        print(" ok")

    # ── Batch plan ───────────────────────────────────────────────────────────
    batch_size = min(max(1, args.batch_size), MAX_BATCH_SIZE)
    batches    = [images[i:i + batch_size] for i in range(0, len(images), batch_size)]

    print()
    print("=" * 60)
    print("  DRESSER -- Seed Uploader")
    print("=" * 60)
    print(f"  Gender:      {args.gender}")
    print(f"  User ID:     {args.user_id}")
    print(f"  Source:      {images_dir}")
    print(f"  Images:      {len(images)} file(s)")
    print(f"  Batch size:  {batch_size} files/request  ({len(batches)} batch(es))")
    print(f"  Endpoint:    {args.api_url}{ADMIN_BATCH_ENDPOINT}")
    if args.dry_run:
        print("  Mode:        DRY RUN — no requests will be sent")
    print("=" * 60)
    print()

    # ── Upload ───────────────────────────────────────────────────────────────
    total_success = 0
    total_items   = 0
    all_errors: list[str] = []

    for batch_num, batch in enumerate(batches, start=1):
        s, t, errs = _upload_batch(
            batch, args.user_id, batch_num, len(batches),
            args.api_url, service_key, args.dry_run,
        )
        total_success += s
        total_items   += t
        all_errors.extend(errs)
        print()

    # ── Final summary ─────────────────────────────────────────────────────────
    print("=" * 60)
    if args.dry_run:
        print(f"  DRY RUN: {total_items} file(s) would be uploaded")
    else:
        print(f"  Done: {total_success}/{total_items} garments added to wardrobe")
        if all_errors:
            print(f"\n  {len(all_errors)} error(s):")
            for e in all_errors:
                print(f"    !! {e}")
    print("=" * 60)
    print()


if __name__ == "__main__":
    main()
