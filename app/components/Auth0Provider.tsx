import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import * as AuthSession from 'expo-auth-session';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';
import { auth0Config } from '@/config/auth0.config';

// Auth0 discovery document
const discovery = {
  authorizationEndpoint: `https://${auth0Config.domain}/authorize`,
  tokenEndpoint: `https://${auth0Config.domain}/oauth/token`,
  revocationEndpoint: `https://${auth0Config.domain}/oauth/revoke`,
};

// Auth0 Context Type
interface Auth0ContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: any | null;
  accessToken: string | null;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  error: Error | null;
}

// Create Context
const Auth0Context = createContext<Auth0ContextType | undefined>(undefined);

// Secure Store Keys
const ACCESS_TOKEN_KEY = 'auth0_access_token';
const ID_TOKEN_KEY = 'auth0_id_token';
const REFRESH_TOKEN_KEY = 'auth0_refresh_token';
const USER_KEY = 'auth0_user';
const TOKEN_EXPIRY_KEY = 'auth0_token_expiry';

// Cross-platform storage wrapper
const storage = {
  async getItem(key: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      return localStorage.getItem(key);
    }
    return await SecureStore.getItemAsync(key);
  },

  async setItem(key: string, value: string): Promise<void> {
    if (Platform.OS === 'web') {
      localStorage.setItem(key, value);
    } else {
      await SecureStore.setItemAsync(key, value);
    }
  },

  async deleteItem(key: string): Promise<void> {
    if (Platform.OS === 'web') {
      localStorage.removeItem(key);
    } else {
      await SecureStore.deleteItemAsync(key);
    }
  },
};

interface Auth0ProviderProps {
  children: ReactNode;
}

// Generate platform-specific redirect URI
const redirectUri = AuthSession.makeRedirectUri({
  scheme: 'app',
  path: 'auth',
  preferLocalhost: true,
  // Use native scheme for native platforms, https for web
  native: auth0Config.tailscaleIP
    ? `app://${auth0Config.tailscaleIP}:8081/auth`
    : undefined
});

