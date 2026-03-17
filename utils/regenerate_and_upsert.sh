#!/bin/bash

# Regenerate CSV files and upsert to database
# Usage: ./regenerate_and_upsert.sh

set -e

echo "==================================================================="
echo "Plant Encyclopedia: Regenerate CSVs and Upsert to Database"
echo "==================================================================="
echo ""

# Step 1: Generate CSV files from existing data
echo "Step 1: Generating CSV files from plant data..."
python generate_csv_exports.py

echo ""
echo "==================================================================="
echo ""

# Step 2: Upsert to database
echo "Step 2: Upserting data to database..."
python upsert_plants_to_db.py

echo ""
echo "==================================================================="
echo "✅ All done!"
echo "==================================================================="

