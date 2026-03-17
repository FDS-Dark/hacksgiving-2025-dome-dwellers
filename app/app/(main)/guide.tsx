import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';

interface FeatureCardProps {
  title: string;
  description: string;
  iconName: keyof typeof Ionicons.glyphMap;
  color: string;
  onPress: () => void;
}

const FeatureCard: React.FC<FeatureCardProps> = ({ title, description, iconName, color, onPress }) => {
  return (
    <TouchableOpacity 
      style={styles.featureCard} 
      onPress={onPress}
      activeOpacity={0.8}
    >
      <View style={[styles.featureIconContainer, { backgroundColor: color }]}>
        <Ionicons name={iconName} size={32} color={Palette.white} />
      </View>
      <View style={styles.featureContent}>
        <Text style={styles.featureTitle}>{title}</Text>
        <Text style={styles.featureDescription}>{description}</Text>
      </View>
      <Ionicons name="chevron-forward" size={24} color={Palette.gray900} />
    </TouchableOpacity>
  );
};

interface GuideButtonProps {
  label: string;
  onPress: () => void;
}

const GuideButton: React.FC<GuideButtonProps> = ({ label, onPress }) => {
  return (
    <TouchableOpacity 
      style={styles.guideButton} 
      onPress={onPress}
      activeOpacity={0.7}
    >
      <Text style={styles.guideButtonText}>{label}</Text>
      <Ionicons name="arrow-forward" size={18} color={Palette.green900} />
    </TouchableOpacity>
  );
};

export default function VisitScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  
  const guideButtons = [
    { key: 'startYourVisit', route: '/guide/start-your-visit' },
    { key: 'toursAndSuggestedRoutes', route: '/guide/tours-routes' },
    { key: 'tropicalDome', route: '/guide/tropical-dome' },
    { key: 'desertDome', route: '/guide/desert-dome' },
    { key: 'seasonalDome', route: '/guide/seasonal-dome' },
    { key: 'plants', route: '/guide/plants' },
    { key: 'accessibilityInfo', route: '/guide/accessibility-info' },
    { key: 'learnMore', route: '/guide/learn-more' },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Plan Your Visit</Text>
        <Text style={styles.headerSubtitle}>Everything you need for a great experience</Text>
      </View>

      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Tickets Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="ticket" size={24} color={Palette.green900} />
            <Text style={styles.sectionTitle}>Admission</Text>
          </View>
          <FeatureCard
            title="Purchase Tickets"
            description="Get your tickets for the conservatory"
            iconName="ticket-outline"
            color="#8b5cf6"
            onPress={() => router.push('/tickets')}
          />
        </View>

        {/* Visitor Guide Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="map" size={24} color={Palette.green900} />
            <Text style={styles.sectionTitle}>Visitor Guide</Text>
          </View>
          <View style={styles.guideGrid}>
            {guideButtons.map((button) => (
              <GuideButton
                key={button.key}
                label={t(`guide.${button.key}`)}
                onPress={() => router.push(button.route as any)}
              />
            ))}
          </View>
        </View>

        {/* Learn Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="library" size={24} color={Palette.green900} />
            <Text style={styles.sectionTitle}>Explore & Learn</Text>
          </View>
          <FeatureCard
            title="Plant Encyclopedia"
            description="Discover detailed information about our plant collection"
            iconName="book-outline"
            color="#3b82f6"
            onPress={() => router.push('/plant-encyclopedia')}
          />
        </View>

        {/* Shop Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="storefront" size={24} color={Palette.green900} />
            <Text style={styles.sectionTitle}>Shop & Support</Text>
          </View>
          <FeatureCard
            title="Gift Shop"
            description="Browse our collection of botanical gifts and souvenirs"
            iconName="gift-outline"
            color="#10b981"
            onPress={() => router.push('/gift-shop')}
          />
          <View style={styles.cardSpacer} />
          <FeatureCard
            title="Make a Donation"
            description="Support our conservation and education programs"
            iconName="heart-outline"
            color="#ef4444"
            onPress={() => router.push('/donation')}
          />
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#faf8f3',
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 24,
    paddingBottom: 20,
    backgroundColor: Palette.white,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  headerTitle: {
    fontSize: 32,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 16,
    color: Palette.gray900,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  section: {
    marginBottom: 32,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    gap: 8,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: Palette.green900,
  },
  featureCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    borderRadius: 16,
    padding: 18,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  featureIconContainer: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  featureContent: {
    flex: 1,
  },
  featureTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: Palette.green900,
    marginBottom: 4,
  },
  featureDescription: {
    fontSize: 14,
    color: Palette.gray900,
    lineHeight: 20,
  },
  cardSpacer: {
    height: 12,
  },
  guideGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  guideButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 12,
    gap: 6,
    borderWidth: 1,
    borderColor: Palette.gray100,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  guideButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
  },
});
