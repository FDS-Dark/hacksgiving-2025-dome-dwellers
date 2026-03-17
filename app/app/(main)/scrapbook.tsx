import React, { useState, useRef } from 'react';
import { useRouter } from 'expo-router';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  ScrollView,
  TouchableOpacity,
  Modal,
  TextInput,
  Image,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useScrapbookCatalog, useCollectionStats, useToggleFavorite, useUpdateNotes } from '@/hooks/use-scrapbook';
import { CollectibleCatalogEntry } from '@/types/scrapbook';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const CIRCLE_SIZE = 80;
const CANVAS_PADDING = 800; // Extra padding around the edges

const RARITY_COLORS = {
  common: Palette.gray900,
  uncommon: '#10b981',
  rare: '#3b82f6',
  legendary: '#f59e0b',
};

interface CirclePosition {
  x: number;
  y: number;
  entry: CollectibleCatalogEntry;
}

function calculateCirclePositions(entries: CollectibleCatalogEntry[], canvasWidth: number, canvasHeight: number): CirclePosition[] {
  const positions: CirclePosition[] = [];
  const centerEntry = entries[0];
  
  if (!centerEntry) return positions;
  
  // Center of the canvas
  const centerX = canvasWidth / 2;
  const centerY = canvasHeight / 2;
  
  positions.push({
    x: centerX - CIRCLE_SIZE / 2,
    y: centerY - CIRCLE_SIZE / 2,
    entry: centerEntry,
  });

  let currentRadius = 150;
  let currentIndex = 1;
  let itemsInCurrentRing = 6;
  
  while (currentIndex < entries.length) {
    const itemsToPlace = Math.min(itemsInCurrentRing, entries.length - currentIndex);
    const angleStep = (2 * Math.PI) / itemsInCurrentRing;
    
    for (let i = 0; i < itemsToPlace; i++) {
      const angle = i * angleStep;
      const x = centerX + currentRadius * Math.cos(angle) - CIRCLE_SIZE / 2;
      const y = centerY + currentRadius * Math.sin(angle) - CIRCLE_SIZE / 2;
      
      positions.push({
        x,
        y,
        entry: entries[currentIndex],
      });
      
      currentIndex++;
    }
    
    currentRadius += 120;
    itemsInCurrentRing += 6;
  }
  
  return positions;
}

interface PlantCircleProps {
  position: CirclePosition;
  onPress: () => void;
}

