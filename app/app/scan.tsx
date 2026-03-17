import React, { useState, useEffect, useRef } from 'react';
import { CameraView, CameraType, useCameraPermissions } from 'expo-camera';
import { 
  StyleSheet, 
  Text, 
  TouchableOpacity, 
  View, 
  Modal, 
  Dimensions, 
  Animated, 
  Image,
  ActivityIndicator 
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';
import { useAuth0 } from '@/components/Auth0Provider';
import { scrapbookService } from '@/services/scrapbook';

const { width, height } = Dimensions.get('window');
const BOX_SIZE = 250;

export default function ScanScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { user, accessToken } = useAuth0();
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [showCamera, setShowCamera] = useState(true);
  const [celebrationData, setCelebrationData] = useState<{
    speciesName: string;
    catalogNumber: number;
    speciesId: number;
    catalogEntryId: number;
    alreadyDiscovered: boolean;
  } | null>(null);
  const lastScanTime = useRef<number>(0);
  const DEBOUNCE_MS = 2000;

  if (!permission) {
    return <View style={styles.container} />;
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <View style={styles.permissionModal}>
          <Text style={styles.message}>{t('scan.permissionMessage')}</Text>
          <TouchableOpacity style={styles.permissionButton} onPress={requestPermission}>
             <Text style={styles.permissionButtonText}>{t('scan.grantPermission')}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.closeButton} onPress={() => router.back()}>
            <Text style={styles.closeButtonText}>{t('scan.close')}</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  const handleBarCodeScanned = async ({ type, data }: { type: string; data: string }) => {
    if (scanning || !user || !accessToken) return;
    
    const now = Date.now();
    if (now - lastScanTime.current < DEBOUNCE_MS) {
      console.log('Scan debounced - too soon after last scan');
      return;
    }
    lastScanTime.current = now;
    
    console.log('QR Code scanned:', data);
    
    setScanned(true);
    setScanning(true);
    setShowCamera(false); // Hide camera immediately

    try {
      // Extract QR token from the URL or use data directly
      let qrToken = data;
      
      // If it's a deep link URL, extract the qr parameter
      if (data.includes('qr=')) {
        try {
          const url = new URL(data);
          qrToken = url.searchParams.get('qr') || data;
        } catch (e) {
          // If URL parsing fails, try to extract manually
          const match = data.match(/qr=([^&]+)/);
          if (match) {
            qrToken = match[1];
          }
        }
      }

      console.log('Extracted QR token:', qrToken);

      const response = await scrapbookService.scanQRCode(accessToken, qrToken);
      
      console.log('Scan response:', response);

      if (response.success && response.plant_species_id) {
        // Show celebration data
        setShowCamera(false);
        setCelebrationData({
          speciesName: response.species_name || 'Unknown Plant',
          catalogNumber: response.catalog_number || 0,
          speciesId: response.plant_species_id || 0, // Species ID for navigation
          catalogEntryId: response.catalog_entry_id || 0,
          alreadyDiscovered: response.already_discovered,
        });
      } else {
        alert(response.message || 'Failed to scan QR code');
        setScanned(false);
        setScanning(false);
        setShowCamera(true); // Show camera again if failed
      }
    } catch (error) {
      console.error('QR scan error:', error);
      alert('Failed to process QR code. Please try again.');
      setScanned(false);
      setScanning(false);
      setShowCamera(true); // Show camera again if failed
    }
  };

  const handleCelebrationClose = () => {
    console.log('Celebration closing, navigating to plant details...');
    if (celebrationData) {
      // Navigate to encyclopedia page for this plant
      router.replace(`/plant-details?id=${celebrationData.speciesId}`);
    } else {
      // If no data, go back
      router.back();
    }
  };

  const handleRescan = () => {
    setCelebrationData(null);
    setScanned(false);
    setScanning(false);
    setShowCamera(true);
    lastScanTime.current = 0;
  };

  return (
    <View style={styles.container}>
      {showCamera && (
        <>
          <CameraView 
            style={styles.camera} 
            facing="back"
            onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
          />
          <View style={styles.overlay}>
            <View style={styles.overlayTop} />
            <View style={styles.overlayMiddle}>
                <View style={styles.overlaySide} />
                <View style={styles.boxContainer}>
                  <View style={styles.cornerTL} />
                  <View style={styles.cornerTR} />
                  <View style={styles.cornerBL} />
                  <View style={styles.cornerBR} />
                </View>
                <View style={styles.overlaySide} />
            </View>
            <View style={styles.overlayBottom}>
              <TouchableOpacity style={styles.cancelButton} onPress={() => router.back()}>
                <Ionicons name="close-circle" size={60} color="white" />
              </TouchableOpacity>
              <Text style={styles.instructionText}>
                {scanning ? 'Processing...' : t('scan.instruction')}
              </Text>
            </View>
          </View>
        </>
      )}
      
      {!showCamera && (
        <View style={[styles.container, { backgroundColor: 'black' }]}>
          {scanning && !celebrationData && (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={Palette.green900} />
              <Text style={styles.loadingText}>Processing QR code...</Text>
            </View>
          )}
        </View>
      )}

      {/* Celebration Modal */}
      {celebrationData && (
        <CelebrationModal
          data={celebrationData}
          onClose={handleCelebrationClose}
        />
      )}
    </View>
  );
}

