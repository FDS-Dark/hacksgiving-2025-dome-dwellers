export interface CollectibleCatalogEntry {
  catalog_id: number;
  catalog_number: number;
  plant_species_id: number;
  species_name: string;
  scientific_name: string;
  image_url?: string;
  rarity_tier: 'common' | 'uncommon' | 'rare' | 'legendary';
  featured_order?: number;
  is_discovered: boolean;
  discovered_at?: string;
  discovery_id?: number;
  user_notes?: string;
  is_favorite: boolean;
}

export interface DiscoveryDetails {
  discovery_id: number;
  catalog_number: number;
  plant_species_id: number;
  species_name: string;
  scientific_name: string;
  family?: string;
  rarity_tier: 'common' | 'uncommon' | 'rare' | 'legendary';
  discovered_at: string;
  user_notes?: string;
  is_favorite: boolean;
  plant_article: {
    description?: string;
    care_notes?: string;
    native_habitat?: string;
    conservation_status?: string;
  };
}

export interface DiscoveryResponse {
  success: boolean;
  message: string;
  discovery_id?: number;
  catalog_entry_id?: number;
  catalog_number?: number;
  species_name?: string;
  plant_species_id?: number;
  already_discovered: boolean;
}

export interface CollectionStats {
  total_collectibles: number;
  total_discovered: number;
  discovery_percentage: number;
  common_discovered: number;
  uncommon_discovered: number;
  rare_discovered: number;
  legendary_discovered: number;
  favorites_count: number;
  recent_discoveries: number[];
}

export interface QRCodeInfo {
  id: number;
  code_token: string;
  species_id: number;
  active: boolean;
  common_name?: string;
  scientific_name?: string;
  created_at?: string;
}

