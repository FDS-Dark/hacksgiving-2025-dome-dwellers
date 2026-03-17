import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  TouchableOpacity,
  Image,
  ActivityIndicator,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { usePlants } from '@/hooks/use-plants';
import { PlantSpeciesListItem } from '@/types/plants';
import { useTranslation } from '@/hooks/useTranslation';

export default function PlantEncyclopediaScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const { data, isLoading, error } = usePlants({ search: debouncedSearch, limit: 50 });

  React.useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(search);
    }, 300);
    return () => clearTimeout(timer);
  }, [search]);

  const renderPlantItem = ({ item }: { item: PlantSpeciesListItem }) => (
    <TouchableOpacity
      style={styles.plantCard}
      onPress={() => router.push(`/plant-details?id=${item.id}`)}
    >
      <View style={styles.plantImageContainer}>
        {item.image_url ? (
          <Image
            source={{ uri: item.image_url }}
            style={styles.plantImage}
            resizeMode="cover"
          />
        ) : (
          <View style={[styles.plantImage, styles.placeholderImage]}>
            <Ionicons name="leaf-outline" size={40} color={Palette.green900} />
          </View>
        )}
      </View>
      
      <View style={styles.plantInfo}>
        <View style={styles.plantHeader}>
          <Text style={styles.plantCommonName} numberOfLines={1}>
            {item.common_name || item.scientific_name}
          </Text>
          {item.has_article && (
            <Ionicons name="document-text" size={16} color={Palette.green900} />
          )}
        </View>
        <Text style={styles.plantScientificName} numberOfLines={1}>
          {item.scientific_name}
        </Text>
        {item.description && (
          <Text style={styles.plantDescription} numberOfLines={2}>
            {item.description}
          </Text>
        )}
      </View>
      
      <Ionicons name="chevron-forward" size={20} color={Palette.gray900} />
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          title: t('plantEncyclopedia.title'),
          headerShown: true,
          headerStyle: { backgroundColor: Palette.green900 },
          headerTintColor: Palette.white,
          headerLeft: () => (
            <TouchableOpacity onPress={() => router.back()}>
              <Ionicons name="arrow-back" size={24} color={Palette.white} />
            </TouchableOpacity>
          ),
        }}
      />

      <View style={styles.searchContainer}>
        <Ionicons name="search" size={20} color={Palette.gray900} style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder={t('plantEncyclopedia.searchPlaceholder')}
          placeholderTextColor={Palette.gray900}
          value={search}
          onChangeText={setSearch}
          autoCapitalize="none"
          autoCorrect={false}
        />
        {search.length > 0 && (
          <TouchableOpacity onPress={() => setSearch('')} style={styles.clearButton}>
            <Ionicons name="close-circle" size={20} color={Palette.gray900} />
          </TouchableOpacity>
        )}
      </View>

      {isLoading && !data ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>{t('plantEncyclopedia.loading')}</Text>
        </View>
      ) : error ? (
        <View style={styles.centerContainer}>
          <Ionicons name="alert-circle" size={48} color="#d32f2f" />
          <Text style={styles.errorText}>{t('plantEncyclopedia.error')}</Text>
          <Text style={styles.errorSubtext}>{error.message}</Text>
        </View>
      ) : data && data.plants.length === 0 ? (
        <View style={styles.centerContainer}>
          <Ionicons name="leaf-outline" size={48} color={Palette.gray900} />
          <Text style={styles.emptyText}>{t('plantEncyclopedia.emptyTitle')}</Text>
          {search && <Text style={styles.emptySubtext}>{t('plantEncyclopedia.emptySubtext')}</Text>}
        </View>
      ) : (
        <>
          <View style={styles.resultsHeader}>
            <Text style={styles.resultsText}>
              {t(`plantEncyclopedia.resultsCount${data?.total !== 1 ? '_plural' : ''}`, { count: data?.total || 0 })}
            </Text>
          </View>
          <FlatList
            data={data?.plants || []}
            renderItem={renderPlantItem}
            keyExtractor={(item) => item.id.toString()}
            contentContainerStyle={styles.listContent}
            ItemSeparatorComponent={() => <View style={styles.separator} />}
          />
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.gray100,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    margin: 16,
    paddingHorizontal: 12,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: 16,
    color: Palette.black,
  },
  clearButton: {
    padding: 4,
  },
  resultsHeader: {
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  resultsText: {
    fontSize: 14,
    color: Palette.gray900,
    fontWeight: '500',
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  plantCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  plantImageContainer: {
    marginRight: 12,
  },
  plantImage: {
    width: 64,
    height: 64,
    borderRadius: 8,
  },
  placeholderImage: {
    backgroundColor: Palette.gray100,
    justifyContent: 'center',
    alignItems: 'center',
  },
  plantInfo: {
    flex: 1,
    marginRight: 8,
  },
  plantHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 2,
  },
  plantCommonName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    flex: 1,
  },
  plantScientificName: {
    fontSize: 14,
    fontStyle: 'italic',
    color: Palette.gray900,
    marginBottom: 4,
  },
  plantDescription: {
    fontSize: 13,
    color: Palette.black,
    opacity: 0.7,
  },
  separator: {
    height: 12,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: Palette.gray900,
  },
  errorText: {
    marginTop: 16,
    fontSize: 18,
    fontWeight: '600',
    color: '#d32f2f',
    textAlign: 'center',
  },
  errorSubtext: {
    marginTop: 8,
    fontSize: 14,
    color: Palette.gray900,
    textAlign: 'center',
  },
  emptyText: {
    marginTop: 16,
    fontSize: 18,
    fontWeight: '600',
    color: Palette.gray900,
    textAlign: 'center',
  },
  emptySubtext: {
    marginTop: 8,
    fontSize: 14,
    color: Palette.gray900,
    textAlign: 'center',
  },
});

