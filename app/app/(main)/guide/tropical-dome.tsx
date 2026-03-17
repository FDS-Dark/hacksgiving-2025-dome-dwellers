import React from 'react';
import { View, Text, StyleSheet, ScrollView, ImageBackground } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';

const tropicalBackground = require('@/assets/images/tropical.png');

export default function TropicalDomeScreen() {
  const router = useRouter();
  const { t } = useTranslation();

  return (
    <ImageBackground source={tropicalBackground} style={styles.background} resizeMode="cover">
      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <Stack.Screen 
          options={{ 
            headerShown: false,
          }} 
        />
        
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
            <Ionicons name="arrow-back" size={24} color={Palette.green900} />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>{t('guide.tropicalDome')}</Text>
          <View style={{ width: 40 }} />
        </View>

        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
          <View style={styles.card}>
          <View style={styles.iconContainer}>
            <Ionicons name="leaf" size={48} color={Palette.green900} />
          </View>
          <Text style={styles.title}>{t('guide.tropicalDomeTitle')}</Text>
          <Text style={styles.paragraph}>{t('guide.tropicalDomeIntro')}</Text>
          
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('guide.plantCollection')}</Text>
            <Text style={styles.paragraph}>{t('guide.tropicalPlantCollection')}</Text>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('guide.featuredPlants')}</Text>
            <Text style={styles.paragraph}>{t('guide.tropicalFeaturedPlants')}</Text>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('guide.animalResidents')}</Text>
            <Text style={styles.paragraph}>{t('guide.tropicalAnimalResidents')}</Text>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('guide.environment')}</Text>
            <Text style={styles.paragraph}>{t('guide.tropicalEnvironment')}</Text>
          </View>
        </View>
      </ScrollView>
      </SafeAreaView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  safeArea: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'flex-start',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    flex: 1,
    textAlign: 'center',
  },
  container: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingBottom: 100,
  },
  card: {
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  iconContainer: {
    alignItems: 'center',
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: Palette.green900,
    marginBottom: 16,
    textAlign: 'center',
  },
  section: {
    marginTop: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  paragraph: {
    fontSize: 16,
    lineHeight: 24,
    color: '#333',
    marginBottom: 12,
  },
});

