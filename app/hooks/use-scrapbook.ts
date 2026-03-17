import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth0 } from '@/components/Auth0Provider';
import { scrapbookService } from '@/services/scrapbook';

export const scrapbookKeys = {
  all: ['scrapbook'] as const,
  catalog: () => [...scrapbookKeys.all, 'catalog'] as const,
  stats: () => [...scrapbookKeys.all, 'stats'] as const,
  discovery: (catalogEntryId: number) => [...scrapbookKeys.all, 'discovery', catalogEntryId] as const,
};

export function useScrapbookCatalog() {
  const { accessToken } = useAuth0();
  
  return useQuery({
    queryKey: scrapbookKeys.catalog(),
    queryFn: () => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.getCatalog(accessToken);
    },
    enabled: !!accessToken,
  });
}

export function useCollectionStats() {
  const { accessToken } = useAuth0();
  
  return useQuery({
    queryKey: scrapbookKeys.stats(),
    queryFn: () => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.getCollectionStats(accessToken);
    },
    enabled: !!accessToken,
  });
}

export function useDiscoveryDetails(catalogEntryId: number | null) {
  const { accessToken } = useAuth0();
  
  return useQuery({
    queryKey: scrapbookKeys.discovery(catalogEntryId!),
    queryFn: () => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.getDiscoveryDetails(accessToken, catalogEntryId!);
    },
    enabled: catalogEntryId !== null && !!accessToken,
  });
}

export function useScanQRCode() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: (qrToken: string) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.scanQRCode(accessToken, qrToken);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: scrapbookKeys.catalog() });
      queryClient.invalidateQueries({ queryKey: scrapbookKeys.stats() });
    },
  });
}

export function useUpdateNotes() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: ({ discoveryId, notes }: { discoveryId: number; notes: string }) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.updateNotes(accessToken, discoveryId, notes);
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: scrapbookKeys.catalog() });
    },
  });
}

export function useToggleFavorite() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();
  
  return useMutation({
    mutationFn: (discoveryId: number) => {
      if (!accessToken) {
        throw new Error('No access token available');
      }
      return scrapbookService.toggleFavorite(accessToken, discoveryId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: scrapbookKeys.catalog() });
      queryClient.invalidateQueries({ queryKey: scrapbookKeys.stats() });
    },
  });
}

