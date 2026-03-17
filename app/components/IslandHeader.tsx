import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useRouter } from 'expo-router';
import { useTranslation } from '@/hooks/useTranslation';

export const IslandHeader = () => {
  const router = useRouter();
  const { t } = useTranslation();

  // Fallback colors in case Palette is somehow undefined during hot reload
  const greenColor = Palette?.green900 || '#14532d';
  const whiteColor = Palette?.white || '#ffffff';

  return (
    <SafeAreaView edges={['top']} style={styles.safeArea}>
      <View style={styles.container}>
        <View style={[styles.island, { backgroundColor: greenColor }]}>
          <TouchableOpacity onPress={() => router.push('/')}>
            <Text style={[styles.title, { color: whiteColor }]}>{t('home.title')}</Text>
          </TouchableOpacity>
          <TouchableOpacity 
            style={styles.menuButton}
            onPress={() => router.push('/settings')}
          >
            <Ionicons name="menu" size={24} color={whiteColor} />
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: 'transparent',
  },
  container: {
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 10,
  },
  island: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    // backgroundColor: Palette.green900, // moved inline for safety
    borderRadius: 30,
    paddingVertical: 18,
    paddingHorizontal: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  title: {
    // color: Palette.white, // moved inline for safety
    fontSize: 18,
    fontWeight: 'bold',
  },
  menuButton: {
    padding: 4,
  },
});
