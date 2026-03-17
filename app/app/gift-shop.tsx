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

interface GiftShopItem {
  id: string;
  name: string;
  description: string;
  price: number;
  icon: string;
}

interface CartItem extends GiftShopItem {
  quantity: number;
}

const getGiftShopItems = (t: any): GiftShopItem[] => [
  {
    id: '1',
    name: t('giftShop.items.tshirt.name'),
    description: t('giftShop.items.tshirt.description'),
    price: 2499,
    icon: 'shirt-outline',
  },
  {
    id: '2',
    name: t('giftShop.items.book.name'),
    description: t('giftShop.items.book.description'),
    price: 1999,
    icon: 'book-outline',
  },
  {
    id: '3',
    name: t('giftShop.items.keychain.name'),
    description: t('giftShop.items.keychain.description'),
    price: 999,
    icon: 'key-outline',
  },
  {
    id: '4',
    name: t('giftShop.items.poster.name'),
    description: t('giftShop.items.poster.description'),
    price: 3499,
    icon: 'image-outline',
  },
  {
    id: '5',
    name: t('giftShop.items.mug.name'),
    description: t('giftShop.items.mug.description'),
    price: 1499,
    icon: 'cafe-outline',
  },
  {
    id: '6',
    name: t('giftShop.items.cap.name'),
    description: t('giftShop.items.cap.description'),
    price: 1999,
    icon: 'shirt-outline',
  },
];

