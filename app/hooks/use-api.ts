import { useAuth0 } from '@/components/Auth0Provider';
import { useState, useCallback } from 'react';

/**
 * Custom hook for making authenticated API calls
 * Automatically includes the Auth0 access token in the Authorization header
 */
export function useApi() {
  const { accessToken, isAuthenticated } = useAuth0();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const makeRequest = useCallback(
    async <T,>(url: string, options: RequestInit = {}): Promise<T> => {
      if (!isAuthenticated || !accessToken) {
        throw new Error('User is not authenticated');
      }

      setLoading(true);
      setError(null);

      try {
        const headers = {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
          ...options.headers,
        };

        const response = await fetch(url, {
          ...options,
          headers,
        });

        if (!response.ok) {
          throw new Error(`API request failed: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        return data as T;
      } catch (err) {
        const error = err as Error;
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [accessToken, isAuthenticated]
  );

  const get = useCallback(
    async <T,>(url: string): Promise<T> => {
      return makeRequest<T>(url, { method: 'GET' });
    },
    [makeRequest]
  );

  const post = useCallback(
    async <T,>(url: string, data: any): Promise<T> => {
      return makeRequest<T>(url, {
        method: 'POST',
        body: JSON.stringify(data),
      });
    },
    [makeRequest]
  );

  const put = useCallback(
    async <T,>(url: string, data: any): Promise<T> => {
      return makeRequest<T>(url, {
        method: 'PUT',
        body: JSON.stringify(data),
      });
    },
    [makeRequest]
  );

  const del = useCallback(
    async <T,>(url: string): Promise<T> => {
      return makeRequest<T>(url, { method: 'DELETE' });
    },
    [makeRequest]
  );

  return {
    loading,
    error,
    get,
    post,
    put,
    delete: del,
    makeRequest,
  };
}

