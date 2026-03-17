import json
import pandas as pd
from pathlib import Path


def generate_csv_exports(
    csv_path: str = "../Plants_Formatted.csv",
    articles_file: str = "plant_articles.json",
    output_species: str = "plants_species.csv",
    output_articles: str = "plants_articles.csv"
) -> None:
    """Generate CSV files for plant species and articles."""
    
    print("Generating CSV exports for plant encyclopedia...")
    print("=" * 60)
    
    # Load plant data
    csv_full_path = Path(__file__).parent / csv_path
    if not csv_full_path.exists():
        print(f"Error: Could not find {csv_full_path}")
        return
    
    print(f"\nLoading plant data from {csv_full_path}...")
    plants_df = pd.read_csv(csv_full_path, encoding='utf-8')
    
    # Remove duplicates
    original_count = len(plants_df)
    plants_df = plants_df.drop_duplicates(subset=['Scientific Name'], keep='first')
    deduped_count = len(plants_df)
    
    print(f"Loaded {original_count} rows, {deduped_count} unique species")
    
    # Prepare species data
    print("\nPreparing species data...")
    species_data = []
    skipped = 0
    
    for _, row in plants_df.iterrows():
        scientific_name = row['Scientific Name']
        common_name = row['Common Name'] if pd.notna(row['Common Name']) else None
        
        if pd.isna(scientific_name) or not scientific_name.strip():
            skipped += 1
            continue
        
        notes = row.get('Notes', '')
        description = None
        if pd.notna(notes) and notes.strip():
            description = f"Plant from Mitchell Park Domes collection. {notes.strip()}"
        
        species_data.append({
            'scientific_name': scientific_name,
            'common_name': common_name if common_name else '',
            'description': description if description else '',
            'image_url': ''
        })
    
    # Save species CSV
    species_df = pd.DataFrame(species_data)
    species_path = Path(__file__).parent / output_species
    species_df.to_csv(species_path, index=False, encoding='utf-8')
    
    print(f"✓ Species CSV saved to: {species_path}")
    print(f"  - {len(species_df)} species")
    print(f"  - {skipped} rows skipped (no scientific name)")
    
    # Load and prepare articles data
    articles_path = Path(__file__).parent / articles_file
    if articles_path.exists():
        print(f"\nLoading articles from {articles_path}...")
        with open(articles_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        articles_data = []
        failed_count = 0
        
        for article in data.get("articles", []):
            if not article.get("success"):
                failed_count += 1
                continue
            
            scientific_name = article.get("scientific_name")
            article_content = article.get("article")
            
            if not scientific_name or not article_content:
                failed_count += 1
                continue
            
            articles_data.append({
                'scientific_name': scientific_name,
                'article_content': article_content,
                'published': True
            })
        
        # Save articles CSV
        articles_df = pd.DataFrame(articles_data)
        articles_path_out = Path(__file__).parent / output_articles
        articles_df.to_csv(articles_path_out, index=False, encoding='utf-8')
        
        print(f"✓ Articles CSV saved to: {articles_path_out}")
        print(f"  - {len(articles_df)} articles")
        print(f"  - {failed_count} failed/skipped")
        
        # Print summary
        print("\n" + "=" * 60)
        print("Summary:")
        print(f"  Species file: {output_species} ({len(species_df)} rows)")
        print(f"  Articles file: {output_articles} ({len(articles_df)} rows)")
        print(f"\nCoverage: {len(articles_df)}/{len(species_df)} species have articles ({len(articles_df)/len(species_df)*100:.1f}%)")
    else:
        print(f"\nWarning: {articles_file} not found, skipping articles")
        print("\n" + "=" * 60)
        print("Summary:")
        print(f"  Species file: {output_species} ({len(species_df)} rows)")


def main():
    """Main entry point."""
    print("Plant Encyclopedia CSV Generator")
    
    generate_csv_exports()
    
    print("\n✓ Done!")
    print("\nNext steps:")
    print("  1. Review the CSV files")
    print("  2. Run: python upsert_plants_to_db.py")
    print("     - This will upsert the data to your database")


if __name__ == "__main__":
    main()

