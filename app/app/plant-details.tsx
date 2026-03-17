import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Image,
  ActivityIndicator,
  TouchableOpacity,
} from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { usePlantDetails } from '@/hooks/use-plants';
import { useTranslation } from '@/hooks/useTranslation';

export default function PlantDetailsScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const params = useLocalSearchParams();
  const speciesId = params.id ? parseInt(params.id as string) : null;
  const { data, loading, error } = usePlantDetails(speciesId);

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          title: data?.common_name || data?.scientific_name || 'Plant Details',
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

      {loading ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>{t('plantEncyclopedia.loadingDetails')}</Text>
        </View>
      ) : error ? (
        <View style={styles.centerContainer}>
          <Ionicons name="alert-circle" size={48} color="#d32f2f" />
          <Text style={styles.errorText}>{t('plantEncyclopedia.errorDetails')}</Text>
          <Text style={styles.errorSubtext}>{error.message}</Text>
        </View>
      ) : !data ? (
        <View style={styles.centerContainer}>
          <Ionicons name="leaf-outline" size={48} color={Palette.gray900} />
          <Text style={styles.emptyText}>{t('plantEncyclopedia.plantNotFound')}</Text>
        </View>
      ) : (
        <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
          {data.image_url && (
            <Image
              source={{ uri: data.image_url }}
              style={styles.headerImage}
              resizeMode="cover"
            />
          )}

          <View style={styles.headerSection}>
            <Text style={styles.commonName}>{data.common_name || 'Unknown'}</Text>
            <Text style={styles.scientificName}>{data.scientific_name}</Text>
          </View>

          {data.description && (
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Ionicons name="information-circle" size={20} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('plantEncyclopedia.sections.description')}</Text>
              </View>
              <Text style={styles.sectionContent}>{data.description}</Text>
            </View>
          )}

          {data.care_notes && (
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Ionicons name="water" size={20} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('plantEncyclopedia.sections.careInstructions')}</Text>
              </View>
              <Text style={styles.sectionContent}>{data.care_notes}</Text>
            </View>
          )}

          {data.article_content ? (
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Ionicons name="document-text" size={20} color={Palette.green900} />
                <Text style={styles.sectionTitle}>{t('plantEncyclopedia.sections.fullArticle')}</Text>
              </View>
              <Text style={styles.articleContent}>{data.article_content}</Text>
              {data.article_updated_at && (
                <Text style={styles.articleMeta}>
                  {t('plantEncyclopedia.lastUpdated', { date: new Date(data.article_updated_at).toLocaleDateString() })}
                </Text>
              )}
            </View>
          ) : (
            <View style={styles.section}>
              <View style={styles.noArticleContainer}>
                <Ionicons name="document-outline" size={40} color={Palette.gray900} />
                <Text style={styles.noArticleText}>{t('plantEncyclopedia.noArticle')}</Text>
              </View>
            </View>
          )}
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.gray100,
  },
  scrollView: {
    flex: 1,
  },
  content: {
    paddingBottom: 32,
  },
  headerImage: {
    width: '100%',
    height: 250,
    backgroundColor: Palette.gray100,
  },
  headerSection: {
    backgroundColor: Palette.white,
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  commonName: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 8,
  },
  scientificName: {
    fontSize: 18,
    fontStyle: 'italic',
    color: Palette.gray900,
  },
  section: {
    backgroundColor: Palette.white,
    marginTop: 12,
    padding: 20,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 8,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
  },
  sectionContent: {
    fontSize: 16,
    lineHeight: 24,
    color: Palette.black,
  },
  articleContent: {
    fontSize: 16,
    lineHeight: 26,
    color: Palette.black,
  },
  articleMeta: {
    marginTop: 16,
    fontSize: 12,
    color: Palette.gray900,
    fontStyle: 'italic',
  },
  noArticleContainer: {
    alignItems: 'center',
    paddingVertical: 32,
  },
  noArticleText: {
    marginTop: 12,
    fontSize: 16,
    color: Palette.gray900,
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
});

