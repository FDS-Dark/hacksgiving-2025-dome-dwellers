import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, TextInput } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';
import { usePlants } from '@/hooks/use-plants';

export default function PlantsScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const [searchQuery, setSearchQuery] = useState('');
  const { data, isLoading, error } = usePlants({
    search: searchQuery || undefined,
    order_by: 'common_name',
    limit: 100,
  });

  const plants = data?.plants || [];

  return (
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
        <Text style={styles.headerTitle}>{t('guide.plants')}</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.card}>
          <View style={styles.iconContainer}>
            <Ionicons name="leaf" size={48} color={Palette.green900} />
          </View>
          <Text style={styles.title}>{t('guide.plantsTitle')}</Text>
          <Text style={styles.paragraph}>{t('guide.plantsIntro')}</Text>

          {/* Search Bar */}
          <View style={styles.searchContainer}>
            <Ionicons name="search" size={20} color={Palette.gray900} style={styles.searchIcon} />
            <TextInput
              style={styles.searchInput}
              placeholder={t('guide.searchPlants') || 'Search plants...'}
              placeholderTextColor={Palette.gray900}
              value={searchQuery}
              onChangeText={setSearchQuery}
            />
            {searchQuery.length > 0 && (
              <TouchableOpacity onPress={() => setSearchQuery('')} style={styles.clearButton}>
                <Ionicons name="close-circle" size={20} color={Palette.gray900} />
              </TouchableOpacity>
            )}
          </View>

          {/* Loading State */}
          {isLoading && (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={Palette.green900} />
              <Text style={styles.loadingText}>{t('guide.loading') || 'Loading plants...'}</Text>
            </View>
          )}

          {/* Error State */}
          {error && (
            <View style={styles.errorContainer}>
              <Ionicons name="alert-circle" size={24} color="#d32f2f" />
              <Text style={styles.errorText}>
                {t('guide.errorLoadingPlants') || 'Error loading plants. Please try again.'}
              </Text>
            </View>
          )}

          {/* Plants List */}
          {!isLoading && !error && (
            <>
              {plants.length > 0 ? (
                <>
                  <Text style={styles.resultsCount}>
                    {data?.total || plants.length} {t('guide.plantsFound') || 'plants found'}
                  </Text>
                  {plants.map((plant) => (
                    <View key={plant.id} style={styles.plantCard}>
                      {plant.common_name && (
                        <Text style={styles.plantCommonName}>{plant.common_name}</Text>
                      )}
                      <Text style={styles.plantScientificName}>{plant.scientific_name}</Text>
                      {plant.description && (
                        <Text style={styles.plantDescription}>{plant.description}</Text>
                      )}
                    </View>
                  ))}
                </>
              ) : (
                <View style={styles.emptyContainer}>
                  <Ionicons name="leaf-outline" size={48} color={Palette.gray900} />
                  <Text style={styles.emptyText}>
                    {searchQuery
                      ? t('guide.noPlantsFound') || 'No plants found matching your search.'
                      : t('guide.noPlants') || 'No plants available.'}
                  </Text>
                </View>
              )}
            </>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: Palette.white,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Palette.white,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray900,
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
    backgroundColor: Palette.white,
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
  paragraph: {
    fontSize: 16,
    lineHeight: 24,
    color: '#333',
    marginBottom: 20,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 20,
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: Palette.black,
  },
  clearButton: {
    marginLeft: 8,
  },
  loadingContainer: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: Palette.gray900,
  },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffebee',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  errorText: {
    marginLeft: 12,
    fontSize: 16,
    color: '#d32f2f',
    flex: 1,
  },
  resultsCount: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 16,
  },
  plantCard: {
    backgroundColor: Palette.gray100,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  plantCommonName: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 4,
  },
  plantScientificName: {
    fontSize: 16,
    fontStyle: 'italic',
    color: '#666',
    marginBottom: 8,
  },
  plantDescription: {
    fontSize: 14,
    lineHeight: 20,
    color: '#333',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    marginTop: 12,
    fontSize: 16,
    color: Palette.gray900,
    textAlign: 'center',
  },
});