const PlantCircle: React.FC<PlantCircleProps> = ({ position, onPress }) => {
  const { entry } = position;
  const borderColor = RARITY_COLORS[entry.rarity_tier] || Palette.gray900;
  
  return (
    <TouchableOpacity
      style={[
        styles.circle,
        {
          position: 'absolute',
          left: position.x,
          top: position.y,
          borderColor,
          borderWidth: entry.is_discovered ? 3 : 1,
          backgroundColor: entry.is_discovered ? Palette.white : Palette.gray100,
        },
      ]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      {entry.is_discovered ? (
        <View style={styles.discoveredCircle}>
          {entry.image_url ? (
            <Image 
              source={{ uri: entry.image_url }} 
              style={styles.circleImage}
              resizeMode="cover"
            />
          ) : (
            <Ionicons name="leaf" size={40} color={borderColor} />
          )}
          {entry.is_favorite && (
            <View style={styles.favoriteBadge}>
              <Ionicons name="star" size={16} color="#f59e0b" />
            </View>
          )}
        </View>
      ) : (
        <View style={styles.undiscoveredCircle}>
          <Ionicons name="help" size={40} color={Palette.gray900} />
        </View>
      )}
      <Text style={styles.catalogNumber}>#{entry.catalog_number.toString().padStart(3, '0')}</Text>
    </TouchableOpacity>
  );
};

interface PlantDetailModalProps {
  entry: CollectibleCatalogEntry | null;
  visible: boolean;
  onClose: () => void;
}

const PlantDetailModal: React.FC<PlantDetailModalProps> = ({ entry, visible, onClose }) => {
  const [notes, setNotes] = useState(entry?.user_notes || '');
  const toggleFavoriteMutation = useToggleFavorite();
  const updateNotesMutation = useUpdateNotes();
  
  if (!entry) return null;
  
  const handleToggleFavorite = () => {
    if (entry.discovery_id) {
      toggleFavoriteMutation.mutate(entry.discovery_id);
    }
  };
  
  const handleSaveNotes = () => {
    if (entry.discovery_id && notes !== entry.user_notes) {
      updateNotesMutation.mutate({ discoveryId: entry.discovery_id, notes });
    }
  };
  
  const borderColor = RARITY_COLORS[entry.rarity_tier];
  
  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={true}
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Ionicons name="close" size={28} color={Palette.green900} />
          </TouchableOpacity>
          
          <ScrollView showsVerticalScrollIndicator={false}>
            <View style={[styles.modalHeader, { borderColor }]}>
              <View style={[styles.modalCircle, { borderColor }]}>
                {entry.is_discovered && entry.image_url ? (
                  <Image 
                    source={{ uri: entry.image_url }} 
                    style={styles.modalCircleImage}
                    resizeMode="cover"
                  />
                ) : (
                  <Ionicons
                    name={entry.is_discovered ? 'leaf' : 'help'}
                    size={60}
                    color={entry.is_discovered ? borderColor : Palette.gray900}
                  />
                )}
              </View>
              
              <Text style={styles.catalogNumberLarge}>
                #{entry.catalog_number.toString().padStart(3, '0')}
              </Text>
              
              <Text style={styles.speciesName}>
                {entry.is_discovered ? entry.species_name : '???'}
              </Text>
              
              {entry.is_discovered && (
                <Text style={styles.scientificName}>{entry.scientific_name}</Text>
              )}
              
              <View style={[styles.rarityBadge, { backgroundColor: borderColor }]}>
                <Text style={styles.rarityText}>{entry.rarity_tier.toUpperCase()}</Text>
              </View>
            </View>
            
            {!entry.is_discovered ? (
              <View style={styles.undiscoveredInfo}>
                <Ionicons name="lock-closed" size={48} color={Palette.gray900} />
                <Text style={styles.undiscoveredText}>Plant Not Discovered</Text>
                <Text style={styles.undiscoveredHint}>
                  Scan the QR code at this plant's location to unlock its information!
                </Text>
              </View>
            ) : (
              <>
                {entry.discovered_at && (
                  <View style={styles.infoSection}>
                    <Text style={styles.infoLabel}>Discovered</Text>
                    <View style={styles.infoRow}>
                      <Ionicons name="calendar" size={16} color={Palette.green900} />
                      <Text style={styles.infoText}>
                        {new Date(entry.discovered_at).toLocaleDateString('en-US', {
                          month: 'long',
                          day: 'numeric',
                          year: 'numeric',
                        })}
                      </Text>
                    </View>
                  </View>
                )}
                
                <View style={styles.infoSection}>
                  <View style={styles.favoriteHeader}>
                    <Text style={styles.infoLabel}>Favorite</Text>
                    <TouchableOpacity onPress={handleToggleFavorite} style={styles.favoriteButton}>
                      <Ionicons
                        name={entry.is_favorite ? 'star' : 'star-outline'}
                        size={24}
                        color="#f59e0b"
                      />
                    </TouchableOpacity>
                  </View>
                </View>
                
                <View style={styles.infoSection}>
                  <Text style={styles.infoLabel}>Personal Notes</Text>
                  <TextInput
                    style={styles.notesInput}
                    multiline
                    numberOfLines={4}
                    value={notes}
                    onChangeText={setNotes}
                    placeholder="Add your personal notes about this plant..."
                    placeholderTextColor={Palette.gray900}
                    onBlur={handleSaveNotes}
                  />
                </View>
                
                <TouchableOpacity style={styles.viewArticleButton}>
                  <Text style={styles.viewArticleText}>View Full Article</Text>
                  <Ionicons name="arrow-forward" size={20} color={Palette.white} />
                </TouchableOpacity>
              </>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
};

export default function ScrapbookScreen() {
  const router = useRouter();
  const { data: catalog = [], isLoading } = useScrapbookCatalog();
  const { data: stats } = useCollectionStats();
  const [selectedEntry, setSelectedEntry] = useState<CollectibleCatalogEntry | null>(null);
  const [modalVisible, setModalVisible] = useState(false);
  const scrollViewRef = useRef<ScrollView>(null);
  
  // Calculate the maximum radius needed for all circles
  const maxRadius = catalog.length > 0 ? 150 + Math.ceil((catalog.length - 1) / 6) * 120 : 0;
  const canvasWidth = Math.max(SCREEN_WIDTH, (maxRadius + CIRCLE_SIZE + CANVAS_PADDING) * 2);
  const canvasHeight = Math.max(SCREEN_HEIGHT, (maxRadius + CIRCLE_SIZE + CANVAS_PADDING) * 2);
  
  const positions = calculateCirclePositions(catalog, canvasWidth, canvasHeight);
  
  const handleCirclePress = (entry: CollectibleCatalogEntry) => {
    setSelectedEntry(entry);
    setModalVisible(true);
  };
  
  const handleCloseModal = () => {
    setModalVisible(false);
    setTimeout(() => setSelectedEntry(null), 300);
  };
  
  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading your collection...</Text>
      </View>
    );
  }
  
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <Text style={styles.headerTitle}>Plant Collection</Text>
          {stats && (
            <View style={styles.statsChip}>
              <Text style={styles.statsText}>
                {stats.total_discovered}/{stats.total_collectibles}
              </Text>
            </View>
          )}
        </View>
        
        {stats && (
          <Text style={styles.headerSubtitle}>
            {stats.discovery_percentage.toFixed(1)}% Complete
          </Text>
        )}
      </View>
      
      <ScrollView
        ref={scrollViewRef}
        style={styles.scrollView}
        contentContainerStyle={{
          width: canvasWidth,
          height: canvasHeight,
        }}
        showsVerticalScrollIndicator={false}
        showsHorizontalScrollIndicator={false}
        bounces={true}
        scrollEventThrottle={16}
        maximumZoomScale={2}
        minimumZoomScale={0.5}
        onLayout={() => {
          // Scroll to center on mount
          if (scrollViewRef.current && catalog.length > 0) {
            const centerX = (canvasWidth - SCREEN_WIDTH) / 2;
            const centerY = (canvasHeight - SCREEN_HEIGHT) / 2;
            scrollViewRef.current.scrollTo({ x: centerX, y: centerY, animated: false });
          }
        }}
      >
        <View style={styles.canvasContainer}>
          {positions.map((position, index) => (
            <PlantCircle
              key={position.entry.catalog_id}
              position={position}
              onPress={() => handleCirclePress(position.entry)}
            />
          ))}
        </View>
      </ScrollView>
      
      <View style={styles.legend}>
        <View style={styles.legendItem}>
          <View style={[styles.legendCircle, { borderColor: RARITY_COLORS.common }]} />
          <Text style={styles.legendText}>Common</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendCircle, { borderColor: RARITY_COLORS.uncommon }]} />
          <Text style={styles.legendText}>Uncommon</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendCircle, { borderColor: RARITY_COLORS.rare }]} />
          <Text style={styles.legendText}>Rare</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendCircle, { borderColor: RARITY_COLORS.legendary }]} />
          <Text style={styles.legendText}>Legendary</Text>
        </View>
      </View>
      
      <PlantDetailModal
        entry={selectedEntry}
        visible={modalVisible}
        onClose={handleCloseModal}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#faf8f3',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#faf8f3',
  },
  loadingText: {
    fontSize: 16,
    color: Palette.green900,
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 24,
    paddingBottom: 16,
    backgroundColor: Palette.white,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Palette.green900,
  },
  statsChip: {
    backgroundColor: Palette.green900,
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  statsText: {
    color: Palette.white,
    fontSize: 14,
    fontWeight: '600',
  },
  headerSubtitle: {
    fontSize: 14,
    color: Palette.gray900,
  },
  scrollView: {
    flex: 1,
  },
  canvasContainer: {
    position: 'relative',
  },
  circle: {
    width: CIRCLE_SIZE,
    height: CIRCLE_SIZE,
    borderRadius: CIRCLE_SIZE / 2,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  discoveredCircle: {
    justifyContent: 'center',
    alignItems: 'center',
    width: CIRCLE_SIZE,
    height: CIRCLE_SIZE,
    borderRadius: CIRCLE_SIZE / 2,
    overflow: 'hidden',
  },
  undiscoveredCircle: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  circleImage: {
    width: CIRCLE_SIZE,
    height: CIRCLE_SIZE,
    borderRadius: CIRCLE_SIZE / 2,
  },
  catalogNumber: {
    position: 'absolute',
    bottom: 4,
    fontSize: 10,
    fontWeight: '600',
    color: Palette.green900,
  },
  favoriteBadge: {
    position: 'absolute',
    top: -8,
    right: -8,
    backgroundColor: Palette.white,
    borderRadius: 12,
    width: 24,
    height: 24,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
  },
  legend: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: Palette.white,
    borderTopWidth: 1,
    borderTopColor: Palette.gray100,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  legendCircle: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    backgroundColor: Palette.white,
  },
  legendText: {
    fontSize: 11,
    color: Palette.green900,
    fontWeight: '500',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: Palette.white,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingTop: 24,
    paddingHorizontal: 24,
    paddingBottom: 40,
    maxHeight: SCREEN_HEIGHT * 0.85,
  },
  closeButton: {
    alignSelf: 'flex-end',
    padding: 8,
    marginBottom: 16,
  },
  modalHeader: {
    alignItems: 'center',
    paddingBottom: 24,
    borderBottomWidth: 2,
    marginBottom: 24,
  },
  modalCircle: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 4,
    backgroundColor: Palette.white,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    overflow: 'hidden',
  },
  modalCircleImage: {
    width: 120,
    height: 120,
    borderRadius: 60,
  },
  catalogNumberLarge: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.gray900,
    marginBottom: 8,
  },
  speciesName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: Palette.green900,
    textAlign: 'center',
    marginBottom: 4,
  },
  scientificName: {
    fontSize: 16,
    fontStyle: 'italic',
    color: Palette.gray900,
    textAlign: 'center',
    marginBottom: 12,
  },
  rarityBadge: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 16,
  },
  rarityText: {
    color: Palette.white,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
  },
  undiscoveredInfo: {
    alignItems: 'center',
    paddingVertical: 48,
  },
  undiscoveredText: {
    fontSize: 20,
    fontWeight: '600',
    color: Palette.gray900,
    marginTop: 16,
    marginBottom: 8,
  },
  undiscoveredHint: {
    fontSize: 14,
    color: Palette.gray900,
    textAlign: 'center',
    paddingHorizontal: 32,
  },
  infoSection: {
    marginBottom: 24,
  },
  infoLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  infoText: {
    fontSize: 16,
    color: Palette.green900,
  },
  favoriteHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  favoriteButton: {
    padding: 8,
  },
  notesInput: {
    borderWidth: 1,
    borderColor: Palette.gray900,
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
    color: Palette.green900,
    textAlignVertical: 'top',
    minHeight: 100,
  },
  viewArticleButton: {
    backgroundColor: Palette.green900,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 16,
    borderRadius: 12,
    marginTop: 8,
  },
  viewArticleText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
});

