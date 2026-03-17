import { useQuery } from '@tanstack/react-query';
import { plantsService, GetPlantsParams } from '@/services/plants';

// Query Keys
export const plantsKeys = {
  all: ['plants'] as const,
  encyclopedia: () => [...plantsKeys.all, 'encyclopedia'] as const,
  encyclopediaList: (params?: GetPlantsParams) => [...plantsKeys.encyclopedia(), 'list', params] as const,
  encyclopediaEntry: (speciesId: number) => [...plantsKeys.encyclopedia(), 'entry', speciesId] as const,
};

// Encyclopedia Hooks
export function usePlants(params?: GetPlantsParams) {
  return useQuery({
    queryKey: plantsKeys.encyclopediaList(params),
    queryFn: () => plantsService.getEncyclopediaList(params),
  });
}

export function usePlantDetails(speciesId: number | null) {
  return useQuery({
    queryKey: plantsKeys.encyclopediaEntry(speciesId!),
    queryFn: () => plantsService.getEncyclopediaEntry(speciesId!),
    enabled: speciesId !== null,
  });
}

// Re-export inventory hooks for convenience
export {
  usePlantSpecies,
  useCreatePlantSpecies,
  useStorageLocations,
  useCreateStorageLocation,
  usePlantInstances,
  useCreatePlantInstance,
  useUpdatePlantInstance,
  inventoryKeys,
} from './use-inventory';

