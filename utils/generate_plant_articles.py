import asyncio
import json
import os
from pathlib import Path
import pandas as pd
from tqdm.asyncio import tqdm_asyncio
from openai import AsyncOpenAI
from typing import Optional
from dotenv import load_dotenv
from argparse import ArgumentParser

load_dotenv()

parser = ArgumentParser()
parser.add_argument('--skip', type=int, default=0, help='Number of plants to skip')
parser.add_argument('--limit', type=int, default=0, help='Number of plants to generate')
args = parser.parse_args()

# Initialize OpenAI client
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# System prompt for generating plant articles
SYSTEM_PROMPT = """
Role: You are a professional horticulturist and botanical researcher.

Task: Write content about a specific plant for a garden encyclopedia in a structured JSON format.

Input Format:
* COMMON_NAME: string
* SCIENTIFIC_NAME: string

Output Format:
You must return a valid JSON object with exactly two fields:
{
  "short_description": "A concise 1-2 sentence summary of the plant",
  "article": "A comprehensive encyclopedia article"
}

Content Requirements:

SHORT_DESCRIPTION:
* 1-2 sentences maximum
* Highlight the plant's most distinctive feature or appeal
* Written to entice visitors at a botanical conservatory
* Accessible and engaging for general audiences

ARTICLE:
A comprehensive encyclopedia-style article covering:

1.  General Description: Detailed explanation of the plant's appearance, size, structure, and identifying characteristics.
2.  Origin and History: Background on the plant's native habitat, geographical distribution, and relevant history of its discovery, naming, or cultivation.
3.  Cultivation and Care Guide: Professional guidance on growing the plant, including:
    * Light requirements
    * Soil/Substrate needs
    * Watering/Humidity
    * Temperature ranges
    * Fertilization
    * Pruning/Maintenance
4.  Additional Details/Notes: Notable information such as common pests/diseases, toxicity, uses (historical or modern), or unique horticultural facts.

Output Constraints:
* Return ONLY valid JSON - no additional text before or after
* Do not use any emojis
* Maintain a professional, formal, and authoritative tone suitable for an academic encyclopedia
* Do not restate the common name or scientific name as a heading in the article
* Do not number your sections, just use headings. 
"""


async def generate_article(
    scientific_name: str,
    common_name: Optional[str],
    semaphore: asyncio.Semaphore,
    max_retries: int = 3
) -> dict:
    """Generate an article for a single plant species using OpenAI API."""
    
    async with semaphore:
        plant_name = common_name if common_name else scientific_name
        
        user_prompt = f"""Generate structured content for {plant_name} ({scientific_name}).

Return a JSON object with:
1. "short_description": A concise 1-2 sentence summary highlighting the plant's most distinctive or appealing features
2. "article": A comprehensive encyclopedia article covering general description, origin and history, cultivation and care guide, and additional notable details

Remember to return ONLY the JSON object, no other text."""

        for attempt in range(max_retries):
            try:
                response = await client.chat.completions.create(
                    model="gpt-5-mini",
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_prompt}
                    ],
                    reasoning_effort='low',
                    response_format={"type": "json_object"}
                )
                
                content = response.choices[0].message.content.strip()
                parsed_content = json.loads(content)
                
                return {
                    "scientific_name": scientific_name,
                    "common_name": common_name,
                    "article": parsed_content.get("article", ""),
                    "short_description": parsed_content.get("short_description", ""),
                    "success": True,
                    "error": None
                }
                
            except Exception as e:
                if attempt == max_retries - 1:
                    return {
                        "scientific_name": scientific_name,
                        "common_name": common_name,
                        "article": None,
                        "success": False,
                        "error": str(e)
                    }
                await asyncio.sleep(2 ** attempt)  # Exponential backoff


async def generate_all_articles(
    plants_df: pd.DataFrame,
    max_concurrent: int = 10,
    output_file: str = "plant_articles.json"
) -> None:
    """Generate articles for all plants in the dataframe."""
    
    semaphore = asyncio.Semaphore(max_concurrent)
    
    # Create tasks for all plants
    tasks = []
    for i, row in plants_df.iterrows():
        if i < args.skip:
            continue
        if args.limit > 0 and i >= args.skip + args.limit:
            break
        scientific_name = row['Scientific Name']
        common_name = row['Common Name'] if pd.notna(row['Common Name']) else None
        
        # Skip if no valid scientific name
        if pd.isna(scientific_name) or not scientific_name.strip():
            continue
            
        tasks.append(generate_article(scientific_name, common_name, semaphore))

    print(f"Generating articles for {len(tasks)} plants...")
    print(f"Using {max_concurrent} concurrent API calls")
    
    # Execute all tasks with progress bar
    results = await tqdm_asyncio.gather(*tasks, desc="Generating articles")
    
    # Separate successful and failed results
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]
    
    print(f"\nCompleted: {len(successful)} successful, {len(failed)} failed")
    
    # Save results to JSON
    output_path = Path(__file__).parent / output_file
    output_data = {
        "metadata": {
            "total_plants": len(results),
            "successful": len(successful),
            "failed": len(failed),
            "model": "gpt-5-mini"
        },
        "articles": successful,
        "failed": failed
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\nResults saved to: {output_path}")
    
    if failed:
        print(f"\nFailed plants:")
        for item in failed[:10]:  # Show first 10 failures
            print(f"  - {item['common_name']} ({item['scientific_name']}): {item['error']}")


def main():
    """Main entry point."""
    # Load plant data
    csv_path = Path(__file__).parent.parent / "Plants_Formatted.csv"
    
    if not csv_path.exists():
        print(f"Error: Could not find {csv_path}")
        return
    
    print(f"Loading plant data from {csv_path}...")
    plants_df = pd.read_csv(csv_path, encoding='utf-8')
    
    # Remove duplicates based on scientific name
    plants_df = plants_df.drop_duplicates(subset=['Scientific Name'], keep='first')
    
    print(f"Loaded {len(plants_df)} unique plant species")
    
    # Check for API key
    if not os.getenv("OPENAI_API_KEY"):
        print("Error: OPENAI_API_KEY environment variable not set")
        return
    
    # Run async article generation
    asyncio.run(generate_all_articles(
        plants_df,
        max_concurrent=10,
        output_file="plant_articles.json"
    ))


if __name__ == "__main__":
    main()

