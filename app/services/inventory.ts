import { API_BASE_URL } from '@/constants/config';

export interface PlantSpecies {
  id: number;
  scientific_name: string;
  common_name: string | null;
  description?: string | null;
}

export interface PlantSpeciesCreate {
  scientific_name: string;
  common_name?: string | null;
}

export interface StorageLocation {
  id: number;
  name: string;
  location_type: string;
  description?: string | null;
  capacity?: number | null;
  created_at: string;
}

export interface StorageLocationCreate {
  name: string;
  location_type: string;
  description?: string | null;
  capacity?: number | null;
}

export interface PlantInstance {
  id: number;
  plant_species_id: number;
  storage_location_id: number | null;
  identifier: string | null;
  quantity: number;
  status: string;
  is_public: boolean;
  acquired_date?: string | null;
  notes?: string | null;
  created_at: string;
}

export interface PlantInstanceCreate {
  plant_species_id: number;
  storage_location_id?: number | null;
  identifier?: string | null;
  quantity?: number;
  status?: string;
  is_public?: boolean;
  acquired_date?: string | null;
  notes?: string | null;
}

export interface PlantInstanceUpdate {
  plant_species_id?: number;
  storage_location_id?: number | null;
  identifier?: string | null;
  quantity?: number;
  status?: string;
  is_public?: boolean;
  acquired_date?: string | null;
  notes?: string | null;
}

export interface PlantInstanceWithDetails extends PlantInstance {
  scientific_name: string;
  common_name: string | null;
  species_description?: string | null;
  location_name: string | null;
  location_type: string | null;
  location_description?: string | null;
  is_public: boolean;
}

export interface GetPlantInstancesParams {
  storage_location_id?: number;
  status?: string;
  plant_species_id?: number;
}

export interface GetPlantSpeciesParams {
  search?: string;
}

export interface GetStorageLocationsParams {
  location_type?: string;
}

export const inventoryService = {
  // Plant Species
  async getPlantSpecies(params?: GetPlantSpeciesParams): Promise<PlantSpecies[]> {
    const queryParams = new URLSearchParams();
    if (params?.search) queryParams.append('search', params.search);

    const url = `${API_BASE_URL}/inventory/plant-species${queryParams.toString() ? '?' + queryParams.toString() : ''}`;
    const response = await fetch(url);

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to fetch plant species: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async createPlantSpecies(data: PlantSpeciesCreate): Promise<PlantSpecies> {
    const response = await fetch(`${API_BASE_URL}/inventory/plant-species`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to create plant species: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  // Storage Locations
  async getStorageLocations(params?: GetStorageLocationsParams): Promise<StorageLocation[]> {
    const queryParams = new URLSearchParams();
    if (params?.location_type) queryParams.append('location_type', params.location_type);

    const url = `${API_BASE_URL}/inventory/storage-locations${queryParams.toString() ? '?' + queryParams.toString() : ''}`;
    const response = await fetch(url);

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to fetch storage locations: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  async createStorageLocation(data: StorageLocationCreate): Promise<StorageLocation> {
    const response = await fetch(`${API_BASE_URL}/inventory/storage-locations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to create storage location: ${response.status} - ${errorText}`);
    }

    return response.json();
  },

  // Plant Instances
  async getPlantInstances(params?: GetPlantInstancesParams): Promise<PlantInstanceWithDetails[]> {
    const queryParams = new URLSearchParams();
    if (params?.storage_location_id) queryParams.append('storage_location_id', params.storage_location_id.toString());
    if (params?.status) queryParams.append('status', params.status);
    if (params?.plant_species_id) queryParams.append('species_id', params.plant_species_id.toString());

    const url = `${API_BASE_URL}/inventory/plant-instances${queryParams.toString() ? '?' + queryParams.toString() : ''}`;
    const response = await fetch(url);

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to fetch plant instances: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    
    return data.map((instance: any) => ({
      ...instance,
      plant_species_id: instance.species_id,
    }));
  },

  async createPlantInstance(data: PlantInstanceCreate): Promise<PlantInstance> {
    const payload = {
      species_id: data.plant_species_id,
      storage_location_id: data.storage_location_id,
      identifier: data.identifier,
      quantity: data.quantity,
      status: data.status,
      is_public: data.is_public,
      acquired_date: data.acquired_date,
      notes: data.notes,
    };

    const response = await fetch(`${API_BASE_URL}/inventory/plant-instances`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to create plant instance: ${response.status} - ${errorText}`);
    }

    const instance = await response.json();
    return {
      ...instance,
      plant_species_id: instance.species_id,
    };
  },

  async updatePlantInstance(instanceId: number, data: PlantInstanceUpdate): Promise<PlantInstance> {
    const payload: any = {};
    if (data.plant_species_id !== undefined) payload.species_id = data.plant_species_id;
    if (data.storage_location_id !== undefined) payload.storage_location_id = data.storage_location_id;
    if (data.identifier !== undefined) payload.identifier = data.identifier;
    if (data.quantity !== undefined) payload.quantity = data.quantity;
    if (data.status !== undefined) payload.status = data.status;
    if (data.is_public !== undefined) payload.is_public = data.is_public;
    if (data.acquired_date !== undefined) payload.acquired_date = data.acquired_date;
    if (data.notes !== undefined) payload.notes = data.notes;

    const response = await fetch(`${API_BASE_URL}/inventory/plant-instances/${instanceId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Failed to update plant instance: ${response.status} - ${errorText}`);
    }

    const instance = await response.json();
    return {
      ...instance,
      plant_species_id: instance.species_id,
    };
  },
};

