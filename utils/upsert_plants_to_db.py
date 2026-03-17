"""
Upsert plant species and articles from CSV files to the database.

This script reads the generated CSV files (plants_species.csv and plants_articles.csv)
and upserts them into the plants.species and plants.articles tables.
It also loads short descriptions from plant_articles.json to use as species descriptions.
"""

import asyncio
import csv
import json
import os
from pathlib import Path
from typing import Optional
import asyncpg
from dotenv import load_dotenv

# Load environment variables from parent api directory
api_dir = Path(__file__).parent.parent / "api"
dotenv_path = api_dir / ".env"
load_dotenv(dotenv_path=dotenv_path)


async def get_database_url() -> str:
    """Get database URL from environment variables."""
    db_url = os.getenv("APP__SUPABASE__DATABASE_URL")
    if not db_url:
        raise ValueError("APP__SUPABASE__DATABASE_URL not found in environment variables")
    return db_url


async def upsert_species(conn: asyncpg.Connection, species_data: dict) -> int:
    """
    Upsert a plant species record and return its ID.
    
    Args:
        conn: Database connection
        species_data: Dictionary containing species data
        
    Returns:
        The species ID
    """
    query = """
    INSERT INTO plants.species (scientific_name, common_name, description, image_url)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (scientific_name) 
    DO UPDATE SET
        common_name = EXCLUDED.common_name,
        description = EXCLUDED.description,
        image_url = EXCLUDED.image_url
    RETURNING id
    """
    
    scientific_name = species_data['scientific_name'].strip()
    common_name = species_data.get('common_name', '').strip() or None
    description = species_data.get('description', '').strip() or None
    image_url = species_data.get('image_url', '').strip() or None
    
    species_id = await conn.fetchval(
        query,
        scientific_name,
        common_name,
        description,
        image_url
    )
    
    return species_id


async def upsert_article(
    conn: asyncpg.Connection,
    species_id: int,
    article_content: str,
    published: bool = True
) -> None:
    """
    Upsert a plant article record.
    
    Args:
        conn: Database connection
        species_id: ID of the species this article belongs to
        article_content: The article content
        published: Whether the article is published
    """
    query = """
    INSERT INTO plants.articles (species_id, article_content, published, updated_at)
    VALUES ($1, $2, $3, NOW())
    ON CONFLICT (species_id)
    DO UPDATE SET
        article_content = EXCLUDED.article_content,
        published = EXCLUDED.published,
        updated_at = NOW()
    """
    
    await conn.execute(query, species_id, article_content, published)


async def load_species_from_csv(file_path: Path) -> list[dict]:
    """Load species data from CSV file."""
    species_list = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Skip care_notes if it exists (no longer used)
            if 'care_notes' in row:
                del row['care_notes']
            if 'thumbnail_url' in row:
                del row['thumbnail_url']
            species_list.append(row)
    
    return species_list


async def load_articles_from_csv(file_path: Path) -> dict[str, dict]:
    """
    Load articles data from CSV file.
    
    Returns:
        Dictionary mapping scientific_name to article data
    """
    articles_dict = {}
    
    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            scientific_name = row['scientific_name'].strip()
            articles_dict[scientific_name] = {
                'article_content': row.get('article_content', '').strip(),
                'published': row.get('published', 'true').lower() == 'true'
            }
    
    return articles_dict


async def load_short_descriptions_from_json(file_path: Path) -> dict[str, str]:
    """
    Load short descriptions from plant_articles.json.
    
    Returns:
        Dictionary mapping scientific_name to short_description
    """
    descriptions_dict = {}
    
    if not file_path.exists():
        print(f"Warning: {file_path} not found, short descriptions will not be loaded")
        return descriptions_dict
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
        for article in data.get('articles', []):
            if article.get('success'):
                scientific_name = article.get('scientific_name', '').strip()
                short_description = article.get('short_description', '').strip()
                if scientific_name and short_description:
                    descriptions_dict[scientific_name] = short_description
    
    return descriptions_dict


async def main():
    """Main function to upsert plant data."""
    script_dir = Path(__file__).parent
    species_csv = script_dir / "plants_species.csv"
    articles_csv = script_dir / "plants_articles.csv"
    articles_json = script_dir / "plant_articles.json"
    
    # Check if files exist
    if not species_csv.exists():
        print(f"Error: {species_csv} not found")
        return
    
    if not articles_csv.exists():
        print(f"Error: {articles_csv} not found")
        return
    
    print("Loading data from CSV and JSON files...")
    species_list = await load_species_from_csv(species_csv)
    articles_dict = await load_articles_from_csv(articles_csv)
    descriptions_dict = await load_short_descriptions_from_json(articles_json)
    
    print(f"Loaded {len(species_list)} species")
    print(f"Loaded {len(articles_dict)} articles")
    print(f"Loaded {len(descriptions_dict)} short descriptions")
    
    # Connect to database
    db_url = await get_database_url()
    print(f"\nConnecting to database...")
    
    conn = await asyncpg.connect(db_url)
    
    try:
        # Upsert species and articles
        print("\nUpserting species and articles...")
        species_count = 0
        articles_count = 0
        skipped_count = 0
        
        for species_data in species_list:
            scientific_name = species_data['scientific_name'].strip()
            
            if not scientific_name:
                skipped_count += 1
                continue
            
            # Override description with short_description from JSON if available
            if scientific_name in descriptions_dict:
                species_data['description'] = descriptions_dict[scientific_name]
            
            # Upsert species
            species_id = await upsert_species(conn, species_data)
            species_count += 1
            
            # Upsert article if it exists
            if scientific_name in articles_dict:
                article_data = articles_dict[scientific_name]
                if article_data['article_content']:
                    await upsert_article(
                        conn,
                        species_id,
                        article_data['article_content'],
                        article_data['published']
                    )
                    articles_count += 1
            
            # Progress indicator
            if species_count % 50 == 0:
                print(f"  Processed {species_count} species, {articles_count} articles...")
        
        print(f"\n✅ Complete!")
        print(f"  Species upserted: {species_count}")
        print(f"  Articles upserted: {articles_count}")
        print(f"  Skipped (empty scientific name): {skipped_count}")
        
    finally:
        await conn.close()
        print("\nDatabase connection closed.")


if __name__ == "__main__":
    asyncio.run(main())

