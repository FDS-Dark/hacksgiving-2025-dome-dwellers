import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useRouter } from 'expo-router';
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';
import { useUser } from '@/hooks/use-user';

interface FooterButtonProps {
  iconName: keyof typeof Ionicons.glyphMap;
  onPress?: () => void;
  size?: number;
  highlighted?: boolean;
  isActive?: boolean;
}

const AnimatedTouchableOpacity = Animated.createAnimatedComponent(TouchableOpacity);

const FooterButton = ({ iconName, onPress, size = 24, highlighted = false, isActive = false }: FooterButtonProps) => {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [{ scale: scale.value }],
    };
  });

  const handlePressIn = () => {
    scale.value = withSpring(0.9);
  };

  const handlePressOut = () => {
    scale.value = withSpring(1);
  };

  return (
    <AnimatedTouchableOpacity 
      style={[
        styles.button, 
        highlighted && styles.highlightedButton,
        isActive && !highlighted && styles.activeButton,
        animatedStyle
      ]} 
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      activeOpacity={0.7}
    >
      <Ionicons 
        name={iconName} 
        size={size} 
        color={highlighted ? Palette.white : (isActive ? Palette.green900 : Palette.black)} 
      />
    </AnimatedTouchableOpacity>
  );
};

interface CircleFooterProps {
  activeRoute?: 'map' | 'visit' | 'scan' | 'events' | 'entertainment' | 'staff';
}

export const CircleFooter = ({ activeRoute = 'scan' }: CircleFooterProps) => {
  const router = useRouter();
  const { user } = useUser();

  const isStaffOrAdmin = user?.roles?.some(role => role === 'staff' || role === 'admin') || false;

  const navigateTo = (route: string) => {
    router.replace(route as any);
  };

  return (
    <View style={styles.container}>
      <FooterButton
        iconName={activeRoute === 'map' ? "map" : "map-outline"}
        onPress={() => navigateTo('/map')}
        isActive={activeRoute === 'map'}
      />
      <FooterButton
        iconName={activeRoute === 'visit' ? "compass" : "compass-outline"}
        onPress={() => navigateTo('/guide')}
        isActive={activeRoute === 'visit'}
      />
      <FooterButton
        iconName={activeRoute === 'events' ? "calendar" : "calendar-outline"}
        onPress={() => navigateTo('/events')}
        isActive={activeRoute === 'events'}
      />
      <View style={styles.scanButtonContainer}>
        <View style={styles.bulbContainer}>
          <View style={styles.bulbShape} />
        </View>
        <FooterButton
          iconName="scan"
          size={32}
          highlighted
          onPress={() => router.push('/scan')}
          isActive={activeRoute === 'scan'}
        />
      </View>
      <FooterButton
        iconName={activeRoute === 'entertainment' ? "game-controller" : "game-controller-outline"}
        onPress={() => navigateTo('/entertainment')}
        isActive={activeRoute === 'entertainment'}
      />
      {isStaffOrAdmin && (
        <FooterButton
          iconName={activeRoute === 'staff' ? "briefcase" : "briefcase-outline"}
          onPress={() => navigateTo('/(main)/staff-panel')}
          isActive={activeRoute === 'staff'}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 15,
    backgroundColor: 'rgba(255, 255, 255, 0.95)', // Semi-transparent white
    borderTopWidth: 1,
    borderTopColor: 'rgba(240, 240, 240, 0.5)',
    paddingBottom: 30, // Safe area padding
    position: 'relative',
    overflow: 'visible',
  },
  scanButtonContainer: {
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
  },
  bulbContainer: {
    position: 'absolute',
    top: -45,
    width: 100,
    height: 30,
    alignItems: 'center',
    justifyContent: 'flex-start',
    zIndex: 1,
  },
  bulbShape: {
    width: 100,
    height: 40,
    backgroundColor: 'rgba(255, 255, 255, 1)',
    borderTopLeftRadius: 40,
    borderTopRightRadius: 40,
    borderBottomLeftRadius: 0,
    borderBottomRightRadius: 0,
  },
  button: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: Palette.gray100,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.2,
    shadowRadius: 1.41,
    elevation: 2,
  },
  highlightedButton: {
    backgroundColor: Palette.green900,
    width: 60,
    height: 60,
    borderRadius: 30,
    marginBottom: 10, // Slight lift
    elevation: 4,
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  activeButton: {
    backgroundColor: Palette.gray200, // Slightly darker background for active non-highlighted buttons
  }
});
