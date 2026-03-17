#!/bin/bash

# Plant Encyclopedia Article Generator - Example Usage
# This script demonstrates the complete workflow

echo "==================================="
echo "Plant Encyclopedia Article Generator"
echo "==================================="
echo ""

# Step 1: Set API key
echo "Step 1: Set your OpenAI API key"
echo "export OPENAI_API_KEY='your-api-key-here'"
echo ""

# Step 2: Generate articles
echo "Step 2: Generate articles for all plants"
echo "python generate_plant_articles.py"
echo ""

# Step 3: Review
echo "Step 3: Review generated articles in plant_articles.json"
echo ""

# Step 4: Start API
echo "Step 4: Start the API server (in another terminal)"
echo "cd ../api"
echo "uvicorn main:app --reload --port 8443"
echo ""

# Step 5: Import
echo "Step 5: Import articles to database"
echo "export API_BASE_URL='http://localhost:8443/api/v1'"
echo "python import_plant_articles.py"
echo ""

echo "Done! Check your plant encyclopedia at /plant-encyclopedia"

