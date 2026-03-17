import { useState, useEffect } from 'react';
import { useAuth0 } from '@/components/Auth0Provider';
import { userService } from '@/services/user';
import { UserProfile } from '@/types/user';

export interface UseUserResult {
  user: UserProfile | null;
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export function useUser(): UseUserResult {
  const { user: auth0User, accessToken, isAuthenticated } = useAuth0();
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchUser = async () => {
    if (!isAuthenticated || !accessToken) {
      setUser(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const userProfile = await userService.getCurrentUser(accessToken);
      setUser(userProfile);
    } catch (err) {
      console.error('Error fetching user profile:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch user profile'));
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUser();
  }, [isAuthenticated, accessToken]);

  return {
    user,
    loading,
    error,
    refetch: fetchUser,
  };
}

