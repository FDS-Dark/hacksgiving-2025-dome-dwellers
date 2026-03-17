import React, { useState, useMemo } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Modal, TextInput, Alert, ActivityIndicator, SafeAreaView } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import {
  usePlantInstances,
  useStorageLocations,
  useCreatePlantSpecies,
  useCreatePlantInstance,
  useCreateStorageLocation,
  useUpdatePlantInstance,
  usePlantSpecies,
} from '@/hooks/use-inventory';

interface GroupedPlant {
  id: number;
  scientific_name: string;
  common_name: string | null;
  quantity: number;
  status: string;
  location_name: string | null;
  location_type: string | null;
  identifier: string | null;
  plant_species_id: number;
  is_public: boolean;
}

interface Filters {
  searchQuery: string;
  selectedLocations: string[];
  minQuantity?: number;
  maxQuantity?: number;
  status?: string;
}

export default function DIMSDashboard() {
  const router = useRouter();
  
  // Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [filtersVisible, setFiltersVisible] = useState(false);
  const [selectedLocations, setSelectedLocations] = useState<string[]>([]);
  const [minQuantity, setMinQuantity] = useState<string>('');
  const [maxQuantity, setMaxQuantity] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('available');
  
  // Modal state
  const [modalVisible, setModalVisible] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [addPlantLocation, setAddPlantLocation] = useState<string>('');
  const [selectedPlantForEdit, setSelectedPlantForEdit] = useState<GroupedPlant | null>(null);
  
  // Form state
  const [addMode, setAddMode] = useState<'existing' | 'new'>('existing');
  const [selectedSpeciesId, setSelectedSpeciesId] = useState<number | null>(null);
  const [selectedSpeciesName, setSelectedSpeciesName] = useState('');
  const [speciesSearchQuery, setSpeciesSearchQuery] = useState('');
  const [showSpeciesDropdown, setShowSpeciesDropdown] = useState(false);
  const [scientificName, setScientificName] = useState('');
  const [commonName, setCommonName] = useState('');
  const [isPublic, setIsPublic] = useState(true);
  
  // Edit form state
  const [editQuantity, setEditQuantity] = useState('');
  const [editLocation, setEditLocation] = useState<string>('');
  const [editIsPublic, setEditIsPublic] = useState(true);

  // Hooks
  const { data: storageLocations = [], isLoading: locationsLoading } = useStorageLocations();
  const { data: allSpecies = [] } = usePlantSpecies({ search: speciesSearchQuery });

  const {
    data: plantInstances = [],
    isLoading: plantsLoading,
  } = usePlantInstances({
    status: selectedStatus || undefined,
  });

  const createPlantSpeciesMutation = useCreatePlantSpecies();
  const createPlantInstanceMutation = useCreatePlantInstance();
  const createStorageLocationMutation = useCreateStorageLocation();
  const updatePlantInstanceMutation = useUpdatePlantInstance();

  // Filter and group plants
  const groupedPlants = useMemo(() => {
    let filteredInstances = plantInstances;

    // Filter by search query
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      filteredInstances = filteredInstances.filter((plant) => {
        const scientificMatch = plant.scientific_name?.toLowerCase().includes(query);
        const commonMatch = plant.common_name?.toLowerCase().includes(query);
        const identifierMatch = plant.identifier?.toLowerCase().includes(query);
        return scientificMatch || commonMatch || identifierMatch;
      });
    }

    // Filter by selected locations
    if (selectedLocations.length > 0) {
      filteredInstances = filteredInstances.filter((plant) =>
        plant.location_name ? selectedLocations.includes(plant.location_name) : false
      );
    }

    // Filter by quantity range
    const min = minQuantity ? parseInt(minQuantity) : undefined;
    const max = maxQuantity ? parseInt(maxQuantity) : undefined;

    // Group by species and location, then filter by quantity
    const groupedBySpeciesAndLocation: Record<string, GroupedPlant> = {};
    filteredInstances.forEach((plant) => {
      const speciesId = plant.plant_species_id;
      const locationName = plant.location_name || 'Unassigned';
      const key = `${speciesId}-${locationName}`;
      
      if (speciesId) {
        if (groupedBySpeciesAndLocation[key]) {
          groupedBySpeciesAndLocation[key].quantity += plant.quantity || 1;
        } else {
          groupedBySpeciesAndLocation[key] = {
            id: speciesId,
            scientific_name: plant.scientific_name || 'Unknown',
            common_name: plant.common_name,
            quantity: plant.quantity || 1,
            status: plant.status,
            location_name: plant.location_name,
            location_type: plant.location_type,
            identifier: plant.identifier,
            plant_species_id: speciesId,
            is_public: plant.is_public ?? true,
          };
        }
      }
    });

    let results = Object.values(groupedBySpeciesAndLocation);

    // Apply quantity filters
    if (min !== undefined) {
      results = results.filter((plant) => plant.quantity >= min);
    }
    if (max !== undefined) {
      results = results.filter((plant) => plant.quantity <= max);
    }

    return results;
  }, [plantInstances, searchQuery, selectedLocations, minQuantity, maxQuantity]);

  const loading = plantsLoading || locationsLoading;

  const toggleLocationFilter = (locationName: string) => {
    setSelectedLocations((prev) =>
      prev.includes(locationName)
        ? prev.filter((loc) => loc !== locationName)
        : [...prev, locationName]
    );
  };

  const clearFilters = () => {
    setSearchQuery('');
    setSelectedLocations([]);
    setMinQuantity('');
    setMaxQuantity('');
    setSelectedStatus('available');
  };

  const handleAddPlant = () => {
    setAddMode('existing');
    setSelectedSpeciesId(null);
    setSelectedSpeciesName('');
    setSpeciesSearchQuery('');
    setShowSpeciesDropdown(false);
    setScientificName('');
    setCommonName('');
    setAddPlantLocation('');
    setIsPublic(true);
    setModalVisible(true);
  };

  const handleEditPlant = (plant: GroupedPlant) => {
    setSelectedPlantForEdit(plant);
    setEditQuantity(plant.quantity.toString());
    setEditLocation(plant.location_name || '');
    setEditIsPublic(plant.is_public);
    setEditModalVisible(true);
  };

  const handleCloseEditModal = () => {
    setEditModalVisible(false);
    setSelectedPlantForEdit(null);
    setEditQuantity('');
    setEditLocation('');
    setEditIsPublic(true);
  };

  const handleCloseModal = () => {
    setModalVisible(false);
    setAddMode('existing');
    setSelectedSpeciesId(null);
    setSelectedSpeciesName('');
    setSpeciesSearchQuery('');
    setShowSpeciesDropdown(false);
    setScientificName('');
    setCommonName('');
    setAddPlantLocation('');
    setIsPublic(true);
  };

  const handleRemovePlant = async (plant: GroupedPlant) => {
    Alert.alert(
      'Remove Plant',
      `Are you sure you want to remove "${plant.common_name || plant.scientific_name}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            try {
              // Find first available instance of this species at this location
              const instanceToRemove = plantInstances.find(
                (inst) => 
                  inst.plant_species_id === plant.plant_species_id && 
                  inst.status === 'available' &&
                  inst.location_name === plant.location_name
              );

              if (!instanceToRemove) {
                Alert.alert('Error', 'No available instances to remove');
                return;
              }

              await updatePlantInstanceMutation.mutateAsync({
                instanceId: instanceToRemove.id,
                data: { status: 'removed' },
              });

              Alert.alert('Success', 'Plant removed successfully');
            } catch (error: any) {
              Alert.alert('Error', error.message || 'An unexpected error occurred');
            }
          },
        },
      ]
    );
  };

  const handleUpdatePlant = async () => {
    if (!selectedPlantForEdit) return;

    const quantity = parseInt(editQuantity);
    if (isNaN(quantity) || quantity < 1) {
      Alert.alert('Error', 'Please enter a valid quantity');
      return;
    }

    try {
      // Find first instance of this species at this location
      const instanceToUpdate = plantInstances.find(
        (inst) => 
          inst.plant_species_id === selectedPlantForEdit.plant_species_id &&
          inst.location_name === selectedPlantForEdit.location_name
      );

      if (!instanceToUpdate) {
        Alert.alert('Error', 'Plant instance not found');
        return;
      }

      // Get or create storage location if changed
      let newLocationId: number | null = instanceToUpdate.storage_location_id;
      
      if (editLocation !== selectedPlantForEdit.location_name) {
        if (editLocation.trim()) {
          const selectedLocation = storageLocations.find(loc => loc.name === editLocation);
          newLocationId = selectedLocation?.id ?? null;

          if (!newLocationId) {
            const locationType = editLocation.toLowerCase().includes('greenhouse') 
              ? 'greenhouse' 
              : editLocation.toLowerCase().includes('dome')
              ? 'dome'
              : 'other';
            
            const newLocation = await createStorageLocationMutation.mutateAsync({
              name: editLocation,
              location_type: locationType,
            });
            newLocationId = newLocation.id;
          }
        } else {
          newLocationId = null;
        }
      }

      await updatePlantInstanceMutation.mutateAsync({
        instanceId: instanceToUpdate.id,
        data: {
          quantity,
          storage_location_id: newLocationId,
          is_public: editIsPublic,
        },
      });

      Alert.alert('Success', 'Plant updated successfully');
      handleCloseEditModal();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
    }
  };

  const handleSelectSpecies = (species: { id: number; scientific_name: string; common_name: string | null }) => {
    setSelectedSpeciesId(species.id);
    setSelectedSpeciesName(species.common_name || species.scientific_name);
    setSpeciesSearchQuery('');
    setShowSpeciesDropdown(false);
  };

  const handleSubmit = async () => {
    let speciesId: number;

    if (addMode === 'existing') {
      if (!selectedSpeciesId) {
        Alert.alert('Error', 'Please select a species');
        return;
      }
      speciesId = selectedSpeciesId;
    } else {
      if (!scientificName.trim()) {
        Alert.alert('Error', 'Please enter a scientific name');
        return;
      }

      if (!commonName.trim()) {
        Alert.alert('Error', 'Please enter a common name');
        return;
      }

      try {
        const newSpecies = await createPlantSpeciesMutation.mutateAsync({
          scientific_name: scientificName.trim(),
          common_name: commonName.trim(),
        });
        speciesId = newSpecies.id;
      } catch (error: any) {
        Alert.alert('Error', error.message || 'Failed to create species');
        return;
      }
    }

    try {

      // Get or create storage location if one is selected
      let currentLocationId: number | null = null;
      
      if (addPlantLocation.trim()) {
        const selectedLocation = storageLocations.find(loc => loc.name === addPlantLocation);
        currentLocationId = selectedLocation?.id ?? null;

        if (!currentLocationId) {
          // Determine location type from name
          const locationType = addPlantLocation.toLowerCase().includes('greenhouse') 
            ? 'greenhouse' 
            : addPlantLocation.toLowerCase().includes('dome')
            ? 'dome'
            : 'other';
          
          const newLocation = await createStorageLocationMutation.mutateAsync({
            name: addPlantLocation,
            location_type: locationType,
          });
          currentLocationId = newLocation.id;
        }
      }

      // Create plant instance
      await createPlantInstanceMutation.mutateAsync({
        plant_species_id: speciesId,
        storage_location_id: currentLocationId,
        quantity: 1,
        status: 'available',
        is_public: isPublic,
      });

      const plantName = addMode === 'existing' 
        ? selectedSpeciesName
        : (commonName.trim() || scientificName.trim());
      
      Alert.alert('Success', `Successfully added ${plantName}`);
      handleCloseModal();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Stack.Screen 
        options={{ 
          headerShown: true, 
          title: 'DIMS Dashboard',
          headerStyle: {
            backgroundColor: Palette.white,
          },
          headerTintColor: Palette.green900,
          headerTitleStyle: {
            fontWeight: '600',
          },
        }} 
      />
      
      <View style={styles.content}>
        {/* Search Bar and Filters Button */}
        <View style={styles.searchContainer}>
          <View style={styles.searchInputContainer}>
            <Ionicons name="search" size={20} color={Palette.gray900} style={styles.searchIcon} />
            <TextInput
              style={styles.searchInput}
              placeholder="Search by name or identifier..."
              placeholderTextColor={Palette.gray900}
              value={searchQuery}
              onChangeText={setSearchQuery}
            />
            {searchQuery.length > 0 && (
              <TouchableOpacity onPress={() => setSearchQuery('')}>
                <Ionicons name="close-circle" size={20} color={Palette.gray900} />
              </TouchableOpacity>
            )}
          </View>
          <TouchableOpacity
            style={[styles.filtersButton, filtersVisible && styles.filtersButtonActive]}
            onPress={() => setFiltersVisible(!filtersVisible)}
          >
            <Ionicons name="filter" size={20} color={filtersVisible ? Palette.white : Palette.green900} />
            <Text style={[styles.filtersButtonText, filtersVisible && styles.filtersButtonTextActive]}>
              Filters
            </Text>
          </TouchableOpacity>
        </View>

        {/* Filters Panel */}
        {filtersVisible && (
          <View style={styles.filtersPanel}>
            <View style={styles.filtersPanelHeader}>
              <Text style={styles.filtersPanelTitle}>Filter Options</Text>
              <TouchableOpacity onPress={clearFilters} activeOpacity={0.7}>
                <Text style={styles.clearFiltersText}>Clear All</Text>
              </TouchableOpacity>
            </View>

            {/* Location Filter */}
            <View style={styles.filterSection}>
              <Text style={styles.filterLabel}>Location</Text>
              <ScrollView 
                horizontal 
                showsHorizontalScrollIndicator={false}
                nestedScrollEnabled
              >
                <View style={styles.filterChips}>
                  {storageLocations.map((location) => (
                    <TouchableOpacity
                      key={location.id}
                      style={[
                        styles.filterChip,
                        selectedLocations.includes(location.name) && styles.filterChipActive,
                      ]}
                      onPress={() => toggleLocationFilter(location.name)}
                      activeOpacity={0.7}
                    >
                      <Text
                        style={[
                          styles.filterChipText,
                          selectedLocations.includes(location.name) && styles.filterChipTextActive,
                        ]}
                      >
                        {location.name}
                      </Text>
                    </TouchableOpacity>
                  ))}
                  {!storageLocations.some(loc => loc.name === 'Show Dome') && (
                    <TouchableOpacity
                      style={[
                        styles.filterChip,
                        selectedLocations.includes('Show Dome') && styles.filterChipActive,
                      ]}
                      onPress={() => toggleLocationFilter('Show Dome')}
                      activeOpacity={0.7}
                    >
                      <Text
                        style={[
                          styles.filterChipText,
                          selectedLocations.includes('Show Dome') && styles.filterChipTextActive,
                        ]}
                      >
                        Show Dome
                      </Text>
                    </TouchableOpacity>
                  )}
                </View>
              </ScrollView>
            </View>

            {/* Quantity Filter */}
            <View style={styles.filterSection}>
              <Text style={styles.filterLabel}>Quantity Range</Text>
              <View style={styles.quantityInputs}>
                <TextInput
                  style={styles.quantityInput}
                  placeholder="Min"
                  placeholderTextColor={Palette.gray900}
                  value={minQuantity}
                  onChangeText={setMinQuantity}
                  keyboardType="numeric"
                />
                <Text style={styles.quantityDivider}>-</Text>
                <TextInput
                  style={styles.quantityInput}
                  placeholder="Max"
                  placeholderTextColor={Palette.gray900}
                  value={maxQuantity}
                  onChangeText={setMaxQuantity}
                  keyboardType="numeric"
                />
              </View>
            </View>

            {/* Status Filter */}
            <View style={styles.filterSection}>
              <Text style={styles.filterLabel}>Status</Text>
              <View style={styles.filterChips}>
                {['available', 'reserved', 'sold', 'removed'].map((status) => (
                  <TouchableOpacity
                    key={status}
                    style={[
                      styles.filterChip,
                      selectedStatus === status && styles.filterChipActive,
                    ]}
                    onPress={() => setSelectedStatus(status)}
                    activeOpacity={0.7}
                  >
                    <Text
                      style={[
                        styles.filterChipText,
                        selectedStatus === status && styles.filterChipTextActive,
                      ]}
                    >
                      {status.charAt(0).toUpperCase() + status.slice(1)}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          </View>
        )}

        {/* Main Content Area */}
        <View style={styles.mainContent}>
          {/* Top - Plant Data */}
          <View style={styles.leftPanel}>
            <View style={styles.panelHeader}>
              <Text style={styles.panelTitle}>Plant Inventory</Text>
              <Text style={styles.panelSubtitle}>
                {loading ? 'Loading...' : `${groupedPlants.length} plant species`}
              </Text>
            </View>
            {loading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={Palette.green900} />
              </View>
            ) : (
              <ScrollView style={styles.plantList} showsVerticalScrollIndicator={false}>
                {groupedPlants.length === 0 ? (
                  <View style={styles.emptyContainer}>
                    <Text style={styles.emptyText}>No plants found in this location</Text>
                  </View>
                ) : (
                  groupedPlants.map((plant) => (
                    <View
                      key={`${plant.plant_species_id}-${plant.location_name}`}
                      style={styles.plantCard}
                    >
                      <View style={styles.plantCardHeader}>
                        <View style={styles.plantCardTitleRow}>
                          <Text style={styles.plantCommonName}>
                            {plant.common_name || plant.scientific_name}
                          </Text>
                          {plant.location_name ? (
                            <View style={styles.locationBadge}>
                              <Ionicons name="location" size={12} color={Palette.green900} />
                              <Text style={styles.locationBadgeText}>{plant.location_name}</Text>
                            </View>
                          ) : (
                            <View style={[styles.locationBadge, styles.stagingBadge]}>
                              <Ionicons name="file-tray" size={12} color={Palette.gray900} />
                              <Text style={styles.stagingBadgeText}>Staging</Text>
                            </View>
                          )}
                          {!plant.is_public && (
                            <View style={styles.visibilityBadge}>
                              <Ionicons name="eye-off" size={12} color={Palette.gray900} />
                              <Text style={styles.visibilityBadgeText}>Private</Text>
                            </View>
                          )}
                        </View>
                        <View style={[styles.statusBadge, plant.status === 'available' && styles.statusBadgeActive]}>
                          <Text style={styles.statusText}>{plant.status}</Text>
                        </View>
                      </View>
                      {plant.common_name && (
                        <Text style={styles.plantScientificName}>{plant.scientific_name}</Text>
                      )}
                      <View style={styles.plantDetails}>
                        <View style={styles.plantDetailRow}>
                          <Ionicons name="list-outline" size={16} color={Palette.green900} />
                          <Text style={styles.plantDetailText}>Quantity: {plant.quantity}</Text>
                        </View>
                        {plant.identifier && (
                          <View style={styles.plantDetailRow}>
                            <Ionicons name="pricetag-outline" size={16} color={Palette.green900} />
                            <Text style={styles.plantDetailText}>ID: {plant.identifier}</Text>
                          </View>
                        )}
                      </View>
                      <View style={styles.plantCardActions}>
                        <TouchableOpacity 
                          style={[styles.plantActionButton, styles.editButton]} 
                          onPress={() => handleEditPlant(plant)}
                        >
                          <Ionicons name="pencil" size={16} color={Palette.white} />
                          <Text style={styles.plantActionButtonText}>Edit</Text>
                        </TouchableOpacity>
                        <TouchableOpacity 
                          style={[styles.plantActionButton, styles.deleteButton]} 
                          onPress={() => handleRemovePlant(plant)}
                        >
                          <Ionicons name="trash" size={16} color={Palette.white} />
                          <Text style={styles.plantActionButtonText}>Remove</Text>
                        </TouchableOpacity>
                      </View>
                    </View>
                  ))
                )}
              </ScrollView>
            )}
          </View>

        </View>
      </View>

      {/* Floating Add Button */}
      <TouchableOpacity style={styles.floatingAddButton} onPress={handleAddPlant}>
        <Ionicons name="add" size={32} color={Palette.white} />
      </TouchableOpacity>

      {/* Modal for Add Plant */}
      <Modal
        visible={modalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={handleCloseModal}
      >
        <TouchableOpacity 
          style={styles.modalOverlay} 
          activeOpacity={1}
          onPress={handleCloseModal}
        >
          <TouchableOpacity 
            style={styles.modalContent}
            activeOpacity={1}
            onPress={(e) => e.stopPropagation()}
          >
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add Plant</Text>
              <TouchableOpacity onPress={handleCloseModal} style={styles.modalCloseButton}>
                <Ionicons name="close" size={24} color={Palette.green900} />
              </TouchableOpacity>
            </View>

            <View style={styles.tabContainer}>
              <TouchableOpacity
                style={[styles.tab, addMode === 'existing' && styles.tabActive]}
                onPress={() => setAddMode('existing')}
              >
                <Text style={[styles.tabText, addMode === 'existing' && styles.tabTextActive]}>
                  Existing Species
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.tab, addMode === 'new' && styles.tabActive]}
                onPress={() => setAddMode('new')}
              >
                <Text style={[styles.tabText, addMode === 'new' && styles.tabTextActive]}>
                  New Species
                </Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
              {addMode === 'existing' ? (
                <>
                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Select Species *</Text>
                    <Text style={styles.modalSectionDescription}>
                      Search and select a species to add to inventory
                    </Text>
                    
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

                    {showSpeciesDropdown && allSpecies.length > 0 && (
                      <View style={styles.speciesDropdown}>
                        <ScrollView 
                          style={styles.speciesDropdownScroll} 
                          nestedScrollEnabled
                          keyboardShouldPersistTaps="handled"
                        >
                          {allSpecies.slice(0, 10).map((species) => (
                            <TouchableOpacity
                              key={species.id}
                              style={styles.speciesDropdownItem}
                              onPress={() => handleSelectSpecies(species)}
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

                    {selectedSpeciesId && (
                      <View style={styles.selectedSpeciesCard}>
                        <View style={styles.selectedSpeciesCardContent}>
                          <Text style={styles.selectedSpeciesCardTitle}>Selected:</Text>
                          <Text style={styles.selectedSpeciesCardName}>{selectedSpeciesName}</Text>
                        </View>
                        <TouchableOpacity onPress={() => {
                          setSelectedSpeciesId(null);
                          setSelectedSpeciesName('');
                        }}>
                          <Ionicons name="close-circle" size={24} color={Palette.green900} />
                        </TouchableOpacity>
                      </View>
                    )}
                  </View>
                </>
              ) : (
                <>
                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Scientific Name *</Text>
                    <TextInput
                      style={styles.input}
                      value={scientificName}
                      onChangeText={setScientificName}
                      placeholder="e.g., Monstera deliciosa"
                      placeholderTextColor={Palette.gray900}
                    />
                  </View>

                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Common Name *</Text>
                    <TextInput
                      style={styles.input}
                      value={commonName}
                      onChangeText={setCommonName}
                      placeholder="e.g., Swiss Cheese Plant"
                      placeholderTextColor={Palette.gray900}
                    />
                  </View>
                </>
              )}

              <View style={styles.formGroup}>
                <Text style={styles.label}>Location</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                  <View style={styles.locationChips}>
                    <TouchableOpacity
                      style={[
                        styles.locationChip,
                        addPlantLocation === '' && styles.locationChipActive,
                      ]}
                      onPress={() => setAddPlantLocation('')}
                    >
                      <Text
                        style={[
                          styles.locationChipText,
                          addPlantLocation === '' && styles.locationChipTextActive,
                        ]}
                      >
                        No Location (Staging)
                      </Text>
                    </TouchableOpacity>
                    {storageLocations.map((location) => (
                      <TouchableOpacity
                        key={location.id}
                        style={[
                          styles.locationChip,
                          addPlantLocation === location.name && styles.locationChipActive,
                        ]}
                        onPress={() => setAddPlantLocation(location.name)}
                      >
                        <Text
                          style={[
                            styles.locationChipText,
                            addPlantLocation === location.name && styles.locationChipTextActive,
                          ]}
                        >
                          {location.name}
                        </Text>
                      </TouchableOpacity>
                    ))}
                    {!storageLocations.some(loc => loc.name === 'Show Dome') && (
                      <TouchableOpacity
                        style={[
                          styles.locationChip,
                          addPlantLocation === 'Show Dome' && styles.locationChipActive,
                        ]}
                        onPress={() => setAddPlantLocation('Show Dome')}
                      >
                        <Text
                          style={[
                            styles.locationChipText,
                            addPlantLocation === 'Show Dome' && styles.locationChipTextActive,
                          ]}
                        >
                          Show Dome
                        </Text>
                      </TouchableOpacity>
                    )}
                  </View>
                </ScrollView>
              </View>

              <View style={styles.formGroup}>
                <Text style={styles.label}>Visibility</Text>
                <View style={styles.visibilityToggle}>
                  <TouchableOpacity
                    style={[
                      styles.visibilityOption,
                      isPublic && styles.visibilityOptionActive,
                    ]}
                    onPress={() => setIsPublic(true)}
                  >
                    <Ionicons 
                      name="eye" 
                      size={20} 
                      color={isPublic ? Palette.white : Palette.green900} 
                    />
                    <Text
                      style={[
                        styles.visibilityOptionText,
                        isPublic && styles.visibilityOptionTextActive,
                      ]}
                    >
                      Public
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.visibilityOption,
                      !isPublic && styles.visibilityOptionActive,
                    ]}
                    onPress={() => setIsPublic(false)}
                  >
                    <Ionicons 
                      name="eye-off" 
                      size={20} 
                      color={!isPublic ? Palette.white : Palette.green900} 
                    />
                    <Text
                      style={[
                        styles.visibilityOptionText,
                        !isPublic && styles.visibilityOptionTextActive,
                      ]}
                    >
                      Private
                    </Text>
                  </TouchableOpacity>
                </View>
                <Text style={styles.helperText}>
                  Private plants are in staging and not visible to the public
                </Text>
              </View>
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonCancel]}
                onPress={handleCloseModal}
              >
                <Text style={styles.modalButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonPrimary]}
                onPress={handleSubmit}
                disabled={createPlantInstanceMutation.isPending || createPlantSpeciesMutation.isPending}
              >
                {createPlantInstanceMutation.isPending || createPlantSpeciesMutation.isPending ? (
                  <ActivityIndicator color={Palette.white} />
                ) : (
                  <Text style={styles.modalButtonText}>Add Plant</Text>
                )}
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>

      {/* Edit Plant Modal */}
      <Modal
        visible={editModalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={handleCloseEditModal}
      >
        <TouchableOpacity 
          style={styles.modalOverlay} 
          activeOpacity={1}
          onPress={handleCloseEditModal}
        >
          <TouchableOpacity 
            style={styles.modalContent}
            activeOpacity={1}
            onPress={(e) => e.stopPropagation()}
          >
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Edit Plant</Text>
              <TouchableOpacity onPress={handleCloseEditModal} style={styles.modalCloseButton}>
                <Ionicons name="close" size={24} color={Palette.green900} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
              {selectedPlantForEdit && (
                <>
                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Plant</Text>
                    <Text style={styles.plantInfoText}>
                      {selectedPlantForEdit.common_name || selectedPlantForEdit.scientific_name}
                    </Text>
                    {selectedPlantForEdit.common_name && (
                      <Text style={styles.plantInfoSubtext}>{selectedPlantForEdit.scientific_name}</Text>
                    )}
                  </View>

                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Quantity *</Text>
                    <TextInput
                      style={styles.input}
                      value={editQuantity}
                      onChangeText={setEditQuantity}
                      placeholder="e.g., 5"
                      placeholderTextColor={Palette.gray900}
                      keyboardType="numeric"
                    />
                  </View>

                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Location</Text>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                      <View style={styles.locationChips}>
                        <TouchableOpacity
                          style={[
                            styles.locationChip,
                            editLocation === '' && styles.locationChipActive,
                          ]}
                          onPress={() => setEditLocation('')}
                        >
                          <Text
                            style={[
                              styles.locationChipText,
                              editLocation === '' && styles.locationChipTextActive,
                            ]}
                          >
                            No Location (Staging)
                          </Text>
                        </TouchableOpacity>
                        {storageLocations.map((location) => (
                          <TouchableOpacity
                            key={location.id}
                            style={[
                              styles.locationChip,
                              editLocation === location.name && styles.locationChipActive,
                            ]}
                            onPress={() => setEditLocation(location.name)}
                          >
                            <Text
                              style={[
                                styles.locationChipText,
                                editLocation === location.name && styles.locationChipTextActive,
                              ]}
                            >
                              {location.name}
                            </Text>
                          </TouchableOpacity>
                        ))}
                      </View>
                    </ScrollView>
                  </View>

                  <View style={styles.formGroup}>
                    <Text style={styles.label}>Visibility</Text>
                    <View style={styles.visibilityToggle}>
                      <TouchableOpacity
                        style={[
                          styles.visibilityOption,
                          editIsPublic && styles.visibilityOptionActive,
                        ]}
                        onPress={() => setEditIsPublic(true)}
                      >
                        <Ionicons 
                          name="eye" 
                          size={20} 
                          color={editIsPublic ? Palette.white : Palette.green900} 
                        />
                        <Text
                          style={[
                            styles.visibilityOptionText,
                            editIsPublic && styles.visibilityOptionTextActive,
                          ]}
                        >
                          Public
                        </Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[
                          styles.visibilityOption,
                          !editIsPublic && styles.visibilityOptionActive,
                        ]}
                        onPress={() => setEditIsPublic(false)}
                      >
                        <Ionicons 
                          name="eye-off" 
                          size={20} 
                          color={!editIsPublic ? Palette.white : Palette.green900} 
                        />
                        <Text
                          style={[
                            styles.visibilityOptionText,
                            !editIsPublic && styles.visibilityOptionTextActive,
                          ]}
                        >
                          Private
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                </>
              )}
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonCancel]}
                onPress={handleCloseEditModal}
              >
                <Text style={styles.modalButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonPrimary]}
                onPress={handleUpdatePlant}
                disabled={updatePlantInstanceMutation.isPending}
              >
                {updatePlantInstanceMutation.isPending ? (
                  <ActivityIndicator color={Palette.white} />
                ) : (
                  <Text style={styles.modalButtonText}>Save Changes</Text>
                )}
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.white,
  },
  content: {
    flex: 1,
    backgroundColor: Palette.gray100,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 16,
  },
  searchContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 12,
  },
  searchInputContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Palette.white,
    borderRadius: 8,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    height: 48,
    fontSize: 16,
    color: Palette.black,
  },
  filtersButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: Palette.white,
    borderWidth: 2,
    borderColor: Palette.green900,
  },
  filtersButtonActive: {
    backgroundColor: Palette.green900,
  },
  filtersButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
  },
  filtersButtonTextActive: {
    color: Palette.white,
  },
  filtersPanel: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  filtersPanelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  filtersPanelTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
  },
  clearFiltersText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
  },
  filterSection: {
    marginBottom: 16,
  },
  filterLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  filterChips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  filterChip: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 16,
    backgroundColor: Palette.gray100,
    borderWidth: 1,
    borderColor: Palette.gray900,
  },
  filterChipActive: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  filterChipText: {
    fontSize: 13,
    fontWeight: '500',
    color: Palette.green900,
  },
  filterChipTextActive: {
    color: Palette.white,
  },
  quantityInputs: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  quantityInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: Palette.gray900,
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: Palette.black,
    backgroundColor: Palette.white,
  },
  quantityDivider: {
    fontSize: 16,
    color: Palette.gray900,
    fontWeight: '600',
  },
  mainContent: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    marginTop: 8,
  },
  leftPanel: {
    flex: 1,
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  panelHeader: {
    marginBottom: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
  },
  panelTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 4,
  },
  panelSubtitle: {
    fontSize: 14,
    color: Palette.gray900,
  },
  plantList: {
    flex: 1,
  },
  plantCard: {
    backgroundColor: Palette.gray100,
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
  },
  plantCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  plantCardTitleRow: {
    flex: 1,
    gap: 8,
  },
  plantCommonName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.black,
  },
  locationBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 12,
    backgroundColor: Palette.gray100,
    alignSelf: 'flex-start',
  },
  locationBadgeText: {
    fontSize: 11,
    fontWeight: '600',
    color: Palette.green900,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    backgroundColor: Palette.gray900,
  },
  statusBadgeActive: {
    backgroundColor: Palette.green900,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
    color: Palette.white,
  },
  plantScientificName: {
    fontSize: 14,
    fontStyle: 'italic',
    color: '#666',
    marginBottom: 8,
  },
  plantDetails: {
    gap: 6,
  },
  plantDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  plantDetailText: {
    fontSize: 12,
    color: '#666',
  },
  plantCardActions: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: Palette.gray100,
  },
  plantActionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 6,
  },
  editButton: {
    backgroundColor: Palette.green900,
  },
  deleteButton: {
    backgroundColor: '#dc2626',
  },
  plantActionButtonText: {
    fontSize: 12,
    fontWeight: '600',
    color: Palette.white,
  },
  floatingAddButton: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: Palette.green900,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
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
    maxHeight: '90%',
    paddingBottom: 20,
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
  modalCloseButton: {
    padding: 4,
  },
  modalBody: {
    padding: 20,
    maxHeight: 400,
  },
  formGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: Palette.gray900,
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: Palette.black,
    backgroundColor: Palette.white,
  },
  locationChips: {
    flexDirection: 'row',
    gap: 8,
  },
  locationChip: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: Palette.gray100,
    borderWidth: 2,
    borderColor: Palette.gray900,
  },
  locationChipActive: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  locationChipText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
  },
  locationChipTextActive: {
    color: Palette.white,
  },
  infoText: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
  modalFooter: {
    flexDirection: 'row',
    gap: 12,
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: Palette.gray100,
  },
  modalButton: {
    flex: 1,
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalButtonCancel: {
    backgroundColor: Palette.gray900,
  },
  modalButtonPrimary: {
    backgroundColor: Palette.green900,
  },
  modalButtonDanger: {
    backgroundColor: '#dc2626',
  },
  modalButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.white,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyContainer: {
    paddingVertical: 40,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    color: Palette.gray900,
    fontStyle: 'italic',
  },
  visibilityToggle: {
    flexDirection: 'row',
    gap: 12,
  },
  visibilityOption: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: Palette.gray100,
    borderWidth: 2,
    borderColor: Palette.gray900,
  },
  visibilityOptionActive: {
    backgroundColor: Palette.green900,
    borderColor: Palette.green900,
  },
  visibilityOptionText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
  },
  visibilityOptionTextActive: {
    color: Palette.white,
  },
  helperText: {
    fontSize: 12,
    color: Palette.gray900,
    fontStyle: 'italic',
    marginTop: 8,
  },
  stagingBadge: {
    backgroundColor: Palette.gray100,
  },
  stagingBadgeText: {
    fontSize: 11,
    fontWeight: '600',
    color: Palette.gray900,
  },
  visibilityBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 12,
    backgroundColor: '#fff3cd',
    alignSelf: 'flex-start',
  },
  visibilityBadgeText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#856404',
  },
  plantInfoText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 4,
  },
  plantInfoSubtext: {
    fontSize: 14,
    fontStyle: 'italic',
    color: Palette.gray900,
  },
  tabContainer: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: Palette.gray100,
    paddingHorizontal: 20,
  },
  tab: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: {
    borderBottomColor: Palette.green900,
  },
  tabText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.gray900,
  },
  tabTextActive: {
    color: Palette.green900,
  },
  modalSectionDescription: {
    fontSize: 14,
    color: Palette.gray900,
    marginBottom: 12,
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
  selectedSpeciesCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Palette.white,
    borderWidth: 2,
    borderColor: Palette.green900,
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
  },
  selectedSpeciesCardContent: {
    flex: 1,
  },
  selectedSpeciesCardTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: Palette.gray900,
    marginBottom: 4,
  },
  selectedSpeciesCardName: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
  },
});
