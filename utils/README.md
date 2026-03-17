# Plant Encyclopedia Utilities

This directory contains utilities for managing the plant encyclopedia data.

## Setup

1. Install dependencies:
```bash
uv sync
```

2. Ensure you have the API `.env` file set up in the `../api` directory with:
```env
APP__SUPABASE__DATABASE_URL=postgresql://...
```

## Scripts

### 1. Generate CSV Files

**Script:** `generate_csv_exports.py`

Generates two CSV files from the source data:
- `plants_species.csv` - Plant species information
- `plants_articles.csv` - Plant encyclopedia articles

**Usage:**
```bash
python generate_csv_exports.py
```

**Input:**
- `../Plants_Formatted.csv` - Source plant data
- `plant_articles.json` - Generated articles (if available)

**Output:**
- `plants_species.csv` - Species data (scientific_name, common_name, description, image_url)
- `plants_articles.csv` - Article data (scientific_name, article_content, published)

### 2. Generate Plant Articles

**Script:** `generate_plant_articles.py`

Uses OpenAI to generate encyclopedia articles for plants.

**Usage:**
```bash
# Generate all articles
python generate_plant_articles.py

# Skip first 100 plants
python generate_plant_articles.py --skip 100

# Generate only 50 articles
python generate_plant_articles.py --limit 50
```

**Requirements:**
- `OPENAI_API_KEY` environment variable set

### 3. Upsert Plants to Database

**Script:** `upsert_plants_to_db.py`

Upserts plant species and articles from CSV files to the database.

**Usage:**
```bash
python upsert_plants_to_db.py
```

**What it does:**
- Reads `plants_species.csv` and `plants_articles.csv`
- Reads `plant_articles.json` to extract short descriptions
- Uses short descriptions from JSON as the species description field
- Upserts data to `plants.species` and `plants.articles` tables
- Uses ON CONFLICT to update existing records
- Matches articles to species by scientific_name

**Requirements:**
- `APP__SUPABASE__DATABASE_URL` environment variable (from `../api/.env`)
- `plant_articles.json` file (optional, but recommended for descriptions)

### 4. Complete Workflow

**Script:** `regenerate_and_upsert.sh`

Runs the complete workflow: generate CSVs and upsert to database.

**Usage:**
```bash
chmod +x regenerate_and_upsert.sh
./regenerate_and_upsert.sh
```

**Steps:**
1. Generates CSV files from source data
2. Upserts data to database

## Files

- `plants_species.csv` - Generated species data
- `plants_articles.csv` - Generated article data
- `plant_articles.json` - Raw article data from OpenAI
- `Plants_Formatted.csv` - Source plant data (in parent directory)

## Database Schema

### plants.species
- `id` - Auto-generated ID
- `scientific_name` - Unique scientific name
- `common_name` - Common name
- `description` - Short description
- `image_url` - Image URL

### plants.articles
- `id` - Auto-generated ID
- `species_id` - Foreign key to species
- `article_content` - Full article text
- `published` - Boolean flag
- `created_at` - Timestamp
- `updated_at` - Timestamp

## Notes

- The `care_notes` field has been removed from the schema
- CSV files are UTF-8 encoded
- Duplicate scientific names are automatically handled by ON CONFLICT
- Articles are matched to species by scientific_name

