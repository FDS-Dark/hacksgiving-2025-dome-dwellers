import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';

interface StaffCardProps {
  title: string;
  description: string;
  iconName: keyof typeof Ionicons.glyphMap;
  color: string;
  onPress: () => void;
}

const StaffCard: React.FC<StaffCardProps> = ({ title, description, iconName, color, onPress }) => {
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

export default function StaffPanelScreen() {
  const router = useRouter();

  const adminFeatures = [
    {
      id: 'dims-dashboard',
      title: 'DIMS Dashboard',
      description: 'Dome Inventory Management System',
      iconName: 'bar-chart' as keyof typeof Ionicons.glyphMap,
      color: Palette.green900,
      route: '/dims-dashboard',
    },
    {
      id: 'qr-management',
      title: 'QR Code Management',
      description: 'Manage and generate QR codes',
      iconName: 'qr-code' as keyof typeof Ionicons.glyphMap,
      color: '#8b5cf6',
      route: '/qr-management',
    },
    {
      id: 'business-analytics',
      title: 'Business Analytics',
      description: 'View visitor and revenue analytics',
      iconName: 'stats-chart' as keyof typeof Ionicons.glyphMap,
      color: '#0ea5e9',
      route: '/business-analytics',
    },
    {
      id: 'tasks',
      title: 'Tasks',
      description: 'Manage staff tasks and assignments',
      iconName: 'checkbox' as keyof typeof Ionicons.glyphMap,
      color: '#f59e0b',
      route: '/tasks',
    },
    {
      id: 'calendar',
      title: 'Calendar',
      description: 'Event scheduling and management',
      iconName: 'calendar' as keyof typeof Ionicons.glyphMap,
      color: '#ec4899',
      route: '/calendar',
    },
    {
      id: 'announcements',
      title: 'Announcements',
      description: 'Create and manage announcements',
      iconName: 'megaphone' as keyof typeof Ionicons.glyphMap,
      color: '#ef4444',
      route: '/announcements',
    },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Staff Panel</Text>
        <Text style={styles.headerSubtitle}>Administrative Tools</Text>
      </View>

      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {adminFeatures.map((feature) => (
          <StaffCard
            key={feature.id}
            title={feature.title}
            description={feature.description}
            iconName={feature.iconName}
            color={feature.color}
            onPress={() => router.push(feature.route as any)}
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

