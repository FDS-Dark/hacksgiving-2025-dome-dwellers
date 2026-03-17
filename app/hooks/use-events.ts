import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { domeService } from '@/services/dome';
import { useAuth0 } from '@/components/Auth0Provider';
import { Event, EventRegistrationCreate } from '@/types/dome';

/**
 * Hook to fetch all events (no auth required)
 */
export function useEvents(filters?: {
  event_type?: string;
  start_date?: string;
  end_date?: string;
  location?: string;
  registration_required?: boolean;
  limit?: number;
  offset?: number;
}) {
  return useQuery({
    queryKey: ['events', filters],
    queryFn: () => domeService.getEvents(filters),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

/**
 * Hook to fetch upcoming events (no auth required)
 */
export function useUpcomingEvents(limit: number = 10) {
  return useQuery({
    queryKey: ['events', 'upcoming', limit],
    queryFn: () => domeService.getUpcomingEvents(limit),
    staleTime: 5 * 60 * 1000,
  });
}

/**
 * Hook to fetch event details (no auth required)
 */
export function useEventDetails(eventId: number) {
  return useQuery({
    queryKey: ['events', eventId, 'details'],
    queryFn: () => domeService.getEventDetails(eventId),
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}

/**
 * Hook to register for an event
 * Automatically includes auth token if user is logged in
 */
export function useRegisterForEvent() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();

  return useMutation({
    mutationFn: async ({
      eventId,
      registrationData,
    }: {
      eventId: number;
      registrationData: Omit<EventRegistrationCreate, 'event_id'>;
    }) => {
      return domeService.registerForEvent(eventId, registrationData, accessToken || undefined);
    },
    onSuccess: (data, variables) => {
      // Invalidate events query to refresh registration counts
      queryClient.invalidateQueries({ queryKey: ['events'] });
      queryClient.invalidateQueries({ queryKey: ['events', variables.eventId, 'details'] });
      // Invalidate user registrations if authenticated
      if (accessToken) {
        queryClient.invalidateQueries({ queryKey: ['registrations', 'my'] });
      }
    },
  });
}

/**
 * Hook to fetch user's registrations (requires auth)
 */
export function useMyRegistrations() {
  const { accessToken, isAuthenticated } = useAuth0();

  return useQuery({
    queryKey: ['registrations', 'my'],
    queryFn: () => {
      if (!accessToken) {
        throw new Error('Not authenticated');
      }
      return domeService.getMyRegistrations(accessToken);
    },
    enabled: isAuthenticated && !!accessToken,
    staleTime: 2 * 60 * 1000,
  });
}

/**
 * Hook to cancel a registration (requires auth)
 */
export function useCancelRegistration() {
  const queryClient = useQueryClient();
  const { accessToken } = useAuth0();

  return useMutation({
    mutationFn: async (registrationId: number) => {
      if (!accessToken) {
        throw new Error('Not authenticated');
      }
      return domeService.cancelRegistration(registrationId, accessToken);
    },
    onSuccess: () => {
      // Invalidate both registrations and events queries
      queryClient.invalidateQueries({ queryKey: ['registrations'] });
      queryClient.invalidateQueries({ queryKey: ['events'] });
    },
  });
}