export default function GiftShopScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const [cart, setCart] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const GIFT_SHOP_ITEMS = getGiftShopItems(t);

  const formatPrice = (cents: number) => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  const addToCart = (item: GiftShopItem) => {
    setCart((prevCart) => {
      const existing = prevCart.find((i) => i.id === item.id);
      if (existing) {
        return prevCart.map((i) =>
          i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prevCart, { ...item, quantity: 1 }];
    });
  };

  const removeFromCart = (itemId: string) => {
    setCart((prevCart) => {
      const existing = prevCart.find((i) => i.id === itemId);
      if (existing && existing.quantity > 1) {
        return prevCart.map((i) =>
          i.id === itemId ? { ...i, quantity: i.quantity - 1 } : i
        );
      }
      return prevCart.filter((i) => i.id !== itemId);
    });
  };

  const getCartTotal = () => {
    return cart.reduce((sum, item) => sum + item.price * item.quantity, 0);
  };

  const getCartItemCount = () => {
    return cart.reduce((sum, item) => sum + item.quantity, 0);
  };

  const handleCheckout = async () => {
    if (cart.length === 0) {
      setError(t('giftShop.error.emptyCart'));
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const items = cart.map((item) => ({
        name: item.name,
        description: item.description,
        price: item.price,
        quantity: item.quantity,
      }));

      const response = await axios.post(`${API_BASE_URL}/stripe/checkout/gift-shop`, {
        items: items,
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
      setError(err.response?.data?.detail || t('giftShop.error.checkoutFailed'));
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
        <Text style={styles.headerTitle}>{t('giftShop.headerTitle')}</Text>
        <View style={styles.cartBadgeContainer}>
          {getCartItemCount() > 0 && (
            <>
              <Ionicons name="cart" size={24} color={THEME_COLORS.primary} />
              <View style={styles.badge}>
                <Text style={styles.badgeText}>{getCartItemCount()}</Text>
              </View>
            </>
          )}
        </View>
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.content}>
          <View style={styles.titleSection}>
            <View style={styles.iconCircle}>
              <Ionicons name="bag-handle" size={32} color={THEME_COLORS.primary} />
            </View>
            <Text style={styles.title}>{t('giftShop.title')}</Text>
            <Text style={styles.subtitle}>{t('giftShop.subtitle')}</Text>
          </View>

          {/* Products Grid */}
          <View style={styles.productGrid}>
            {GIFT_SHOP_ITEMS.map((item) => {
              const cartItem = cart.find((i) => i.id === item.id);
              const inCart = cartItem ? cartItem.quantity : 0;

              return (
                <View key={item.id} style={styles.productCard}>
                  <View style={styles.productIcon}>
                    <Ionicons name={item.icon as any} size={48} color={THEME_COLORS.primary} />
                  </View>
                  <Text style={styles.productName}>{item.name}</Text>
                  <Text style={styles.productDescription}>{item.description}</Text>
                  <Text style={styles.productPrice}>{formatPrice(item.price)}</Text>
                  
                  {inCart === 0 ? (
                    <TouchableOpacity
                      style={styles.addButton}
                      onPress={() => addToCart(item)}>
                      <Text style={styles.addButtonText}>{t('giftShop.addToCart')}</Text>
                    </TouchableOpacity>
                  ) : (
                    <View style={styles.quantityControls}>
                      <TouchableOpacity
                        style={styles.quantityButton}
                        onPress={() => removeFromCart(item.id)}>
                        <Ionicons name="remove" size={16} color="white" />
                      </TouchableOpacity>
                      <Text style={styles.quantityText}>{inCart}</Text>
                      <TouchableOpacity
                        style={styles.quantityButton}
                        onPress={() => addToCart(item)}>
                        <Ionicons name="add" size={16} color="white" />
                      </TouchableOpacity>
                    </View>
                  )}
                </View>
              );
            })}
          </View>

          {/* Cart Summary */}
          {cart.length > 0 && (
            <View style={styles.cartSummary}>
              <View style={styles.cartHeader}>
                <Text style={styles.cartTitle}>
                  {t('giftShop.cart', { count: getCartItemCount() })}
                </Text>
                <Text style={styles.cartTotal}>{formatPrice(getCartTotal())}</Text>
              </View>

              {error && (
                <View style={styles.errorContainer}>
                  <Text style={styles.errorText}>{error}</Text>
                </View>
              )}

              <TouchableOpacity
                style={[styles.checkoutButton, loading && styles.checkoutButtonDisabled]}
                onPress={handleCheckout}
                disabled={loading}>
                {loading ? (
                  <ActivityIndicator color="white" />
                ) : (
                  <Text style={styles.checkoutButtonText}>{t('giftShop.proceedToCheckout')}</Text>
                )}
              </TouchableOpacity>
            </View>
          )}
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
  cartBadgeContainer: {
    width: 40,
    alignItems: 'flex-end',
    position: 'relative',
  },
  badge: {
    position: 'absolute',
    top: -4,
    right: -4,
    backgroundColor: THEME_COLORS.primary,
    borderRadius: 10,
    width: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  badgeText: {
    color: 'white',
    fontSize: 12,
    fontWeight: 'bold',
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
  productGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 24,
  },
  productCard: {
    width: '48%',
    padding: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: THEME_COLORS.border,
    backgroundColor: 'white',
  },
  productIcon: {
    height: 100,
    borderRadius: 8,
    backgroundColor: '#f0f9f1',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  productName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  productDescription: {
    fontSize: 12,
    color: THEME_COLORS.darkGray,
    marginBottom: 8,
    minHeight: 32,
  },
  productPrice: {
    fontSize: 18,
    fontWeight: 'bold',
    color: THEME_COLORS.primary,
    marginBottom: 12,
  },
  addButton: {
    padding: 8,
    borderRadius: 20,
    backgroundColor: THEME_COLORS.primary,
    alignItems: 'center',
  },
  addButtonText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 14,
  },
  quantityControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  quantityButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: THEME_COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  quantityText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  cartSummary: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: THEME_COLORS.primary,
    backgroundColor: '#f0f9f1',
    marginTop: 8,
  },
  cartHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  cartTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  cartTotal: {
    fontSize: 24,
    fontWeight: 'bold',
    color: THEME_COLORS.primary,
  },
  errorContainer: {
    padding: 12,
    backgroundColor: '#fee',
    borderRadius: 8,
    marginBottom: 12,
  },
  errorText: {
    color: '#c00',
    textAlign: 'center',
  },
  checkoutButton: {
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
  checkoutButtonDisabled: {
    backgroundColor: '#ccc',
  },
  checkoutButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
});

