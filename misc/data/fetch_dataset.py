"""
fetch_dataset.py - Dresser seed data: Step 1
=============================================
Downloads the Kaggle Fashion Product Images dataset, selects representative
garments by gender and category, copies the images to seed_images/, and writes
seed_images/metadata.json.

Run this first, then run upload_to_app.py.

Usage:
    python data/fetch_dataset.py --gender both
    python data/fetch_dataset.py --gender male
    python data/fetch_dataset.py --gender female

    # Already have the dataset on disk?
    python data/fetch_dataset.py --gender both --dataset-dir /path/to/fashion-dataset
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import random
import shutil
import zipfile
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

KAGGLE_DATASET = "paramaggarwal/fashion-product-images-small"

OUTPUT_DIR    = Path("seed_images")
METADATA_PATH = OUTPUT_DIR / "metadata.json"

# Items to pick per gender per Dresser category.
# Adjust these counts to seed more or fewer garments.
ITEMS_PER_SLOT: dict[str, int] = {
    "topwear":    6,
    "bottomwear": 5,
    "outerwear":  2,
    "footwear":   3,
    "accessory":  2,
}
# Female-only: dresses are picked separately so they don't crowd out
# shirts/blouses in the topwear bucket.
FEMALE_DRESS_COUNT = 2

# Reproducible selection -- change the seed to get different items
RANDOM_SEED = 42

# ---------------------------------------------------------------------------
# Kaggle -> Dresser category mapping
# (master, sub, article) -- None = wildcard, checked top-to-bottom
# ---------------------------------------------------------------------------

_CATEGORY_MAP: list[tuple[tuple[str | None, str | None, str | None], str]] = [
    ((None, "Dress",      None), "dress"),
    ((None, "Saree",      None), "dress"),
    ((None, "Topwear",    None), "topwear"),
    ((None, "Bottomwear", None), "bottomwear"),
    ((None, "Outerwear",  None), "outerwear"),
    (("Apparel", None, "Jacket"), "outerwear"),
    (("Apparel", None, "Blazer"), "outerwear"),
    (("Apparel", None, "Coat"),   "outerwear"),
    (("Footwear", None, None),    "footwear"),
    (("Accessories", None, None), "accessory"),
    (("Personal Care", None, None), "accessory"),
]


def _map_category(master: str, sub: str, article: str) -> str | None:
    for (m, s, a), dresser_cat in _CATEGORY_MAP:
        if m and m.lower() != master.lower():
            continue
        if s and s.lower() != sub.lower():
            continue
        if a and a.lower() != article.lower():
            continue
        return dresser_cat
    return None


# ---------------------------------------------------------------------------
# Progress bar (ASCII-only for Windows cp1252 compatibility)
# ---------------------------------------------------------------------------

_BAR_WIDTH = 30


def _bar(current: int, total: int) -> str:
    filled = int(_BAR_WIDTH * current / max(total, 1))
    return "[" + "#" * filled + "." * (_BAR_WIDTH - filled) + "]"


def _status(current: int, total: int, label: str, icon: str = "~") -> None:
    print(f"  {_bar(current, total)} {current}/{total}  {icon} {label}")


# ---------------------------------------------------------------------------
# Metadata helpers
# ---------------------------------------------------------------------------

def _load_metadata() -> dict:
    if METADATA_PATH.exists():
        with open(METADATA_PATH) as f:
            return json.load(f)
    return {"male": [], "female": []}


def _save_metadata(meta: dict) -> None:
    METADATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(METADATA_PATH, "w") as f:
        json.dump(meta, f, indent=2)


def _find_entry(meta: dict, gender: str, index: int) -> dict | None:
    for e in meta.get(gender, []):
        if e["index"] == index:
            return e
    return None


# ---------------------------------------------------------------------------
# Kaggle download + extraction
# ---------------------------------------------------------------------------

KAGGLE_DOWNLOAD_URL = (
    "https://www.kaggle.com/api/v1/datasets/download/" + KAGGLE_DATASET
)


def _resolve_token() -> str:
    """
    Return the Kaggle Bearer token from env var or ~/.kaggle/kaggle.json.
    Supports both the new KGAT_* bearer tokens and legacy username/key pairs.
    """
    # 1. Explicit env var (highest priority)
    token = os.environ.get("KAGGLE_TOKEN") or os.environ.get("KAGGLE_KEY")
    if token:
        return token

    # 2. ~/.kaggle/kaggle.json
    cfg_path = Path.home() / ".kaggle" / "kaggle.json"
    if cfg_path.exists():
        with open(cfg_path) as f:
            cfg = json.load(f)
        # New format: {"token": "KGAT_..."}
        if "token" in cfg:
            return cfg["token"]
        # Legacy format: {"username": "...", "key": "..."}
        if "username" in cfg and "key" in cfg:
            return cfg["key"]

    raise SystemExit(
        "\n  ERROR: No Kaggle credentials found.\n"
        "  Set KAGGLE_TOKEN=<your_token> as an environment variable, or\n"
        "  place your token in ~/.kaggle/kaggle.json as:\n"
        '  {"token": "KGAT_your_token_here"}\n'
    )


def _download_dataset(dest_dir: Path) -> Path:
    """
    Download the Kaggle dataset zip via the Kaggle HTTP API and extract it.
    Returns the extracted directory that contains styles.csv.
    """
    dest_dir.mkdir(parents=True, exist_ok=True)
    extract_dir = dest_dir / "extracted"

    existing_zips = list(dest_dir.glob("*.zip"))
    zip_path = existing_zips[0] if existing_zips else dest_dir / "fashion-small.zip"

    if not zip_path.exists():
        token = _resolve_token()
        print(f"  Downloading {KAGGLE_DATASET} (~572 MB) ...")

        with requests.get(
            KAGGLE_DOWNLOAD_URL,
            headers={"Authorization": f"Bearer {token}"},
            stream=True,
            timeout=300,
        ) as resp:
            if resp.status_code == 401:
                raise SystemExit(
                    "\n  ERROR: Kaggle API returned 401 Unauthorized.\n"
                    "  Check that your token is valid and not expired.\n"
                )
            if resp.status_code == 403:
                raise SystemExit(
                    "\n  ERROR: Kaggle API returned 403 Forbidden.\n"
                    "  Visit the dataset page on Kaggle and accept the license:\n"
                    f"  https://www.kaggle.com/datasets/{KAGGLE_DATASET}\n"
                )
            resp.raise_for_status()

            total_bytes = int(resp.headers.get("content-length", 0))
            downloaded  = 0
            with open(zip_path, "wb") as f:
                for chunk in resp.iter_content(chunk_size=1024 * 1024):
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_bytes:
                        pct = downloaded / total_bytes * 100
                        mb  = downloaded / 1024 / 1024
                        print(f"\r  Downloading ... {mb:.1f} MB  ({pct:.0f}%)   ", end="", flush=True)

        size_mb = zip_path.stat().st_size / 1024 / 1024
        print(f"\r  Downloaded -> {zip_path.name} ({size_mb:.1f} MB)              ")
    else:
        print(f"  Found existing zip: {zip_path.name}")

    if not extract_dir.exists():
        print(f"  Extracting {zip_path.name} ...")
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(extract_dir)
        print(f"  Extracted -> {extract_dir}/")
    else:
        print(f"  Already extracted at {extract_dir}/")

    return extract_dir


def _find_dataset_root(base: Path) -> tuple[Path, Path]:
    """Locate styles.csv and the images/ folder anywhere under base."""
    candidates = list(base.rglob("styles.csv"))
    if not candidates:
        raise FileNotFoundError(
            f"styles.csv not found under {base}. "
            "Delete the extracted/ folder and re-run to re-extract."
        )
    styles_csv = candidates[0]
    images_dir = styles_csv.parent / "images"
    if not images_dir.is_dir():
        raise FileNotFoundError(
            f"images/ folder not found next to styles.csv at {styles_csv.parent}"
        )
    return styles_csv, images_dir


# ---------------------------------------------------------------------------
# Dataset parsing + selection
# ---------------------------------------------------------------------------

def _load_styles(styles_csv: Path) -> list[dict]:
    rows: list[dict] = []
    with open(styles_csv, encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            rows.append(row)
    return rows


def _select_items(
    rows: list[dict],
    gender: str,
    images_dir: Path,
) -> list[dict]:
    """
    Filter styles.csv rows for the requested gender, bucket them by Dresser
    category, randomly pick the configured number from each bucket, and return
    the final list.
    """
    rng = random.Random(RANDOM_SEED)

    allowed_genders = (
        {"men", "boys", "unisex"} if gender == "male"
        else {"women", "girls", "unisex"}
    )

    buckets: dict[str, list[dict]] = {cat: [] for cat in ITEMS_PER_SLOT}
    dress_bucket: list[dict] = []

    for row in rows:
        row_gender = (row.get("gender") or "").strip().lower()
        if row_gender not in allowed_genders:
            continue

        master  = (row.get("masterCategory") or "").strip()
        sub     = (row.get("subCategory") or "").strip()
        article = (row.get("articleType") or "").strip()

        dresser_cat = _map_category(master, sub, article)
        if dresser_cat is None:
            continue

        item_id = (row.get("id") or "").strip()
        if not (images_dir / f"{item_id}.jpg").exists():
            continue  # image missing in small dataset

        item = {
            "kaggle_id":    item_id,
            "name":         (row.get("productDisplayName") or article).strip(),
            "dresser_cat":  dresser_cat,
            "article_type": article,
            "base_colour":  (row.get("baseColour") or "").strip(),
            "season":       (row.get("season") or "").strip(),
            "usage":        (row.get("usage") or "").strip(),
            "src_path":     str(images_dir / f"{item_id}.jpg"),
        }

        if dresser_cat == "dress" and gender == "female":
            dress_bucket.append(item)
        elif dresser_cat in buckets:
            buckets[dresser_cat].append(item)

    selected: list[dict] = []

    for cat, n in ITEMS_PER_SLOT.items():
        pool = buckets[cat]
        rng.shuffle(pool)
        picked = pool[:n]
        if len(picked) < n:
            print(f"  WARNING: {gender}/{cat}: only {len(picked)}/{n} items available")
        selected.extend(picked)

    if gender == "female":
        rng.shuffle(dress_bucket)
        dresses = dress_bucket[:FEMALE_DRESS_COUNT]
        if len(dresses) < FEMALE_DRESS_COUNT:
            print(f"  WARNING: {gender}/dress: only {len(dresses)}/{FEMALE_DRESS_COUNT} items available")
        selected.extend(dresses)

    return selected


# ---------------------------------------------------------------------------
# Copy phase
# ---------------------------------------------------------------------------

def fetch_and_store(gender: str, dataset_base: Path) -> None:
    styles_csv, images_dir = _find_dataset_root(dataset_base)

    print()
    print(f"  {'-' * 50}")
    print(f"  Selecting & storing {gender.upper()} garment images")
    print(f"  {'-' * 50}")

    rows    = _load_styles(styles_csv)
    items   = _select_items(rows, gender, images_dir)
    total   = len(items)
    out_dir = OUTPUT_DIR / gender
    out_dir.mkdir(parents=True, exist_ok=True)

    meta = _load_metadata()
    meta.setdefault(gender, [])

    for i, item in enumerate(items, start=1):
        safe_name = item["name"].lower()[:40].replace(" ", "_").replace("/", "_")
        filename  = f"{i:02d}_{safe_name}.jpg"
        dest      = out_dir / filename

        existing = _find_entry(meta, gender, i)

        if dest.exists() and existing and existing.get("stored"):
            _status(i, total, f"{item['name']} - already stored, skipping", ">>")
            continue

        _status(i, total, item["name"])
        shutil.copy2(item["src_path"], dest)

        entry: dict = {
            "index":        i,
            "filename":     filename,
            "name":         item["name"],
            "gender":       gender,
            "category":     item["dresser_cat"],
            "article_type": item["article_type"],
            "base_colour":  item["base_colour"],
            "season":       item["season"],
            "usage":        item["usage"],
            "kaggle_id":    item["kaggle_id"],
            "stored":       True,
            "uploaded":     False,
            "garment_id":   None,
        }

        if existing:
            existing.update(entry)
        else:
            meta[gender].append(entry)

        _save_metadata(meta)   # save after every item -- crash safe
        _status(i, total, f"{item['name']} -> {filename}", "OK")

    stored = sum(1 for e in meta.get(gender, []) if e.get("stored"))
    print()
    print(f"  DONE: {stored}/{total} images stored in {out_dir}/")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Dresser seed data -- Step 1: fetch from Kaggle and store locally",
    )
    parser.add_argument(
        "--gender", choices=["male", "female", "both"], default="both",
        help="Which wardrobe to fetch (default: both)",
    )
    parser.add_argument(
        "--dataset-dir", default="./fashion-dataset",
        help="Directory to download/look for the Kaggle dataset (default: ./fashion-dataset)",
    )
    args = parser.parse_args()

    genders     = ["male", "female"] if args.gender == "both" else [args.gender]
    dataset_dir = Path(args.dataset_dir)

    print()
    print("=" * 60)
    print("  DRESSER -- Fetch Dataset  (Step 1 of 2)")
    print("=" * 60)
    print(f"  Source:  Kaggle / {KAGGLE_DATASET}")
    print(f"  Gender:  {args.gender}")
    print(f"  Output:  {OUTPUT_DIR}/")
    print()

    extracted = _download_dataset(dataset_dir)

    for gender in genders:
        fetch_and_store(gender, extracted)

    meta         = _load_metadata()
    total_stored = sum(len(meta.get(g, [])) for g in genders)

    print()
    print("=" * 60)
    print("  Step 1 complete!")
    print(f"  Images:   {OUTPUT_DIR}/")
    print(f"  Metadata: {METADATA_PATH}  ({total_stored} items)")
    print()
    print("  Next step:")
    print("    python data/upload_to_app.py \\")
    print("        --api-url http://localhost:8000 \\")
    print("        --token YOUR_SUPABASE_JWT_TOKEN")
    print("=" * 60)
    print()


if __name__ == "__main__":
    main()
