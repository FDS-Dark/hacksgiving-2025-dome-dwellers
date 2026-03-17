import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Image,
  Linking,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { EventRegistrationModal } from '@/components/EventRegistrationModal';
import { Palette } from '@/constants/theme';
import { useTranslation } from '@/hooks/useTranslation';
import { styles } from './events.styles';
import { useEvents } from '@/hooks/use-events';
import { Event, EventType } from '@/types/dome';

// Event type labels will be translated in the component

const EVENT_TYPE_ICONS: Record<EventType, keyof typeof Ionicons.glyphMap> = {
  tour: 'walk-outline',
  class: 'school-outline',
  exhibition: 'image-outline',
  special_event: 'star-outline',
  other: 'calendar-outline',
};

export default function EventsScreen() {
  const { t } = useTranslation();
  const [selectedFilter, setSelectedFilter] = useState<EventType | 'all'>('all');
  const [selectedEvent, setSelectedEvent] = useState<Event | null>(null);
  const [registrationModalVisible, setRegistrationModalVisible] = useState(false);

  const EVENT_TYPE_LABELS: Record<EventType, string> = {
    tour: t('events.types.tour'),
    class: t('events.types.class'),
    exhibition: t('events.types.exhibition'),
    special_event: t('events.types.specialEvent'),
    other: t('events.types.other'),
  };

  // Fetch events using TanStack Query - no auth required
  const { data, isLoading, error, refetch } = useEvents({
    event_type: selectedFilter === 'all' ? undefined : selectedFilter,
  });

  const events = data?.events || [];
  const loading = isLoading;

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    // Use device locale for date formatting
    return date.toLocaleDateString(undefined, {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    // Use device locale for time formatting
    return date.toLocaleTimeString(undefined, {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  };

  const handleRegister = async (event: Event) => {
    if (event.registration_url) {
      // Open external registration URL
      await Linking.openURL(event.registration_url);
    } else {
      // Open internal registration modal
      setSelectedEvent(event);
      setRegistrationModalVisible(true);
    }
  };

  const handleRegistrationSuccess = () => {
    // Refresh events to update registration counts
    refetch();
  };

  const filteredEvents = selectedFilter === 'all'
    ? events
    : events.filter(e => e.event_type === selectedFilter);

  const filters: Array<{ key: EventType | 'all'; label: string }> = [
    { key: 'all', label: t('events.filters.all') },
    { key: 'tour', label: t('events.filters.tour') },
    { key: 'class', label: t('events.filters.class') },
    { key: 'exhibition', label: t('events.filters.exhibition') },
    { key: 'special_event', label: t('events.filters.specialEvent') },
  ];

  if (loading) {
    return (
      <View style={styles.safeArea}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>{t('events.loading')}</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.safeArea}>
      <ScrollView style={styles.container}>
        {/* Header */}
        <View style={styles.content}>
          <View style={styles.titleSection}>
            <View style={styles.iconCircle}>
              <Ionicons name="calendar" size={32} color={Palette.green900} />
            </View>
            <Text style={styles.title}>{t('events.title')}</Text>
            <Text style={styles.subtitle}>{t('events.subtitle')}</Text>
          </View>
        </View>

        {/* Filters */}
        <View style={styles.filterSection}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.filterScrollContent}
            style={styles.filterScroll}
          >
            {filters.map(filter => (
              <TouchableOpacity
                key={filter.key}
                style={[
                  styles.filterChip,
                  selectedFilter === filter.key && styles.filterChipActive,
                ]}
                onPress={() => setSelectedFilter(filter.key)}
              >
                <Text
                  style={[
                    styles.filterChipText,
                    selectedFilter === filter.key && styles.filterChipTextActive,
                  ]}
                >
                  {filter.label}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>

        {/* Error Message */}
        {error && (
          <View style={styles.errorContainer}>
            <Text style={styles.errorText}>
              {error instanceof Error ? error.message : t('events.error')}
            </Text>
          </View>
        )}

        {/* Events List */}
        {filteredEvents.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Ionicons
              name="calendar-outline"
              size={64}
              color={Palette.gray900}
              style={styles.emptyIcon}
            />
            <Text style={styles.emptyTitle}>{t('events.emptyTitle')}</Text>
            <Text style={styles.emptyText}>
              {selectedFilter === 'all'
                ? t('events.emptyMessage')
                : t('events.emptyMessageFiltered', { type: EVENT_TYPE_LABELS[selectedFilter as EventType]?.toLowerCase() })}
            </Text>
          </View>
        ) : (
          <View style={styles.eventsList}>
            {filteredEvents.map(event => (
              <View key={event.id} style={styles.eventCard}>
                {/* Event Image */}
                {event.image_url ? (
                  <Image source={{ uri: event.image_url }} style={styles.eventImage} />
                ) : (
                  <View style={styles.eventImagePlaceholder}>
                    <Ionicons
                      name={EVENT_TYPE_ICONS[event.event_type]}
                      size={48}
                      color={Palette.green900}
                    />
                  </View>
                )}

                {/* Event Content */}
                <View style={styles.eventContent}>
                  {/* Header with badges */}
                  <View style={styles.eventHeader}>
                    <View style={styles.eventTypeContainer}>
                      <View style={styles.eventTypeBadge}>
                        <Text style={styles.eventTypeText}>
                          {EVENT_TYPE_LABELS[event.event_type]}
                        </Text>
                      </View>
                      {event.registration_required && (
                        <View style={styles.registrationBadge}>
                          <Text style={styles.registrationText}>{t('events.registrationRequired')}</Text>
                        </View>
                      )}
                    </View>
                    <Text style={styles.eventTitle}>{event.title}</Text>
                    {event.description && (
                      <Text style={styles.eventDescription} numberOfLines={3}>
                        {event.description}
                      </Text>
                    )}
                  </View>

                  {/* Event Details */}
                  <View style={styles.eventDetails}>
                    <View style={styles.eventDetailRow}>
                      <Ionicons name="calendar-outline" size={16} color={Palette.gray900} />
                      <Text style={styles.eventDetailText}>
                        {formatDate(event.start_time)}
                      </Text>
                    </View>
                    <View style={styles.eventDetailRow}>
                      <Ionicons name="time-outline" size={16} color={Palette.gray900} />
                      <Text style={styles.eventDetailText}>
                        {formatTime(event.start_time)} - {formatTime(event.end_time)}
                      </Text>
                    </View>
                    {event.location && (
                      <View style={styles.eventDetailRow}>
                        <Ionicons name="location-outline" size={16} color={Palette.gray900} />
                        <Text style={styles.eventDetailText}>{event.location}</Text>
                      </View>
                    )}
                  </View>

                  {/* Footer */}
                  <View style={styles.eventFooter}>
                    {event.capacity && (
                      <Text style={styles.capacityText}>
                        {t('events.capacity', { count: event.capacity })}
                      </Text>
                    )}
                    {event.registration_required ? (
                      <TouchableOpacity
                        style={styles.registerButton}
                        onPress={() => handleRegister(event)}
                      >
                        <Text style={styles.registerButtonText}>{t('events.register')}</Text>
                      </TouchableOpacity>
                    ) : (
                      <TouchableOpacity style={styles.viewDetailsButton}>
                        <Text style={styles.viewDetailsButtonText}>{t('events.viewDetails')}</Text>
                      </TouchableOpacity>
                    )}
                  </View>
                </View>
              </View>
            ))}
          </View>
        )}
      </ScrollView>

      {/* Registration Modal */}
      <EventRegistrationModal
        visible={registrationModalVisible}
        event={selectedEvent}
        onClose={() => {
          setRegistrationModalVisible(false);
          setSelectedEvent(null);
        }}
        onSuccess={handleRegistrationSuccess}
      />
    </View>
  );
}
