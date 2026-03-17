import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  inventoryService,
  PlantSpeciesCreate,
  PlantInstanceCreate,
  PlantInstanceUpdate,
  StorageLocationCreate,
  GetPlantInstancesParams,
  GetPlantSpeciesParams,
  GetStorageLocationsParams,
} from '@/services/inventory';

// Query Keys
export const inventoryKeys = {
  all: ['inventory'] as const,
  plantSpecies: () => [...inventoryKeys.all, 'plant-species'] as const,
  plantSpeciesList: (params?: GetPlantSpeciesParams) => [...inventoryKeys.plantSpecies(), 'list', params] as const,
  storageLocations: () => [...inventoryKeys.all, 'storage-locations'] as const,
  storageLocationsList: (params?: GetStorageLocationsParams) => [...inventoryKeys.storageLocations(), 'list', params] as const,
  plantInstances: () => [...inventoryKeys.all, 'plant-instances'] as const,
  plantInstancesList: (params?: GetPlantInstancesParams) => [...inventoryKeys.plantInstances(), 'list', params] as const,
};

// Plant Species Hooks
export function usePlantSpecies(params?: GetPlantSpeciesParams) {
  return useQuery({
    queryKey: inventoryKeys.plantSpeciesList(params),
    queryFn: () => inventoryService.getPlantSpecies(params),
  });
}

export function useCreatePlantSpecies() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: PlantSpeciesCreate) => inventoryService.createPlantSpecies(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: inventoryKeys.plantSpecies() });
    },
  });
}

// Storage Locations Hooks
export function useStorageLocations(params?: GetStorageLocationsParams) {
  return useQuery({
    queryKey: inventoryKeys.storageLocationsList(params),
    queryFn: () => inventoryService.getStorageLocations(params),
    staleTime: 5 * 60 * 1000, // 5 minutes - locations don't change often
  });
}

export function useCreateStorageLocation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: StorageLocationCreate) => inventoryService.createStorageLocation(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: inventoryKeys.storageLocations() });
    },
  });
}

// Plant Instances Hooks
export function usePlantInstances(params?: GetPlantInstancesParams) {
  return useQuery({
    queryKey: inventoryKeys.plantInstancesList(params),
    queryFn: () => inventoryService.getPlantInstances(params),
  });
}

export function useCreatePlantInstance() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: PlantInstanceCreate) => inventoryService.createPlantInstance(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: inventoryKeys.plantInstances() });
    },
  });
}

export function useUpdatePlantInstance() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ instanceId, data }: { instanceId: number; data: PlantInstanceUpdate }) =>
      inventoryService.updatePlantInstance(instanceId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: inventoryKeys.plantInstances() });
    },
  });
}