export function Auth0Provider({ children }: Auth0ProviderProps) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<any | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [error, setError] = useState<Error | null>(null);

  // Auth request configuration
  const [request, result, promptAsync] = AuthSession.useAuthRequest(
    {
      clientId: auth0Config.clientId,
      scopes: ['openid', 'profile', 'email', 'offline_access'],
      redirectUri,
      extraParams: {
        audience: auth0Config.audience,
      },
    },
    discovery
  );

  // Load stored credentials on mount
  useEffect(() => {
    loadStoredCredentials();
  }, []);

  // Handle auth response
  useEffect(() => {
    if (result?.type === 'success') {
      handleAuthResponse(result.params.code);
    } else if (result?.type === 'error') {
      setError(new Error(result.error?.message || 'Authentication failed'));
      setIsLoading(false);
    }
  }, [result]);

  const loadStoredCredentials = async () => {
    try {
      const token = await storage.getItem(ACCESS_TOKEN_KEY);
      const storedUser = await storage.getItem(USER_KEY);
      const expiryStr = await storage.getItem(TOKEN_EXPIRY_KEY);

      if (token && storedUser && expiryStr) {
        const expiry = parseInt(expiryStr, 10);
        const userData = JSON.parse(storedUser);

        // Check if token is expired
        if (Date.now() < expiry) {
          setAccessToken(token);
          setUser(userData);
          setIsAuthenticated(true);
        } else {
          // Token expired, try to refresh
          await refreshToken();
        }
      }
    } catch (err) {
      console.error('Error loading stored credentials:', err);
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  };

  const refreshToken = async () => {
    try {
      const refreshTokenValue = await storage.getItem(REFRESH_TOKEN_KEY);
      if (refreshTokenValue) {
        const tokenResponse = await fetch(`https://${auth0Config.domain}/oauth/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            grant_type: 'refresh_token',
            client_id: auth0Config.clientId,
            refresh_token: refreshTokenValue,
          }),
        });

        if (!tokenResponse.ok) {
          throw new Error('Failed to refresh token');
        }

        const tokens = await tokenResponse.json();
        await storeTokens(tokens);
        await fetchUserInfo(tokens.access_token);
      } else {
        await clearSession();
      }
    } catch (err) {
      console.error('Error refreshing token:', err);
      await clearSession();
    }
  };

  const handleAuthResponse = async (code: string) => {
    try {
      setIsLoading(true);

      // Generate code verifier for PKCE
      const codeVerifier = request?.codeVerifier || '';

      // Exchange code for tokens
      const tokenResponse = await fetch(`https://${auth0Config.domain}/oauth/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          grant_type: 'authorization_code',
          client_id: auth0Config.clientId,
          code,
          redirect_uri: redirectUri,
          code_verifier: codeVerifier,
        }),
      });

      if (!tokenResponse.ok) {
        throw new Error('Failed to exchange code for tokens');
      }

      const tokens = await tokenResponse.json();
      await storeTokens(tokens);
      await fetchUserInfo(tokens.access_token);
    } catch (err) {
      console.error('Auth response error:', err);
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  };

  const storeTokens = async (tokens: any) => {
    await storage.setItem(ACCESS_TOKEN_KEY, tokens.access_token);
    if (tokens.id_token) {
      await storage.setItem(ID_TOKEN_KEY, tokens.id_token);
    }
    if (tokens.refresh_token) {
      await storage.setItem(REFRESH_TOKEN_KEY, tokens.refresh_token);
    }

    // Store expiry time (current time + expires_in seconds)
    const expiryTime = Date.now() + (tokens.expires_in * 1000);
    await storage.setItem(TOKEN_EXPIRY_KEY, expiryTime.toString());

    setAccessToken(tokens.access_token);
  };

  const fetchUserInfo = async (token: string) => {
    try {
      const userResponse = await fetch(`https://${auth0Config.domain}/userinfo`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!userResponse.ok) {
        throw new Error('Failed to fetch user info');
      }

      const userData = await userResponse.json();
      await storage.setItem(USER_KEY, JSON.stringify(userData));
      setUser(userData);
      setIsAuthenticated(true);
    } catch (err) {
      console.error('Error fetching user info:', err);
      throw err;
    }
  };

  const login = async () => {
    try {
      setError(null);
      if (!request) {
        throw new Error('Auth request not ready');
      }
      // Platform-specific prompt options
      const promptOptions = Platform.OS === 'web'
        ? { windowFeatures: { width: 500, height: 600 } }
        : { useProxy: false, showInRecents: true };

      await promptAsync(promptOptions);
    } catch (err) {
      console.error('Login error:', err);
      setError(err as Error);
      throw err;
    }
  };

  const logout = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Clear local session immediately
      await clearSession();
    } catch (err) {
      console.error('Logout error:', err);
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  };

  const clearSession = async () => {
    await storage.deleteItem(ACCESS_TOKEN_KEY);
    await storage.deleteItem(ID_TOKEN_KEY);
    await storage.deleteItem(REFRESH_TOKEN_KEY);
    await storage.deleteItem(USER_KEY);
    await storage.deleteItem(TOKEN_EXPIRY_KEY);
    setAccessToken(null);
    setUser(null);
    setIsAuthenticated(false);
  };

  const value: Auth0ContextType = {
    isAuthenticated,
    isLoading,
    user,
    accessToken,
    login,
    logout,
    error,
  };

  return <Auth0Context.Provider value={value}>{children}</Auth0Context.Provider>;
}

// Custom hook to use Auth0 context
export function useAuth0() {
  const context = useContext(Auth0Context);
  if (context === undefined) {
    throw new Error('useAuth0 must be used within an Auth0Provider');
  }
  return context;
}

// Export configuration for reference
export { auth0Config, redirectUri };
