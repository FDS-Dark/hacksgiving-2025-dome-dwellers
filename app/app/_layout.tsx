import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import 'react-native-reanimated';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

import { useColorScheme } from '@/hooks/use-color-scheme';
import { Auth0Provider } from '@/components/Auth0Provider';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5 * 60 * 1000, // 5 minutes
      refetchOnWindowFocus: false,
    },
  },
});

export default function RootLayout() {
  const colorScheme = useColorScheme();

  return (
    <QueryClientProvider client={queryClient}>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <Auth0Provider>
          <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
          <Stack>
            <Stack.Screen name="(main)" options={{ headerShown: false }} />
            <Stack.Screen name="tickets" options={{ headerShown: false }} />
            <Stack.Screen name="gift-shop" options={{ headerShown: false }} />
            <Stack.Screen name="donation" options={{ headerShown: false }} />
            <Stack.Screen name="success" options={{ headerShown: false }} />
            <Stack.Screen name="cancel" options={{ headerShown: false }} />
            <Stack.Screen name="settings" options={{ presentation: 'modal', headerShown: false }} />
            <Stack.Screen name="brainstorm-chat" options={{ headerShown: false, animation: 'none' }} />
            <Stack.Screen name="dims-dashboard" />
            <Stack.Screen name="business-analytics" />
            <Stack.Screen
              name="scan"
              options={{
                presentation: 'transparentModal',
                headerShown: false,
                animation: 'fade'
              }}
            />
          </Stack>

          <StatusBar style="auto" />
        </ThemeProvider>
      </Auth0Provider>
    </GestureHandlerRootView>
    </QueryClientProvider>
  );
}
