import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  SafeAreaView,
  TouchableOpacity,
  TextInput,
  Alert,
  Modal,
  FlatList,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useAuth0 } from '@/components/Auth0Provider';
import { qrAdminService, QRCodeDetail } from '@/services/qr-admin';
import { usePlantSpecies } from '@/hooks/use-plants';
import { Linking } from 'react-native';

export default function QRManagementScreen() {
  const router = useRouter();
  const { accessToken } = useAuth0();
  const [qrCodes, setQRCodes] = useState<QRCodeDetail[]>([]);
  const [filteredQRCodes, setFilteredQRCodes] = useState<QRCodeDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [createModalVisible, setCreateModalVisible] = useState(false);
  const [creating, setCreating] = useState(false);
  const [exporting, setExporting] = useState(false);
  
  // Species selection state
  const [speciesSearchQuery, setSpeciesSearchQuery] = useState('');
  const [selectedSpecies, setSelectedSpecies] = useState<Array<{id: number, name: string}>>([]);
  const [showSpeciesDropdown, setShowSpeciesDropdown] = useState(false);
  
  // Fetch species for autocomplete
  const { data: allSpecies = [] } = usePlantSpecies({ search: speciesSearchQuery });

  useEffect(() => {
    fetchQRCodes();
  }, []);

  useEffect(() => {
    filterQRCodes();
  }, [searchQuery, qrCodes]);

  const fetchQRCodes = async () => {
    if (!accessToken) {
      setError('Not authenticated');
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const data = await qrAdminService.getAllQRCodes(accessToken);
      setQRCodes(data);
    } catch (err) {
      console.error('Error fetching QR codes:', err);
      setError(err instanceof Error ? err.message : 'Failed to load QR codes');
    } finally {
      setLoading(false);
    }
  };

  const filterQRCodes = () => {
    if (!searchQuery.trim()) {
      setFilteredQRCodes(qrCodes);
      return;
    }

    const query = searchQuery.toLowerCase();
    const filtered = qrCodes.filter(
      (qr) =>
        qr.common_name?.toLowerCase().includes(query) ||
        qr.scientific_name.toLowerCase().includes(query) ||
        qr.species_id.toString().includes(query)
    );
    setFilteredQRCodes(filtered);
  };

  const handleCreateSingle = async () => {
    if (!accessToken) {
      Alert.alert('Error', 'Not authenticated');
      return;
    }

    if (selectedSpecies.length === 0) {
      Alert.alert('Error', 'Please select at least one plant species');
      return;
    }

    try {
      setCreating(true);
      
      if (selectedSpecies.length === 1) {
        await qrAdminService.createQRCode(selectedSpecies[0].id, accessToken);
        Alert.alert('Success', `QR code created for ${selectedSpecies[0].name}`);
      } else {
        const result = await qrAdminService.bulkCreateQRCodes(
          selectedSpecies.map(s => s.id), 
          accessToken
        );
        Alert.alert(
          'Success',
          `Created ${result.created_count} QR code(s). Some may have been skipped if they already exist.`
        );
      }
      
      setSelectedSpecies([]);
      setSpeciesSearchQuery('');
      setCreateModalVisible(false);
      fetchQRCodes();
    } catch (err) {
      console.error('Error creating QR code:', err);
      Alert.alert('Error', err instanceof Error ? err.message : 'Failed to create QR code');
    } finally {
      setCreating(false);
    }
  };

  const handleAddSpecies = (species: {id: number, scientific_name: string, common_name: string | null}) => {
    const name = species.common_name || species.scientific_name;
    if (!selectedSpecies.find(s => s.id === species.id)) {
      setSelectedSpecies([...selectedSpecies, { id: species.id, name }]);
    }
    setSpeciesSearchQuery('');
    setShowSpeciesDropdown(false);
  };

  const handleRemoveSpecies = (speciesId: number) => {
    setSelectedSpecies(selectedSpecies.filter(s => s.id !== speciesId));
  };

  const filteredSpecies = allSpecies.filter(
    species => !selectedSpecies.find(s => s.id === species.id)
  );

  const handleDownloadSingle = async (qrCode: QRCodeDetail) => {
    if (!accessToken) {
      Alert.alert('Error', 'Not authenticated');
      return;
    }

    try {
      const url = qrAdminService.getQRCodeImageWithLabelUrl(qrCode.qr_code_id, accessToken);
      
      Alert.alert(
        'Download QR Code',
        `Opening download link for ${qrCode.common_name || 'plant'}. You can save the image from your browser.`,
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Open',
            onPress: () => Linking.openURL(url),
          },
        ]
      );
    } catch (err) {
      console.error('Error downloading QR code:', err);
      Alert.alert('Error', 'Failed to download QR code');
    }
  };

  const handleExportAll = async () => {
    if (!accessToken) {
      Alert.alert('Error', 'Not authenticated');
      return;
    }

    Alert.alert(
      'Export All QR Codes',
      'This will download a ZIP file with all QR codes. The download will open in your browser.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Continue',
          onPress: async () => {
            try {
              setExporting(true);
              const { API_BASE_URL } = await import('@/constants/config');
              const url = `${API_BASE_URL}/admin/qr/codes/export-all`;
              
              await fetch(url, {
                method: 'POST',
                headers: {
                  Authorization: `Bearer ${accessToken}`,
                },
              }).then(response => response.blob())
                .then(blob => {
                  const blobUrl = URL.createObjectURL(blob);
                  const link = document.createElement('a');
                  link.href = blobUrl;
                  link.download = 'qr_codes_export.zip';
                  document.body.appendChild(link);
                  link.click();
                  document.body.removeChild(link);
                  URL.revokeObjectURL(blobUrl);
                  Alert.alert('Success', 'QR codes exported successfully');
                })
                .catch(() => {
                  Linking.openURL(url);
                });
            } catch (err) {
              console.error('Error exporting QR codes:', err);
              Alert.alert('Error', 'Failed to export QR codes');
            } finally {
              setExporting(false);
            }
          },
        },
      ]
    );
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const renderQRCodeCard = ({ item }: { item: QRCodeDetail }) => (
    <View style={styles.qrCard}>
      <View style={styles.qrCardHeader}>
        <View style={styles.qrCardHeaderLeft}>
          <Ionicons
            name={item.active ? 'qr-code' : 'qr-code-outline'}
            size={24}
            color={item.active ? Palette.green900 : Palette.gray900}
          />
          <View style={styles.qrCardHeaderText}>
            <Text style={styles.qrCardTitle}>
              {item.common_name || 'Unknown Plant'}
            </Text>
            <Text style={styles.qrCardSubtitle}>{item.scientific_name}</Text>
          </View>
        </View>
        <View style={styles.badgesContainer}>
          {!item.is_public && (
            <View style={styles.privateBadge}>
              <Ionicons name="eye-off" size={12} color="#856404" />
              <Text style={styles.privateBadgeText}>Private</Text>
            </View>
          )}
          {!item.active && (
            <View style={styles.inactiveBadge}>
              <Text style={styles.inactiveBadgeText}>Inactive</Text>
            </View>
          )}
        </View>
      </View>

      <View style={styles.qrCardDetails}>
        <View style={styles.qrCardDetailRow}>
          <Ionicons name="flask-outline" size={16} color={Palette.gray900} />
          <Text style={styles.qrCardDetailText}>
            Species ID: {item.species_id}
          </Text>
        </View>
        {item.location_name && (
          <View style={styles.qrCardDetailRow}>
            <Ionicons name="location-outline" size={16} color={Palette.gray900} />
            <Text style={styles.qrCardDetailText}>
              {item.location_name}
            </Text>
          </View>
        )}
        <View style={styles.qrCardDetailRow}>
          <Ionicons name="eye-outline" size={16} color={Palette.gray900} />
          <Text style={styles.qrCardDetailText}>
            {item.scan_count} scan{item.scan_count !== 1 ? 's' : ''}
          </Text>
        </View>
        <View style={styles.qrCardDetailRow}>
          <Ionicons name="calendar-outline" size={16} color={Palette.gray900} />
          <Text style={styles.qrCardDetailText}>
            Created: {formatDate(item.created_at)}
          </Text>
        </View>
      </View>

      <View style={styles.qrCardActions}>
        <TouchableOpacity
          style={[styles.actionButton, styles.downloadButton]}
          onPress={() => handleDownloadSingle(item)}
        >
          <Ionicons name="download-outline" size={20} color={Palette.white} />
          <Text style={styles.actionButtonText}>Download</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <Stack.Screen
        options={{
          headerShown: true,
          title: 'QR Code Management',
          headerStyle: {
            backgroundColor: Palette.white,
          },
          headerTintColor: Palette.green900,
          headerTitleStyle: {
            fontWeight: '600',
          },
        }}
      />

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>Loading QR codes...</Text>
        </View>
      ) : error ? (
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle" size={48} color="#d32f2f" />
          <Text style={styles.errorText}>{error}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={fetchQRCodes}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
        </View>
      ) : (
        <>
          <View style={styles.header}>
            <View style={styles.statsContainer}>
              <View style={styles.statCard}>
                <Text style={styles.statValue}>{qrCodes.length}</Text>
                <Text style={styles.statLabel}>Total QR Codes</Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statValue}>
                  {qrCodes.filter((qr) => qr.active).length}
                </Text>
                <Text style={styles.statLabel}>Active</Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statValue}>
                  {qrCodes.reduce((sum, qr) => sum + qr.scan_count, 0)}
                </Text>
                <Text style={styles.statLabel}>Total Scans</Text>
              </View>
            </View>

            <View style={styles.searchContainer}>
              <Ionicons name="search" size={20} color={Palette.gray900} />
              <TextInput
                style={styles.searchInput}
                placeholder="Search by name or species ID..."
                value={searchQuery}
                onChangeText={setSearchQuery}
                placeholderTextColor={Palette.gray900}
              />
              {searchQuery.length > 0 && (
                <TouchableOpacity onPress={() => setSearchQuery('')}>
                  <Ionicons name="close-circle" size={20} color={Palette.gray900} />
                </TouchableOpacity>
              )}
            </View>

            <View style={styles.actionBar}>
              <TouchableOpacity
                style={[styles.headerButton, styles.createButton]}
                onPress={() => setCreateModalVisible(true)}
              >
                <Ionicons name="add-circle-outline" size={20} color={Palette.white} />
                <Text style={styles.headerButtonText}>Create QR Code</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.headerButton, styles.exportButton]}
                onPress={handleExportAll}
                disabled={exporting || qrCodes.length === 0}
              >
                {exporting ? (
                  <ActivityIndicator size="small" color={Palette.white} />
                ) : (
                  <>
                    <Ionicons name="cloud-download-outline" size={20} color={Palette.white} />
                    <Text style={styles.headerButtonText}>Export All</Text>
                  </>
                )}
              </TouchableOpacity>
            </View>
          </View>

          <FlatList
            data={filteredQRCodes}
            renderItem={renderQRCodeCard}
            keyExtractor={(item) => item.qr_code_id.toString()}
            contentContainerStyle={styles.listContainer}
            ListEmptyComponent={
              <View style={styles.emptyContainer}>
                <Ionicons name="qr-code-outline" size={64} color={Palette.gray900} />
                <Text style={styles.emptyText}>
                  {searchQuery ? 'No QR codes match your search' : 'No QR codes yet'}
                </Text>
                {!searchQuery && (
                  <Text style={styles.emptySubtext}>
                    Create QR codes for plants to get started
                  </Text>
                )}
              </View>
            }
          />
        </>
      )}

      <Modal
        visible={createModalVisible}
        transparent
        animationType="slide"
        onRequestClose={() => {
          setCreateModalVisible(false);
          setSelectedSpecies([]);
          setSpeciesSearchQuery('');
          setShowSpeciesDropdown(false);
        }}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Create QR Codes</Text>
              <TouchableOpacity onPress={() => {
                setCreateModalVisible(false);
                setSelectedSpecies([]);
                setSpeciesSearchQuery('');
                setShowSpeciesDropdown(false);
              }}>
                <Ionicons name="close" size={24} color={Palette.green900} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
              <View style={styles.modalSection}>
                <Text style={styles.modalSectionTitle}>Select Plant Species</Text>
                <Text style={styles.modalSectionDescription}>
                  Search and select species to create QR codes for
                </Text>
                
                {/* Search Input */}
                <View style={styles.speciesSearchContainer}>
                  <Ionicons name="search" size={20} color={Palette.gray900} />
                  <TextInput
                    style={styles.speciesSearchInput}
                    placeholder="Search by scientific or common name..."
                    value={speciesSearchQuery}
                    onChangeText={(text) => {
                      setSpeciesSearchQuery(text);
                      setShowSpeciesDropdown(text.length > 0);
                    }}
                    onFocus={() => setShowSpeciesDropdown(speciesSearchQuery.length > 0)}
                    placeholderTextColor={Palette.gray900}
                  />
                </View>

                {/* Dropdown Results */}
                {showSpeciesDropdown && filteredSpecies.length > 0 && (
                  <View style={styles.speciesDropdown}>
                    <ScrollView 
                      style={styles.speciesDropdownScroll} 
                      nestedScrollEnabled
                      keyboardShouldPersistTaps="handled"
                    >
                      {filteredSpecies.slice(0, 10).map((species) => (
                        <TouchableOpacity
                          key={species.id}
                          style={styles.speciesDropdownItem}
                          onPress={() => handleAddSpecies(species)}
                        >
                          <View style={styles.speciesDropdownItemContent}>
                            <Text style={styles.speciesDropdownItemName}>
                              {species.common_name || species.scientific_name}
                            </Text>
                            {species.common_name && (
                              <Text style={styles.speciesDropdownItemScientific}>
                                {species.scientific_name}
                              </Text>
                            )}
                          </View>
                          <Ionicons name="add-circle-outline" size={20} color={Palette.green900} />
                        </TouchableOpacity>
                      ))}
                    </ScrollView>
                  </View>
                )}

                {/* Selected Species */}
                {selectedSpecies.length > 0 && (
                  <View style={styles.selectedSpeciesContainer}>
                    <Text style={styles.selectedSpeciesTitle}>
                      Selected ({selectedSpecies.length})
                    </Text>
                    <View style={styles.selectedSpeciesList}>
                      {selectedSpecies.map((species) => (
                        <View key={species.id} style={styles.selectedSpeciesChip}>
                          <Text style={styles.selectedSpeciesChipText} numberOfLines={1}>
                            {species.name}
                          </Text>
                          <TouchableOpacity onPress={() => handleRemoveSpecies(species.id)}>
                            <Ionicons name="close-circle" size={20} color={Palette.white} />
                          </TouchableOpacity>
                        </View>
                      ))}
                    </View>
                  </View>
                )}

                <TouchableOpacity
                  style={[
                    styles.modalButton, 
                    (creating || selectedSpecies.length === 0) && styles.modalButtonDisabled
                  ]}
                  onPress={handleCreateSingle}
                  disabled={creating || selectedSpecies.length === 0}
                >
                  {creating ? (
                    <ActivityIndicator size="small" color={Palette.white} />
                  ) : (
                    <Text style={styles.modalButtonText}>
                      Create {selectedSpecies.length === 1 ? 'QR Code' : `${selectedSpecies.length} QR Codes`}
                    </Text>
                  )}
                </TouchableOpacity>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.gray100,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  loadingText: {
    fontSize: 16,
    color: Palette.gray900,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
    padding: 20,
  },
  errorText: {
    fontSize: 16,
    color: '#d32f2f',
    textAlign: 'center',
  },
  retryButton: {
    marginTop: 12,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: Palette.green900,
    borderRadius: 8,
  },
  retryButtonText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
  header: {
    backgroundColor: Palette.white,
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  statsContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  statCard: {
    flex: 1,
    backgroundColor: Palette.gray100,
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  statValue: {
    fontSize: 24,
    fontWeight: '700',
    color: Palette.green900,
  },
  statLabel: {
    fontSize: 12,
    color: Palette.gray900,
    marginTop: 4,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.gray100,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 16,
    gap: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: Palette.black,
  },
  actionBar: {
    flexDirection: 'row',
    gap: 12,
  },
  headerButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    gap: 8,
  },
  createButton: {
    backgroundColor: Palette.green900,
  },
  exportButton: {
    backgroundColor: Palette.green950,
  },
  headerButtonText: {
    color: Palette.white,
    fontSize: 14,
    fontWeight: '600',
  },
  listContainer: {
    padding: 16,
  },
  qrCard: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  qrCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  qrCardHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    flex: 1,
  },
  qrCardHeaderText: {
    flex: 1,
  },
  qrCardTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 2,
  },
  qrCardSubtitle: {
    fontSize: 14,
    color: Palette.gray900,
    fontStyle: 'italic',
  },
  badgesContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  inactiveBadge: {
    backgroundColor: '#d32f2f',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  inactiveBadgeText: {
    color: Palette.white,
    fontSize: 12,
    fontWeight: '600',
  },
  privateBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#fff3cd',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  privateBadgeText: {
    color: '#856404',
    fontSize: 12,
    fontWeight: '600',
  },
  qrCardDetails: {
    gap: 8,
    marginBottom: 12,
  },
  qrCardDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  qrCardDetailText: {
    fontSize: 14,
    color: Palette.black,
  },
  qrCardActions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    gap: 6,
  },
  downloadButton: {
    backgroundColor: Palette.green900,
  },
  actionButtonText: {
    color: Palette.white,
    fontSize: 14,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    gap: 12,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.gray900,
  },
  emptySubtext: {
    fontSize: 14,
    color: Palette.gray900,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: Palette.white,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Palette.green900,
  },
  modalBody: {
    padding: 20,
  },
  modalSection: {
    marginBottom: 20,
  },
  modalSectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 4,
  },
  modalSectionDescription: {
    fontSize: 14,
    color: Palette.gray900,
    marginBottom: 12,
  },
  input: {
    backgroundColor: Palette.gray100,
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: Palette.black,
    marginBottom: 12,
  },
  textArea: {
    minHeight: 100,
    textAlignVertical: 'top',
  },
  modalButton: {
    backgroundColor: Palette.green900,
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 16,
  },
  modalButtonDisabled: {
    opacity: 0.6,
  },
  modalButtonText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
  modalDivider: {
    height: 1,
    backgroundColor: Palette.gray100,
    marginVertical: 20,
  },
  speciesSearchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.gray100,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    marginBottom: 8,
  },
  speciesSearchInput: {
    flex: 1,
    fontSize: 16,
    color: Palette.black,
  },
  speciesDropdown: {
    backgroundColor: Palette.white,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Palette.gray900,
    maxHeight: 200,
    marginBottom: 12,
  },
  speciesDropdownScroll: {
    maxHeight: 200,
  },
  speciesDropdownItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  speciesDropdownItemContent: {
    flex: 1,
  },
  speciesDropdownItemName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 2,
  },
  speciesDropdownItemScientific: {
    fontSize: 14,
    fontStyle: 'italic',
    color: Palette.gray900,
  },
  selectedSpeciesContainer: {
    marginBottom: 16,
  },
  selectedSpeciesTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  selectedSpeciesList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  selectedSpeciesChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: Palette.green900,
    paddingVertical: 8,
    paddingLeft: 12,
    paddingRight: 8,
    borderRadius: 20,
    maxWidth: '100%',
  },
  selectedSpeciesChipText: {
    color: Palette.white,
    fontSize: 14,
    fontWeight: '600',
    maxWidth: 200,
  },
});

