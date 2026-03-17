import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as WebBrowser from 'expo-web-browser';
import axios from 'axios';
import { API_BASE_URL, CHECKOUT_SUCCESS_URL, CHECKOUT_CANCEL_URL, THEME_COLORS } from '@/constants/config';
import { useTranslation } from '@/hooks/useTranslation';

const ADMISSION_PRICE = 900; // $9.00 in cents
const SEASON_PASS_PRICE = 5000; // $50.00 in cents

type TicketType = 'admission' | 'season_pass';

export default function TicketsScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const [selectedType, setSelectedType] = useState<TicketType>('admission');
  const [quantity, setQuantity] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const formatPrice = (cents: number) => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  const handlePurchase = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_BASE_URL}/stripe/checkout/tickets`, {
        ticket_type: selectedType === 'admission' ? 'general' : 'season_pass',
        quantity: quantity,
        success_url: CHECKOUT_SUCCESS_URL,
        cancel_url: CHECKOUT_CANCEL_URL,
      });

      const { url } = response.data;

      if (Platform.OS === 'web') {
        window.open(url, '_blank');
      } else {
        await WebBrowser.openBrowserAsync(url);
      }
    } catch (err: any) {
      console.error('Error creating checkout session:', err);
      setError(err.response?.data?.detail || t('tickets.error.checkoutFailed'));
    } finally {
      setLoading(false);
    }
  };

  const adjustQuantity = (delta: number) => {
    setQuantity(Math.max(1, Math.min(10, quantity + delta)));
  };

  const getCurrentPrice = () => {
    return selectedType === 'admission' ? ADMISSION_PRICE : SEASON_PASS_PRICE;
  };

  return (
    <SafeAreaView style={styles.safeArea} edges={['top']}>
      <Stack.Screen options={{ headerShown: false }} />
      
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={THEME_COLORS.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>{t('tickets.headerTitle')}</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.content}>
          <View style={styles.titleSection}>
            <View style={styles.iconCircle}>
              <Ionicons name="ticket" size={32} color={THEME_COLORS.primary} />
            </View>
            <Text style={styles.title}>{t('tickets.title')}</Text>
            <Text style={styles.subtitle}>{t('tickets.subtitle')}</Text>
          </View>

          {/* Ticket Type Selection */}
          <View style={styles.ticketTypeSection}>
            <TouchableOpacity
              style={[
                styles.ticketTypeCard,
                selectedType === 'admission' && styles.ticketTypeCardSelected,
              ]}
              onPress={() => setSelectedType('admission')}>
              <View style={styles.ticketTypeHeader}>
                <Ionicons 
                  name={selectedType === 'admission' ? 'radio-button-on' : 'radio-button-off'} 
                  size={24} 
                  color={THEME_COLORS.primary} 
                />
                <Text style={styles.ticketTypeName}>{t('tickets.generalAdmission')}</Text>
              </View>
              <Text style={styles.ticketTypePrice}>{formatPrice(ADMISSION_PRICE)} {t('tickets.perPerson')}</Text>
              <Text style={styles.ticketTypeDescription}>
                {t('tickets.generalDescription')}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.ticketTypeCard,
                selectedType === 'season_pass' && styles.ticketTypeCardSelected,
              ]}
              onPress={() => setSelectedType('season_pass')}>
              <View style={styles.ticketTypeHeader}>
                <Ionicons 
                  name={selectedType === 'season_pass' ? 'radio-button-on' : 'radio-button-off'} 
                  size={24} 
                  color={THEME_COLORS.primary} 
                />
                <Text style={styles.ticketTypeName}>{t('tickets.seasonPass')}</Text>
              </View>
              <Text style={styles.ticketTypePrice}>{formatPrice(SEASON_PASS_PRICE)} {t('tickets.perPerson')}</Text>
              <Text style={styles.ticketTypeDescription}>
                {t('tickets.seasonPassDescription')}
              </Text>
            </TouchableOpacity>
          </View>

          {/* Quantity Selector */}
          <View style={styles.quantitySection}>
            <Text style={styles.sectionLabel}>{selectedType === 'admission' ? t('tickets.numberOfTickets') : t('tickets.numberOfPasses')}</Text>
            <View style={styles.quantityControls}>
              <TouchableOpacity
                style={styles.quantityButton}
                onPress={() => adjustQuantity(-1)}
                disabled={quantity <= 1}>
                <Ionicons name="remove" size={24} color="white" />
              </TouchableOpacity>
              <Text style={styles.quantityValue}>{quantity}</Text>
              <TouchableOpacity
                style={styles.quantityButton}
                onPress={() => adjustQuantity(1)}
                disabled={quantity >= 10}>
                <Ionicons name="add" size={24} color="white" />
              </TouchableOpacity>
            </View>
          </View>

          {/* Total */}
          <View style={styles.totalSection}>
            <Text style={styles.totalLabel}>{t('tickets.total')}</Text>
            <Text style={styles.totalAmount}>
              {formatPrice(getCurrentPrice() * quantity)}
            </Text>
          </View>

          {/* Error Message */}
          {error && (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          {/* Purchase Button */}
          <TouchableOpacity
            style={[
              styles.purchaseButton,
              loading && styles.purchaseButtonDisabled,
            ]}
            onPress={handlePurchase}
            disabled={loading}>
            {loading ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text style={styles.purchaseButtonText}>{t('tickets.continueToPayment')}</Text>
            )}
          </TouchableOpacity>
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
    marginBottom: 24,
  },
  iconCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
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
  },
  subtitle: {
    fontSize: 14,
    color: THEME_COLORS.darkGray,
    textAlign: 'center',
  },
  ticketTypeSection: {
    gap: 12,
    marginBottom: 24,
  },
  ticketTypeCard: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: THEME_COLORS.border,
    backgroundColor: 'white',
  },
  ticketTypeCardSelected: {
    borderColor: THEME_COLORS.primary,
    backgroundColor: '#f0f9f1',
  },
  ticketTypeHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 12,
  },
  ticketTypeName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  ticketTypePrice: {
    fontSize: 20,
    fontWeight: 'bold',
    color: THEME_COLORS.primary,
    marginBottom: 8,
  },
  ticketTypeDescription: {
    fontSize: 14,
    color: THEME_COLORS.darkGray,
    lineHeight: 20,
  },
  quantitySection: {
    marginBottom: 24,
  },
  sectionLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
    textAlign: 'center',
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 24,
  },
  quantityButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: THEME_COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  quantityValue: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#333',
    minWidth: 50,
    textAlign: 'center',
  },
  totalSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 24,
    paddingVertical: 16,
    paddingHorizontal: 16,
    borderTopWidth: 2,
    borderBottomWidth: 2,
    borderColor: THEME_COLORS.border,
    borderRadius: 12,
    backgroundColor: '#f9f9f9',
  },
  totalLabel: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  totalAmount: {
    fontSize: 28,
    fontWeight: 'bold',
    color: THEME_COLORS.primary,
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
  purchaseButton: {
    padding: 16,
    borderRadius: 30,
    backgroundColor: THEME_COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 52,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  purchaseButtonDisabled: {
    backgroundColor: '#ccc',
  },
  purchaseButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
});

