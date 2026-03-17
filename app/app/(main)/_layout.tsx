import React from 'react';
import { View, StyleSheet } from 'react-native';
import { VideoView, useVideoPlayer } from 'expo-video';
import { Slot, usePathname } from 'expo-router';
import { IslandHeader } from '@/components/IslandHeader';
import { CircleFooter } from '@/components/CircleFooter';
import { Auth0Provider } from '@/components/Auth0Provider';
import { Palette } from '@/constants/theme';

const backgroundVideo = require('@/assets/images/video.mp4');

export default function MainLayout() {
  const pathname = usePathname();
  
  // Determine active route for footer highlighting
  // pathname can be "/" or "/map", "/guide", etc.
  // We need to map it to 'scan' | 'map' | 'visit' | 'events' | 'entertainment' | 'staff'
  let activeRoute: 'scan' | 'map' | 'visit' | 'events' | 'entertainment' | 'staff' = 'scan';
  
  // Handle typed routes where pathname might be like "/(main)/events"
  if (pathname === '/' || pathname === '/index' || pathname === '/(main)/index' || pathname === '/(main)') activeRoute = 'scan';
  else if (pathname.includes('map')) activeRoute = 'map';
  else if (pathname.includes('guide')) activeRoute = 'visit';
  else if (pathname.includes('events')) activeRoute = 'events';
  else if (pathname.includes('entertainment') || pathname.includes('scrapbook')) activeRoute = 'entertainment';
  else if (pathname.includes('staff-panel')) activeRoute = 'staff';

  // Wrapper component decision based on route
  const isHome = activeRoute === 'scan';

  const player = useVideoPlayer(backgroundVideo, (player) => {
    player.loop = true;
    player.muted = true;
    player.play();
  });

  const content = (
    <View style={styles.container}>
      <IslandHeader />
      <View style={styles.slotContainer}>
        <Slot />
      </View>
      <CircleFooter activeRoute={activeRoute} />
    </View>
  );

  const layoutContent = isHome ? (
    <View style={styles.container}>
      <VideoView
        player={player}
        style={styles.backgroundVideo}
        contentFit="cover"
        nativeControls={false}
        allowsFullscreen={false}
      />
      {content}
    </View>
  ) : (
    <View style={[styles.container, styles.whiteBackground]}>
      {content}
    </View>
  );

  return (
    <Auth0Provider>
      {layoutContent}
    </Auth0Provider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  whiteBackground: {
    backgroundColor: Palette.white,
  },
  backgroundVideo: {
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    right: 0,
    width: '100%',
    height: '100%',
  },
  slotContainer: {
    flex: 1,
  },
});
