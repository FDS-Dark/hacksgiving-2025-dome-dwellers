import { Platform } from 'react-native';
import Constants from 'expo-constants';

// Get Tailscale IP from config
const tailscaleIP = Constants.expoConfig?.extra?.tailscaleIP || process.env.EXPO_PUBLIC_TAILSCALE_IP;

// API Configuration - use Tailscale IP if available, otherwise localhost
const getApiBaseUrl = () => {
  if (tailscaleIP) {
    return `http://${tailscaleIP}:8443/api/v1`;
  }

  return Platform.select({
    ios: 'http://localhost:8443/api/v1',
    android: 'http://10.0.2.2:8443/api/v1',
    web: 'http://localhost:8443/api/v1',
    default: 'http://localhost:8443/api/v1',
  });
};

export const API_BASE_URL = getApiBaseUrl();

// Success and Cancel URLs for Stripe checkout
export const CHECKOUT_SUCCESS_URL = Platform.select({
  web: `${typeof window !== 'undefined' ? window.location.origin : ''}/success`,
  default: 'myapp://success',
});

export const CHECKOUT_CANCEL_URL = Platform.select({
  web: `${typeof window !== 'undefined' ? window.location.origin : ''}/cancel`,
  default: 'myapp://cancel',
});

// Theme colors
export const THEME_COLORS = {
  primary: '#2E7D32', // Milwaukee Domes Green
  white: '#FFFFFF',
  lightGray: '#f5f5f5',
  darkGray: '#666666',
  border: '#f0f0f0',
};

