import asyncio
import json
import os
from pathlib import Path
from typing import Optional
import httpx
from tqdm.asyncio import tqdm_asyncio

# API configuration
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8443/api/v1")


async def create_species(
    client: httpx.AsyncClient,
    scientific_name: str,
    common_name: Optional[str],
    semaphore: asyncio.Semaphore
) -> dict:
    """Create a plant species in the database."""
    
    async with semaphore:
        try:
            response = await client.post(
                f"{API_BASE_URL}/plants/species",
                json={
                    "scientific_name": scientific_name,
                    "common_name": common_name,
                    "description": f"A species of plant in the {scientific_name.split()[0]} genus.",
                }
            )
            response.raise_for_status()
            return {
                "success": True,
                "data": response.json(),
                "error": None
            }
        except Exception as e:
            return {
                "success": False,
                "data": None,
                "error": str(e)
            }


async def create_article(
    client: httpx.AsyncClient,
    species_id: int,
    article_content: str,
    semaphore: asyncio.Semaphore
) -> dict:
    """Create an article for a plant species."""
    
    async with semaphore:
        try:
            response = await client.post(
                f"{API_BASE_URL}/plants/species/{species_id}/article",
                params={
                    "article_content": article_content,
                    "published": True
                }
            )
            response.raise_for_status()
            return {
                "success": True,
                "data": response.json(),
                "error": None
            }
        except Exception as e:
            return {
                "success": False,
                "data": None,
                "error": str(e)
            }


async def import_plant_with_article(
    client: httpx.AsyncClient,
    plant_data: dict,
    semaphore: asyncio.Semaphore
) -> dict:
    """Import a plant species and its article."""
    
    scientific_name = plant_data["scientific_name"]
    common_name = plant_data["common_name"]
    article = plant_data["article"]
    
    # Create species first
    species_result = await create_species(client, scientific_name, common_name, semaphore)
    
    if not species_result["success"]:
        return {
            "scientific_name": scientific_name,
            "common_name": common_name,
            "success": False,
            "error": f"Failed to create species: {species_result['error']}"
        }
    
    species_id = species_result["data"]["id"]
    
    # Create article
    article_result = await create_article(client, species_id, article, semaphore)
    
    if not article_result["success"]:
        return {
            "scientific_name": scientific_name,
            "common_name": common_name,
            "success": False,
            "error": f"Created species but failed to create article: {article_result['error']}"
        }
    
    return {
        "scientific_name": scientific_name,
        "common_name": common_name,
        "success": True,
        "species_id": species_id,
        "error": None
    }


async def import_all_articles(
    articles_file: str = "plant_articles.json",
    max_concurrent: int = 5
) -> None:
    """Import all plant articles from JSON file to database."""
    
    # Load articles from JSON
    articles_path = Path(__file__).parent / articles_file
    
    if not articles_path.exists():
        print(f"Error: Could not find {articles_path}")
        return
    
    print(f"Loading articles from {articles_path}...")
    with open(articles_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    articles = data["articles"]
    print(f"Found {len(articles)} articles to import")
    
    semaphore = asyncio.Semaphore(max_concurrent)
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Create tasks for all articles
        tasks = [
            import_plant_with_article(client, article, semaphore)
            for article in articles
        ]
        
        print(f"Importing plants with {max_concurrent} concurrent requests...")
        results = await tqdm_asyncio.gather(*tasks, desc="Importing plants")
    
    # Analyze results
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]
    
    print(f"\nCompleted: {len(successful)} successful, {len(failed)} failed")
    
    if failed:
        print(f"\nFailed imports:")
        for item in failed[:10]:
            print(f"  - {item['common_name']} ({item['scientific_name']}): {item['error']}")
        
        # Save failed imports
        failed_path = Path(__file__).parent / "failed_imports.json"
        with open(failed_path, 'w', encoding='utf-8') as f:
            json.dump(failed, f, indent=2, ensure_ascii=False)
        print(f"\nFailed imports saved to: {failed_path}")


def main():
    """Main entry point."""
    print("Plant Encyclopedia Article Importer")
    print("=" * 50)
    
    # Check API URL
    print(f"API URL: {API_BASE_URL}")
    
    # Run import
    asyncio.run(import_all_articles(
        articles_file="plant_articles.json",
        max_concurrent=5  # Lower concurrency to avoid overwhelming the API
    ))


if __name__ == "__main__":
    main()

