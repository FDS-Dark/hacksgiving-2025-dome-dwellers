export type PlantSortOrder = 'common_name' | 'scientific_name';

export interface PlantSpeciesListItem {
  id: number;
  scientific_name: string;
  common_name: string | null;
  description: string | null;
  image_url: string | null;
  has_article: boolean;
}

export interface PlantSpeciesListResponse {
  plants: PlantSpeciesListItem[];
  total: number;
}

export interface PlantEncyclopediaEntry {
  id: number;
  scientific_name: string;
  common_name: string | null;
  description: string | null;
  care_notes: string | null;
  image_url: string | null;
  article_id: number | null;
  article_content: string | null;
  article_author_id: number | null;
  article_created_at: string | null;
  article_updated_at: string | null;
  species_created_at: string;
}

