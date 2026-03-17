import { API_BASE_URL } from '@/constants/config';
import { PlantSpeciesListResponse, PlantEncyclopediaEntry, PlantSortOrder } from '@/types/plants';

export interface GetPlantsParams {
  search?: string;
  order_by?: PlantSortOrder;
  limit?: number;
  offset?: number;
}

export const plantsService = {
  async getEncyclopediaList(params?: GetPlantsParams): Promise<PlantSpeciesListResponse> {
    const queryParams = new URLSearchParams();
    
    if (params?.search) queryParams.append('search', params.search);
    if (params?.order_by) queryParams.append('order_by', params.order_by);
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.offset) queryParams.append('offset', params.offset.toString());

    const url = `${API_BASE_URL}/plants/encyclopedia${queryParams.toString() ? '?' + queryParams.toString() : ''}`;
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch plants: ${response.statusText}`);
    }
    
    return response.json();
  },

  async getEncyclopediaEntry(speciesId: number): Promise<PlantEncyclopediaEntry> {
    const url = `${API_BASE_URL}/plants/encyclopedia/${speciesId}`;
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch plant: ${response.statusText}`);
    }
    
    return response.json();
  },
};

