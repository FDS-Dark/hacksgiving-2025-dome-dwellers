import React from 'react';
import { View, Text, StyleSheet, ScrollView, ImageBackground } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';

const guideBackground = require('@/assets/images/guide_background.png');

export default function AccessibilityInfoScreen() {
  const router = useRouter();
  const { t } = useTranslation();

  return (
    <ImageBackground source={guideBackground} style={styles.background} resizeMode="cover">
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
          <Text style={styles.headerTitle}>{t('guide.accessibilityInfo')}</Text>
          <View style={{ width: 40 }} />
        </View>

        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
          <View style={styles.card}>
            <View style={styles.iconContainer}>
              <Ionicons name="accessibility" size={48} color={Palette.green900} />
            </View>
            <Text style={styles.title}>{t('guide.accessibilityTitle')}</Text>
            <Text style={styles.paragraph}>{t('guide.accessibilityIntro')}</Text>
            
            <View style={styles.section}>
              <View style={styles.iconRow}>
                <Ionicons name="accessibility-outline" size={24} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('guide.wheelchairAccessibility')}</Text>
              </View>
              <Text style={styles.paragraph}>{t('guide.wheelchairAccessibilityDescription')}</Text>
            </View>

            <View style={styles.section}>
              <View style={styles.iconRow}>
                <Ionicons name="paw-outline" size={24} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('guide.serviceAnimals')}</Text>
              </View>
              <Text style={styles.paragraph}>{t('guide.serviceAnimalsDescription')}</Text>
            </View>

            <View style={styles.section}>
              <View style={styles.iconRow}>
                <Ionicons name="car-outline" size={24} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('guide.parking')}</Text>
              </View>
              <Text style={styles.paragraph}>{t('guide.parkingDescription')}</Text>
            </View>

            <View style={styles.section}>
              <View style={styles.iconRow}>
                <Ionicons name="restaurant-outline" size={24} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('guide.restrooms')}</Text>
              </View>
              <Text style={styles.paragraph}>{t('guide.restroomsDescription')}</Text>
            </View>

            <View style={styles.section}>
              <Text style={styles.sectionTitle}>{t('guide.additionalAssistance')}</Text>
              <Text style={styles.paragraph}>{t('guide.additionalAssistanceDescription')}</Text>
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
  iconRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
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
  },
  paragraph: {
    fontSize: 16,
    lineHeight: 24,
    color: '#333',
    marginBottom: 12,
  },
});

