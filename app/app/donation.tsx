import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Platform,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as WebBrowser from 'expo-web-browser';
import axios from 'axios';
import { API_BASE_URL, CHECKOUT_SUCCESS_URL, CHECKOUT_CANCEL_URL, THEME_COLORS } from '@/constants/config';
import { useTranslation } from '@/hooks/useTranslation';

const SUGGESTED_AMOUNTS = [2500, 5000, 10000, 25000];

export default function DonationScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
  const [customAmount, setCustomAmount] = useState('');
  const [donorName, setDonorName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const formatPrice = (cents: number) => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  const handleAmountSelect = (amount: number) => {
    setSelectedAmount(amount);
    setCustomAmount('');
  };

  const handleCustomAmountChange = (text: string) => {
    const cleaned = text.replace(/[^0-9.]/g, '');
    setCustomAmount(cleaned);
    setSelectedAmount(null);
  };

  const getSelectedAmountInCents = (): number | null => {
    if (selectedAmount !== null) {
      return selectedAmount;
    }
    if (customAmount) {
      const amount = parseFloat(customAmount);
      if (!isNaN(amount) && amount > 0) {
        return Math.round(amount * 100);
      }
    }
    return null;
  };

  const handleDonate = async () => {
    const amountInCents = getSelectedAmountInCents();

    if (!amountInCents || amountInCents <= 0) {
      setError(t('donation.error.invalidAmount'));
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_BASE_URL}/stripe/checkout/donation`, {
        amount: amountInCents,
        success_url: CHECKOUT_SUCCESS_URL,
        cancel_url: CHECKOUT_CANCEL_URL,
        donor_name: donorName || undefined,
      });

      const { url } = response.data;

      if (Platform.OS === 'web') {
        window.open(url, '_blank');
      } else {
        await WebBrowser.openBrowserAsync(url);
      }
    } catch (err: any) {
      console.error('Error creating checkout session:', err);
      setError(err.response?.data?.detail || t('donation.error.checkoutFailed'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <Stack.Screen options={{ headerShown: false }} />
      
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={THEME_COLORS.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>{t('donation.headerTitle')}</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.content}>
          {/* Header Section */}
          <View style={styles.titleSection}>
            <View style={styles.iconCircle}>
              <Ionicons name="heart" size={48} color={THEME_COLORS.primary} />
            </View>
            <Text style={styles.title}>{t('donation.title')}</Text>
            <Text style={styles.subtitle}>
              {t('donation.subtitle')}
            </Text>
          </View>

          {/* Suggested Amounts */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('donation.selectAmount')}</Text>
            <View style={styles.amountGrid}>
              {SUGGESTED_AMOUNTS.map((amount) => (
                <TouchableOpacity
                  key={amount}
                  style={[
                    styles.amountButton,
                    selectedAmount === amount && styles.amountButtonSelected,
                  ]}
                  onPress={() => handleAmountSelect(amount)}>
                  <Text
                    style={[
                      styles.amountText,
                      selectedAmount === amount && styles.amountTextSelected,
                    ]}>
                    {formatPrice(amount)}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>

          {/* Custom Amount */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('donation.customAmount')}</Text>
            <View style={[
              styles.customAmountContainer,
              customAmount && styles.customAmountContainerActive,
            ]}>
              <Text style={styles.currencySymbol}>{t('common.currency')}</Text>
              <TextInput
                style={styles.customAmountInput}
                placeholder="0.00"
                placeholderTextColor={THEME_COLORS.darkGray}
                keyboardType="decimal-pad"
                value={customAmount}
                onChangeText={handleCustomAmountChange}
              />
            </View>
          </View>

          {/* Donor Name (Optional) */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('donation.yourName')}</Text>
            <TextInput
              style={styles.nameInput}
              placeholder={t('donation.namePlaceholder')}
              placeholderTextColor={THEME_COLORS.darkGray}
              value={donorName}
              onChangeText={setDonorName}
            />
            <Text style={styles.helperText}>
              {t('donation.nameHelper')}
            </Text>
          </View>

          {/* Impact Card */}
          <View style={styles.impactCard}>
            <Ionicons name="sparkles" size={32} color={THEME_COLORS.primary} />
            <View style={styles.impactContent}>
              <Text style={styles.impactTitle}>{t('donation.impactTitle')}</Text>
              <Text style={styles.impactText}>
                {t('donation.impactText')}
              </Text>
            </View>
          </View>

          {/* Error Message */}
          {error && (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          {/* Donate Button */}
          <TouchableOpacity
            style={[
              styles.donateButton,
              (!getSelectedAmountInCents() || loading) && styles.donateButtonDisabled,
            ]}
            onPress={handleDonate}
            disabled={!getSelectedAmountInCents() || loading}>
            {loading ? (
              <ActivityIndicator color="white" />
            ) : (
              <View style={styles.donateButtonContent}>
                <Ionicons name="heart" size={24} color="white" />
                <Text style={styles.donateButtonText}>
                  {getSelectedAmountInCents()
                    ? t('donation.donateButton', { amount: formatPrice(getSelectedAmountInCents()!) })
                    : t('donation.enterAmount')}
                </Text>
              </View>
            )}
          </TouchableOpacity>

          {/* Tax Notice */}
          <Text style={styles.taxNotice}>
            {t('donation.taxNotice')}
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: 'white',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: THEME_COLORS.border,
  },
  backButton: {
    padding: 8,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  container: {
    flex: 1,
  },
  content: {
    padding: 20,
  },
  titleSection: {
    alignItems: 'center',
    marginBottom: 32,
  },
  iconCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#f0f9f1',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: THEME_COLORS.darkGray,
    textAlign: 'center',
    paddingHorizontal: 20,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  amountGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  amountButton: {
    width: '48%',
    padding: 20,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: THEME_COLORS.border,
    backgroundColor: 'white',
    alignItems: 'center',
  },
  amountButtonSelected: {
    borderColor: THEME_COLORS.primary,
    backgroundColor: '#f0f9f1',
  },
  amountText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  amountTextSelected: {
    color: THEME_COLORS.primary,
  },
  customAmountContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: THEME_COLORS.border,
    borderRadius: 12,
    paddingHorizontal: 16,
    height: 56,
    backgroundColor: 'white',
  },
  customAmountContainerActive: {
    borderColor: THEME_COLORS.primary,
    backgroundColor: '#f0f9f1',
  },
  currencySymbol: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginRight: 8,
  },
  customAmountInput: {
    flex: 1,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  nameInput: {
    borderWidth: 1,
    borderColor: THEME_COLORS.border,
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#333',
    backgroundColor: 'white',
  },
  helperText: {
    fontSize: 12,
    color: THEME_COLORS.darkGray,
    marginTop: 8,
  },
  impactCard: {
    flexDirection: 'row',
    padding: 16,
    borderRadius: 12,
    backgroundColor: '#f0f9f1',
    borderWidth: 1,
    borderColor: THEME_COLORS.primary,
    marginBottom: 24,
    gap: 12,
  },
  impactContent: {
    flex: 1,
  },
  impactTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: THEME_COLORS.primary,
    marginBottom: 4,
  },
  impactText: {
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
  },
  errorContainer: {
    padding: 12,
    backgroundColor: '#fee',
    borderRadius: 8,
    marginBottom: 16,
  },
  errorText: {
    color: '#c00',
    textAlign: 'center',
  },
  donateButton: {
    padding: 16,
    borderRadius: 30,
    backgroundColor: THEME_COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 56,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  donateButtonDisabled: {
    backgroundColor: '#ccc',
  },
  donateButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  donateButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  taxNotice: {
    fontSize: 12,
    textAlign: 'center',
    color: THEME_COLORS.darkGray,
    fontStyle: 'italic',
  },
});