function CelebrationModal({
  data,
  onClose,
}: {
  data: {
    speciesName: string;
    catalogNumber: number;
    speciesId: number;
    alreadyDiscovered: boolean;
  };
  onClose: () => void;
}) {
  const spinValue = useRef(new Animated.Value(0)).current;
  const scaleValue = useRef(new Animated.Value(0)).current;
  const fadeValue = useRef(new Animated.Value(0)).current;
  const [plantImage, setPlantImage] = useState<string | null>(null);

  useEffect(() => {
    // If already discovered, navigate immediately
    if (data.alreadyDiscovered) {
      setTimeout(onClose, 1500);
      return;
    }

    // Animation sequence for new discovery
    Animated.sequence([
      // Fade in background
      Animated.timing(fadeValue, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
      // Scale in the card
      Animated.spring(scaleValue, {
        toValue: 1,
        friction: 8,
        tension: 40,
        useNativeDriver: true,
      }),
      // Spin animation
      Animated.loop(
        Animated.timing(spinValue, {
          toValue: 1,
          duration: 3000,
          useNativeDriver: true,
        })
      ),
    ]).start();
  }, [data.alreadyDiscovered]);

  const spin = spinValue.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  // Fetch plant image (you may need to adjust this based on your API)
  useEffect(() => {
    // For now, using a placeholder - you can fetch the actual image from your API
    setPlantImage(null); // Will show icon instead
  }, [data.speciesId]);

  if (data.alreadyDiscovered) {
    return (
      <Modal transparent visible animationType="fade">
        <View style={styles.celebrationOverlay}>
          <View style={styles.alreadyDiscoveredCard}>
            <Ionicons name="checkmark-circle" size={60} color={Palette.green900} />
            <Text style={styles.alreadyDiscoveredText}>
              You've already discovered this plant!
            </Text>
            <Text style={styles.celebrationSpeciesName}>{data.speciesName}</Text>
            <ActivityIndicator size="small" color={Palette.green900} style={{ marginTop: 16 }} />
            <Text style={styles.redirectText}>Taking you to encyclopedia...</Text>
          </View>
        </View>
      </Modal>
    );
  }

  return (
    <Modal transparent visible animationType="none">
      <Animated.View style={[styles.celebrationOverlay, { opacity: fadeValue }]}>
        <Animated.View style={[styles.celebrationCard, { transform: [{ scale: scaleValue }] }]}>
          {/* Confetti/Stars effect */}
          <View style={styles.confettiContainer}>
            <Ionicons name="star" size={30} color="#FFD700" style={styles.confetti1} />
            <Ionicons name="star" size={25} color="#FFA500" style={styles.confetti2} />
            <Ionicons name="star" size={20} color="#FFD700" style={styles.confetti3} />
            <Ionicons name="star" size={25} color="#FFA500" style={styles.confetti4} />
          </View>

          <Text style={styles.celebrationTitle}>🎉 New Discovery! 🎉</Text>
          
          {/* Spinning plant image/icon */}
          <Animated.View style={[styles.plantImageContainer, { transform: [{ rotate: spin }] }]}>
            {plantImage ? (
              <Image source={{ uri: plantImage }} style={styles.plantImage} />
            ) : (
              <Ionicons name="leaf" size={120} color={Palette.green900} />
            )}
          </Animated.View>

          <Text style={styles.celebrationSpeciesName}>{data.speciesName}</Text>
          <Text style={styles.catalogNumber}>#{data.catalogNumber.toString().padStart(3, '0')}</Text>
          
          <Text style={styles.celebrationMessage}>
            Congratulations! This plant has been added to your scrapbook!
          </Text>

          <TouchableOpacity style={styles.celebrationButton} onPress={onClose}>
            <Text style={styles.celebrationButtonText}>View in Encyclopedia</Text>
            <Ionicons name="arrow-forward" size={20} color={Palette.white} />
          </TouchableOpacity>
        </Animated.View>
      </Animated.View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: 'black', // Fallback
  },
  camera: {
    flex: 1,
    width: '100%',
    height: '100%',
  },
  permissionModal: {
    flex: 1, 
    justifyContent: 'center', 
    alignItems: 'center', 
    backgroundColor: Palette.white,
    padding: 20
  },
  message: {
    textAlign: 'center',
    paddingBottom: 10,
    fontSize: 16,
    color: Palette.black
  },
  permissionButton: {
    backgroundColor: Palette.green900,
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    marginTop: 10,
  },
  permissionButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
  closeButton: {
    marginTop: 20,
  },
  closeButtonText: {
    color: Palette.green900,
    fontSize: 16,
  },
  // Overlay styles to create the "darkened" effect with a clear hole
  overlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 1,
  },
  overlayTop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  overlayMiddle: {
    flexDirection: 'row',
    height: BOX_SIZE,
  },
  overlaySide: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  boxContainer: {
    width: BOX_SIZE,
    height: BOX_SIZE,
    borderColor: 'transparent',
    position: 'relative',
  },
  overlayBottom: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingTop: 40,
  },
  cornerTL: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 40,
    height: 40,
    borderTopWidth: 4,
    borderLeftWidth: 4,
    borderColor: Palette.green900,
    borderTopLeftRadius: 12,
  },
  cornerTR: {
    position: 'absolute',
    top: 0,
    right: 0,
    width: 40,
    height: 40,
    borderTopWidth: 4,
    borderRightWidth: 4,
    borderColor: Palette.green900,
    borderTopRightRadius: 12,
  },
  cornerBL: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    width: 40,
    height: 40,
    borderBottomWidth: 4,
    borderLeftWidth: 4,
    borderColor: Palette.green900,
    borderBottomLeftRadius: 12,
  },
  cornerBR: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 40,
    height: 40,
    borderBottomWidth: 4,
    borderRightWidth: 4,
    borderColor: Palette.green900,
    borderBottomRightRadius: 12,
  },
  cancelButton: {
    marginBottom: 20,
  },
  instructionText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '500',
  },
  // Celebration Modal Styles
  celebrationOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  celebrationCard: {
    backgroundColor: Palette.white,
    borderRadius: 24,
    padding: 32,
    alignItems: 'center',
    width: '90%',
    maxWidth: 400,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  confettiContainer: {
    ...StyleSheet.absoluteFillObject,
    pointerEvents: 'none',
  },
  confetti1: {
    position: 'absolute',
    top: 20,
    left: 30,
  },
  confetti2: {
    position: 'absolute',
    top: 40,
    right: 40,
  },
  confetti3: {
    position: 'absolute',
    bottom: 100,
    left: 50,
  },
  confetti4: {
    position: 'absolute',
    bottom: 120,
    right: 30,
  },
  celebrationTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 24,
    textAlign: 'center',
  },
  plantImageContainer: {
    width: 150,
    height: 150,
    borderRadius: 75,
    backgroundColor: Palette.gray100,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    overflow: 'hidden',
  },
  plantImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  celebrationSpeciesName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: Palette.black,
    textAlign: 'center',
    marginBottom: 8,
  },
  catalogNumber: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 16,
  },
  celebrationMessage: {
    fontSize: 16,
    color: Palette.gray900,
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 22,
  },
  celebrationButton: {
    backgroundColor: Palette.green900,
    paddingHorizontal: 32,
    paddingVertical: 16,
    borderRadius: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  celebrationButtonText: {
    color: Palette.white,
    fontSize: 18,
    fontWeight: 'bold',
  },
  alreadyDiscoveredCard: {
    backgroundColor: Palette.white,
    borderRadius: 20,
    padding: 32,
    alignItems: 'center',
    width: '85%',
    maxWidth: 350,
  },
  alreadyDiscoveredText: {
    fontSize: 18,
    color: Palette.gray900,
    textAlign: 'center',
    marginTop: 16,
    marginBottom: 12,
  },
  redirectText: {
    fontSize: 14,
    color: Palette.gray900,
    marginTop: 8,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
  },
  loadingText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '500',
  },
});
