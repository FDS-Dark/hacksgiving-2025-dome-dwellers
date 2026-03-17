import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';

interface GameCardProps {
  title: string;
  description: string;
  iconName: keyof typeof Ionicons.glyphMap;
  color: string;
  onPress: () => void;
}

const GameCard: React.FC<GameCardProps> = ({ title, description, iconName, color, onPress }) => {
  return (
    <TouchableOpacity 
      style={[styles.card, { borderLeftColor: color }]} 
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={[styles.iconContainer, { backgroundColor: color }]}>
        <Ionicons name={iconName} size={40} color={Palette.white} />
      </View>
      
      <View style={styles.cardContent}>
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardDescription}>{description}</Text>
      </View>
      
      <Ionicons name="chevron-forward" size={24} color={Palette.gray900} />
    </TouchableOpacity>
  );
};

export default function EntertainmentScreen() {
  const router = useRouter();
  const { t } = useTranslation();

  const games = [
    {
      id: 'plant-dex',
      title: 'Plant-Dex',
      description: 'Explore your collection of discovered plants',
      iconName: 'flower' as keyof typeof Ionicons.glyphMap,
      color: Palette.green900,
      route: '/scrapbook',
    },
    {
      id: 'wordle',
      title: 'Plant Wordle',
      description: 'Guess the plant name in 6 tries',
      iconName: 'text' as keyof typeof Ionicons.glyphMap,
      color: '#10b981',
      route: '/plant-wordle',
    },
    {
      id: 'trivia',
      title: 'Plant Trivia',
      description: 'Test your botanical knowledge',
      iconName: 'help-circle' as keyof typeof Ionicons.glyphMap,
      color: '#3b82f6',
      route: '/plant-trivia',
    },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Entertainment</Text>
        <Text style={styles.headerSubtitle}>Games & Activities</Text>
      </View>

      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {games.map((game) => (
          <GameCard
            key={game.id}
            title={game.title}
            description={game.description}
            iconName={game.iconName}
            color={game.color}
            onPress={() => router.push(game.route as any)}
          />
        ))}
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
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    borderLeftWidth: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  iconContainer: {
    width: 70,
    height: 70,
    borderRadius: 35,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: Palette.green900,
    marginBottom: 6,
  },
  cardDescription: {
    fontSize: 14,
    color: Palette.gray900,
    lineHeight: 20,
  },
});

