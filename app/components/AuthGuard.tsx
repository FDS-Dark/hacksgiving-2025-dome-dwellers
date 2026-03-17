import React, { ReactNode } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { useAuth0 } from './Auth0Provider';
import { Palette } from '@/constants/theme';

interface AuthGuardProps {
  children: ReactNode;
  fallback?: ReactNode;
  requireAuth?: boolean;
}

/**
 * AuthGuard component to protect routes that require authentication
 * 
 * @param children - Content to display when authenticated
 * @param fallback - Optional custom fallback UI for unauthenticated users
 * @param requireAuth - If true, shows login prompt. If false, shows children regardless
 * 
 * @example
 * ```tsx
 * <AuthGuard>
 *   <ProtectedContent />
 * </AuthGuard>
 * ```
 */
export function AuthGuard({ children, fallback, requireAuth = true }: AuthGuardProps) {
  const { isAuthenticated, isLoading, login } = useAuth0();

  if (isLoading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color={Palette.green900} />
        <Text style={styles.loadingText}>Loading...</Text>
      </View>
    );
  }

  if (!requireAuth || isAuthenticated) {
    return <>{children}</>;
  }

  if (fallback) {
    return <>{fallback}</>;
  }

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>Authentication Required</Text>
        <Text style={styles.subtitle}>
          Please sign in to access this content
        </Text>
        <TouchableOpacity style={styles.loginButton} onPress={login}>
          <Text style={styles.loginButtonText}>Sign In</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    padding: 24,
    alignItems: 'center',
  },
  title: {
    color: Palette.green900,
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
  },
  subtitle: {
    color: Palette.green900,
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 24,
    opacity: 0.7,
  },
  loadingText: {
    color: Palette.green900,
    fontSize: 16,
    marginTop: 16,
  },
  loginButton: {
    backgroundColor: Palette.green900,
    paddingVertical: 14,
    paddingHorizontal: 28,
    borderRadius: 8,
    marginTop: 8,
  },
  loginButtonText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
});

