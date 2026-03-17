import Constants from 'expo-constants';

// Auth0 Configuration
// For production, use environment variables in app.json extra field
// For development, you can set these in app.json or here directly

export const auth0Config = {
  domain: Constants.expoConfig?.extra?.auth0Domain || process.env.EXPO_PUBLIC_AUTH0_DOMAIN || 'dev-xexyzh6482alwk25.us.auth0.com',
  clientId: Constants.expoConfig?.extra?.auth0ClientId || process.env.EXPO_PUBLIC_AUTH0_CLIENT_ID || 'qHHr7LgS6xxBH3TS1JsUhJ6QEQ9QfZGc',
  audience: Constants.expoConfig?.extra?.auth0Audience || process.env.EXPO_PUBLIC_AUTH0_AUDIENCE || 'https://thedomes.api',
  tailscaleIP: Constants.expoConfig?.extra?.tailscaleIP || process.env.EXPO_PUBLIC_TAILSCALE_IP,
};

// Validate configuration
if (!auth0Config.domain || !auth0Config.clientId) {
  throw new Error('Auth0 configuration is missing. Please check your environment variables.');
}

