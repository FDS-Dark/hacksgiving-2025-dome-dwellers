import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, ScrollView, Image } from 'react-native';
import { Palette } from '@/constants/theme';
import { useAuth0 } from '@/components/Auth0Provider';
import { useTranslation } from '@/hooks/useTranslation';

export default function UserScreen() {
  const { t } = useTranslation();
  const { isAuthenticated, isLoading, user, login, logout, error } = useAuth0();

  const handleLogin = async () => {
    try {
      await login();
    } catch (err) {
      console.error('Login failed:', err);
    }
  };

  const handleLogout = async () => {
    try {
      await logout();
    } catch (err) {
      console.error('Logout failed:', err);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.content}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>{t('user.loading')}</Text>
        </View>
      </View>
    );
  }

  if (!isAuthenticated) {
    return (
      <View style={styles.container}>
        <View style={styles.content}>
          <Text style={styles.title}>{t('user.welcome')}</Text>
          <Text style={styles.subtitle}>{t('user.subtitle')}</Text>
          
          {error && (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{t('user.error', { message: error.message })}</Text>
            </View>
          )}
          
          <TouchableOpacity style={styles.loginButton} onPress={handleLogin}>
            <Text style={styles.loginButtonText}>{t('user.signInWithAuth0')}</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.contentPadded}>
        <View style={styles.profileHeader}>
          {user?.picture && (
            <Image 
              source={{ uri: user.picture }} 
              style={styles.profileImage}
            />
          )}
          <Text style={styles.name}>{user?.name || 'User'}</Text>
          <Text style={styles.email}>{user?.email || ''}</Text>
        </View>

        <View style={styles.infoSection}>
          <Text style={styles.sectionTitle}>{t('user.profileInformation')}</Text>
          
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>{t('user.userId')}</Text>
            <Text style={styles.infoValue} numberOfLines={1}>{user?.sub || 'N/A'}</Text>
          </View>
          
          {user?.nickname && (
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>{t('user.nickname')}</Text>
              <Text style={styles.infoValue}>{user.nickname}</Text>
            </View>
          )}
          
          {user?.updated_at && (
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>{t('user.lastUpdated')}</Text>
              <Text style={styles.infoValue}>
                {new Date(user.updated_at).toLocaleDateString()}
              </Text>
            </View>
          )}
        </View>

        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>{t('user.signOut')}</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.white,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  contentPadded: {
    flex: 1,
    padding: 20,
  },
  title: {
    color: Palette.green900,
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
  },
  subtitle: {
    color: Palette.green900,
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 32,
    opacity: 0.7,
  },
  loadingText: {
    color: Palette.green900,
    fontSize: 16,
    marginTop: 16,
  },
  loginButton: {
    backgroundColor: Palette.green900,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  loginButtonText: {
    color: Palette.white,
    fontSize: 18,
    fontWeight: '600',
  },
  errorContainer: {
    backgroundColor: '#fee',
    padding: 12,
    borderRadius: 8,
    marginVertical: 16,
    width: '100%',
  },
  errorText: {
    color: '#c00',
    textAlign: 'center',
  },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: 24,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
    marginBottom: 24,
  },
  profileImage: {
    width: 100,
    height: 100,
    borderRadius: 50,
    marginBottom: 16,
  },
  name: {
    color: Palette.green900,
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  email: {
    color: Palette.green900,
    fontSize: 16,
    opacity: 0.7,
  },
  infoSection: {
    marginBottom: 32,
  },
  sectionTitle: {
    color: Palette.green900,
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 16,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  infoLabel: {
    color: Palette.green900,
    fontSize: 16,
    fontWeight: '500',
  },
  infoValue: {
    color: Palette.green900,
    fontSize: 16,
    opacity: 0.7,
    flex: 1,
    textAlign: 'right',
    marginLeft: 16,
  },
  logoutButton: {
    backgroundColor: '#fff',
    borderWidth: 2,
    borderColor: Palette.green900,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  logoutButtonText: {
    color: Palette.green900,
    fontSize: 18,
    fontWeight: '600',
  },
});
