# Dresser — Seed Data

Two scripts to populate a Dresser user account with a full demo wardrobe.

```
data/
├── fetch_dataset.py   # Step 1 — download from Kaggle, store images locally
└── upload_to_app.py   # Step 2 — upload stored images to the Dresser API
```

---

## How it works

**Step 1 — `fetch_dataset.py`**
Downloads the [Kaggle Fashion Product Images (Small)](https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small)
dataset, selects representative garments by gender and category, copies the
images to `seed_images/`, and writes `seed_images/metadata.json`.

**Step 2 — `upload_to_app.py`**
Reads `metadata.json`, posts each image to `POST /api/v1/garments`, and records
the returned garment ID. The API handles all AI analysis internally (quality
check, product photo generation, category/color/fabric extraction).

---

## Garments seeded

| Gender | Tops | Bottoms | Dresses | Outerwear | Footwear | Accessories | Total |
|--------|------|---------|---------|-----------|----------|-------------|-------|
| Male   | 6    | 5       | —       | 2         | 3        | 2           | **18** |
| Female | 5    | 4       | 2       | 1         | 3        | 3           | **18** |

---

## Prerequisites

### 1. Python 3.10+

```bash
python --version
```

### 2. Install dependencies

```bash
pip install kaggle requests
```

### 3. Set up Kaggle API credentials

1. Go to [kaggle.com/settings](https://www.kaggle.com/settings) → **API** → **Create New Token**
2. This downloads `kaggle.json`
3. Place it at:
   - macOS / Linux: `~/.kaggle/kaggle.json`
   - Windows: `C:\Users\<your-username>\.kaggle\kaggle.json`
4. macOS/Linux only — restrict permissions:
   ```bash
   chmod 600 ~/.kaggle/kaggle.json
   ```

The file looks like:
```json
{"username": "your_username", "key": "your_api_key"}
```

### 4. Accept the dataset license on Kaggle

Visit the dataset page and click **Download** once to accept the terms —
the API download won't work without this:

[kaggle.com/datasets/paramaggarwal/fashion-product-images-small](https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small)

### 5. Get your Supabase auth token *(Step 2 only)*

Copy the JWT from any authenticated API call's `Authorization: Bearer <token>`
header, or from the Supabase Dashboard → Authentication → Users → your user.

---

## Step 1 — Fetch dataset

Run from the **repo root** (`Dresser/`):

```bash
# Both genders (default)
python data/fetch_dataset.py

# Single gender
python data/fetch_dataset.py --gender male
python data/fetch_dataset.py --gender female

# Already downloaded the dataset? Point to it directly:
python data/fetch_dataset.py --dataset-dir /path/to/fashion-dataset
```

The dataset (~572 MB) downloads once to `./fashion-dataset/` and is reused on
subsequent runs. Images are copied to `seed_images/male/` and `seed_images/female/`.

**Output:**
```
seed_images/
├── male/
│   ├── 01_<name>.jpg
│   ├── 02_<name>.jpg
│   └── ...  (18 files)
├── female/
│   ├── 01_<name>.jpg
│   └── ...  (18 files)
└── metadata.json
```

---

## Step 2 — Upload to app

Make sure the Dresser backend is running, then:

```bash
python data/upload_to_app.py \
    --api-url http://localhost:8000 \
    --token YOUR_SUPABASE_JWT_TOKEN
```

**Preview without uploading (dry run):**
```bash
python data/upload_to_app.py --dry-run
```

**Upload a single gender:**
```bash
python data/upload_to_app.py --gender male \
    --api-url http://localhost:8000 \
    --token YOUR_JWT
```

For each image the API will:
1. Check image quality
2. Generate a clean product photo via Gemini
3. Extract category, colors, fabric, formality, season
4. Store the garment in Supabase and return the garment ID

---

## Resume support

Both scripts are safe to re-run — they check `metadata.json` before each item:

- **Step 1:** image file exists + `stored: true` → skips copy, prints `⏭ already stored`
- **Step 2:** `uploaded: true` + `garment_id` set → skips upload, prints `⏭ already uploaded`

---

## metadata.json structure

Written after every successfully stored/uploaded item:

```json
{
  "male": [
    {
      "index": 1,
      "filename": "01_slim_fit_chinos.jpg",
      "name": "Slim Fit Chinos",
      "gender": "male",
      "category": "bottomwear",
      "article_type": "Trousers",
      "base_colour": "Khaki",
      "season": "Summer",
      "usage": "Casual",
      "kaggle_id": "15970",
      "stored": true,
      "uploaded": false,
      "garment_id": null
    }
  ],
  "female": [...]
}
```

After upload `uploaded` becomes `true` and `garment_id` is populated.

---

## Flags reference

### fetch_dataset.py

| Flag | Default | Description |
|------|---------|-------------|
| `--gender` | `both` | `male`, `female`, or `both` |
| `--dataset-dir` | `./fashion-dataset` | Where to download / look for the dataset |

### upload_to_app.py

| Flag | Default | Description |
|------|---------|-------------|
| `--gender` | `both` | `male`, `female`, or `both` |
| `--api-url` | `http://localhost:8000` | Dresser API base URL |
| `--token` | *(required)* | Supabase JWT auth token |
| `--dry-run` | off | Preview what would be uploaded without sending requests |

---

## Troubleshooting

**`kaggle package not installed`**
Run `pip install kaggle`.

**`404` from Kaggle API**
You haven't accepted the dataset license on Kaggle — visit the dataset page and
click Download once.

**`401 - Unauthorized` from Kaggle API**
Your `kaggle.json` credentials are wrong. Re-download from kaggle.com/settings.

**`styles.csv not found`**
The zip didn't extract correctly. Delete `./fashion-dataset/extracted/` and re-run.

**`Cannot reach http://localhost:8000`**
The Dresser backend isn't running. Start it with `uvicorn main:app --reload`
from the `backend/` directory.

**`401` from Dresser API**
Your Supabase JWT is expired. Re-authenticate and copy a fresh token.

**`422` from Dresser API**
The image was rejected (garment not clearly visible). Check the specific image
file manually — some Kaggle images are low quality or cropped awkwardly.

**Only N/18 items for a category**
The small dataset doesn't cover every category equally. The script warns and
seeds as many as it finds. Use the full dataset if you need all slots filled:
change `KAGGLE_DATASET` in `fetch_dataset.py` to
`paramaggarwal/fashion-product-images-dataset`.
