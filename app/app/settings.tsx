import React, { useState, useMemo } from 'react';
import { View, Text, StyleSheet, Switch, TouchableOpacity, ScrollView, ActivityIndicator, Alert } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';
import { LanguageSwitcher } from '@/components/LanguageSwitcher';
import { useAuth0 } from '@/components/Auth0Provider';
import { FeedbackForm } from '@/components/FeedbackForm';

export default function SettingsModal() {
  const router = useRouter();
  const { t, locale } = useTranslation();
  const { isAuthenticated, isLoading, user, login, logout } = useAuth0();
  const [isLargeText, setIsLargeText] = useState(false);
  const [isTTS, setIsTTS] = useState(false);
  const [feedbackFormVisible, setFeedbackFormVisible] = useState(false);

  const handleLogin = async () => {
    try {
      await login();
      Alert.alert(t('common.success'), t('settings.account.loginSuccess'));
    } catch (err) {
      console.error('Login failed:', err);
      Alert.alert(t('settings.account.loginFailedTitle'), t('settings.account.loginFailed'));
    }
  };

  const handleLogout = async () => {
    Alert.alert(
      t('settings.account.confirmLogout'),
      t('settings.account.confirmLogoutMessage'),
      [
        {
          text: t('common.cancel'),
          style: 'cancel',
        },
        {
          text: t('common.signOut'),
          style: 'destructive',
          onPress: async () => {
            try {
              await logout();
              Alert.alert(t('common.success'), t('settings.account.logoutSuccess'));
            } catch (err) {
              console.error('Logout failed:', err);
              Alert.alert(t('settings.account.logoutFailedTitle'), t('settings.account.logoutFailed'));
            }
          },
        },
      ]
    );
  };

  // Memoize screen options to ensure they update when language changes
  const screenTitle = t('settings.title');
  const screenOptions = useMemo(() => ({
    presentation: 'modal' as const,
    headerShown: true,
    title: screenTitle,
    headerLeft: () => (
      <TouchableOpacity onPress={() => router.back()}>
        <Ionicons name="close" size={24} color={Palette.green900} />
      </TouchableOpacity>
    )
  }), [screenTitle, router]);

  return (
    <View style={styles.container}>
      <Stack.Screen options={screenOptions} />
      
      <ScrollView contentContainerStyle={styles.content}>
        {/* Account Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('settings.account.title')}</Text>
          
          {isLoading ? (
            <View style={styles.row}>
              <ActivityIndicator size="small" color={Palette.green900} />
              <Text style={[styles.rowText, styles.loadingText]}>{t('settings.account.loading')}</Text>
            </View>
          ) : isAuthenticated ? (
            <>
              <View style={styles.userInfoRow}>
                <View style={styles.userInfo}>
                  <Text style={styles.userName}>{user?.name || t('settings.account.user')}</Text>
                  {user?.email && <Text style={styles.userEmail}>{user.email}</Text>}
                </View>
                <Ionicons name="checkmark-circle" size={24} color={Palette.green900} />
              </View>
              <View style={styles.separator} />
              <TouchableOpacity style={styles.row} onPress={() => router.push('/(main)/user')}>
                <Text style={styles.rowText}>{t('settings.account.userSettings')}</Text>
                <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
              </TouchableOpacity>
              <View style={styles.separator} />
              <TouchableOpacity style={styles.row} onPress={handleLogout}>
                <Text style={[styles.rowText, styles.logoutText]}>{t('settings.account.logout')}</Text>
                <Ionicons name="log-out-outline" size={20} color="#d32f2f" />
              </TouchableOpacity>
            </>
          ) : (
            <>
              <TouchableOpacity style={styles.row} onPress={handleLogin}>
                <Text style={styles.rowText}>{t('settings.account.login')}</Text>
                <Ionicons name="log-in-outline" size={20} color={Palette.green900} />
              </TouchableOpacity>
              <View style={styles.separator} />
              <TouchableOpacity style={styles.row} onPress={handleLogin}>
                <Text style={styles.rowText}>{t('settings.account.signup')}</Text>
                <Ionicons name="person-add-outline" size={20} color={Palette.green900} />
              </TouchableOpacity>
            </>
          )}
        </View>

        {/* Payment Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('settings.payment.title')}</Text>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/tickets')}>
            <Text style={styles.rowText}>{t('settings.payment.buyTickets')}</Text>
            <Ionicons name="ticket-outline" size={20} color={Palette.green900} />
          </TouchableOpacity>
          <View style={styles.separator} />
          <TouchableOpacity style={styles.row} onPress={() => router.push('/gift-shop')}>
            <Text style={styles.rowText}>{t('settings.payment.giftShop')}</Text>
            <Ionicons name="gift-outline" size={20} color={Palette.green900} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/donation')}>
            <Text style={styles.rowText}>{t('settings.payment.donation')}</Text>
            <Ionicons name="heart-outline" size={20} color={Palette.green900} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/brainstorm-chat')}>
            <Text style={styles.rowText}>Brainstorm ChatBot</Text>
            <Ionicons name="chatbubble-outline" size={20} color={Palette.green900} />
          </TouchableOpacity>
          <View style={styles.separator} />
          <TouchableOpacity style={styles.row} onPress={() => setFeedbackFormVisible(true)}>
            <Text style={styles.rowText}>Feedback Form</Text>
            <Ionicons name="star-outline" size={20} color={Palette.green900} />
          </TouchableOpacity>
        </View>

        {/* Preferences Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('settings.preferences.title')}</Text>
          <View style={styles.languageRow}>
            <Text style={styles.rowText}>{t('settings.preferences.language')}</Text>
          </View>
          <LanguageSwitcher />
        </View>

        {/* Accessibility Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('settings.accessibility.title')}</Text>
          <View style={styles.row}>
            <Text style={styles.rowText}>{t('settings.accessibility.largeText')}</Text>
            <Switch 
              value={isLargeText} 
              onValueChange={setIsLargeText}
              trackColor={{ false: Palette.gray900, true: Palette.green950 }}
            />
          </View>
          <View style={styles.separator} />
          <View style={styles.row}>
            <Text style={styles.rowText}>{t('settings.accessibility.textToSpeech')}</Text>
            <Switch 
              value={isTTS} 
              onValueChange={setIsTTS}
              trackColor={{ false: Palette.gray900, true: Palette.green950 }}
            />
          </View>
        </View>

        {/* Admin Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Admin</Text>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/dims-dashboard')}>
            <Text style={styles.rowText}>DIMS dashboard</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/tasks')}>
            <Text style={styles.rowText}>Tasks</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/calendar')}>
            <Text style={styles.rowText}>Calendar</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.row} onPress={() => router.push('/announcements')}>
            <Text style={styles.rowText}>Announcements</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
          <View style={styles.separator} />
          <TouchableOpacity style={styles.row} onPress={() => router.push('/qr-management')}>
            <Text style={styles.rowText}>QR Code Management</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
          <View style={styles.separator} />
          <TouchableOpacity style={styles.row} onPress={() => router.push('/business-analytics')}>
            <Text style={styles.rowText}>Business Analytics</Text>
            <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
          </TouchableOpacity>
        </View>
      </ScrollView>
      <FeedbackForm visible={feedbackFormVisible} onClose={() => setFeedbackFormVisible(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.gray100,
  },
  content: {
    padding: 20,
  },
  section: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
  },
  rowText: {
    fontSize: 16,
    color: Palette.black,
  },
  separator: {
    height: 1,
    backgroundColor: Palette.gray100,
  },
  valueContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  valueText: {
    color: '#666',
    marginRight: 8,
  },
  languageRow: {
    paddingVertical: 8,
    marginBottom: 8,
  },
  loadingText: {
    marginLeft: 12,
    opacity: 0.7,
  },
  userInfoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
  },
  userInfo: {
    flex: 1,
  },
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 4,
  },
  userEmail: {
    fontSize: 14,
    color: Palette.gray900,
  },
  logoutText: {
    color: '#d32f2f',
  },
});
